#!/bin/bash
# ============================================================================
# 飞书灵感记录助手 — 共享函数库
# ============================================================================
# 所有脚本 source 这个文件。包含：
# - 配置加载
# - 日志
# - DashScope qwen LLM 调用
# - 飞书发消息
# - 消息去抖（连发多条 → 合并一次回复）
# - Markdown 文件追加
# ============================================================================

# 找到项目根目录（不管脚本被 source 自哪里）
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${LIB_DIR}/.." && pwd)"

# ========== 配置加载 ==========
# 从 .env 加载（chmod 600）
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
else
  echo "[ERROR] 没有找到 ${PROJECT_ROOT}/.env，请先运行 ./install.sh" >&2
  exit 1
fi

# 必填项检查
for var in DASHSCOPE_API_KEY LARK_APP_ID LARK_APP_SECRET LARK_USER_OPEN_ID MARKDOWN_OUTPUT_DIR; do
  if [[ -z "${!var:-}" ]] || [[ "${!var}" == *"在这里填"* ]]; then
    echo "[ERROR] .env 里 ${var} 没填或还是占位符" >&2
    exit 1
  fi
done

# 默认值
DEBOUNCE_SECONDS="${DEBOUNCE_SECONDS:-5}"
LLM_MODEL="${LLM_MODEL:-qwen-plus}"
MARKDOWN_GROUPING="${MARKDOWN_GROUPING:-daily}"
BOT_PERSONA="${BOT_PERSONA:-你是一位灵感整理助手。简短确认 + 帮我整理 + 偶尔追问。}"

# 状态/日志目录
STATE_DIR="${PROJECT_ROOT}/state"
LOGS_DIR="${PROJECT_ROOT}/logs"
mkdir -p "$STATE_DIR" "$LOGS_DIR"

FLUSHER_POLL_INTERVAL=2

# ========== 日志 ==========
log() {
  local prefix="$1"; shift
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${prefix}] $*" >> "${LOGS_DIR}/${prefix}.log"
}

# ========== 飞书发消息 ==========
# 用法: lark_send_text "文本"
lark_send_text() {
  local text="$1"
  lark-cli im +messages-send \
    --as bot \
    --user-id "$LARK_USER_OPEN_ID" \
    --text "$text" 2>>"${LOGS_DIR}/lark.err.log"
}

# ========== LLM 调用 ==========
# 用法: llm_run "完整 prompt"
# 返回 LLM 文本输出到 stdout。失败返回空字符串（不退出，由调用方决定兜底）。
llm_run() {
  local prompt="$1"
  local base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"

  # 用 python 构造 JSON（避免 bash 转义问题）
  local body
  body=$(python3 -c '
import json, sys, os
prompt = sys.stdin.read()
print(json.dumps({
    "model": os.environ.get("LLM_MODEL", "qwen-plus"),
    "max_tokens": 2048,
    "messages": [{"role": "user", "content": prompt}],
    "enable_thinking": False,
}))
' <<< "$prompt")

  local response
  response=$(curl -s --max-time 90 \
    -X POST "${base_url}/chat/completions" \
    -H "content-type: application/json" \
    -H "authorization: Bearer ${DASHSCOPE_API_KEY}" \
    -d "$body" \
    2>>"${LOGS_DIR}/llm.err.log")

  echo "$response" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    if "choices" in d and d["choices"]:
        print(d["choices"][0]["message"].get("content", ""))
    else:
        sys.stderr.write(f"[llm_run] API error: {json.dumps(d, ensure_ascii=False)}\n")
except Exception as e:
    sys.stderr.write(f"[llm_run] parse error: {e}\n")
' 2>>"${LOGS_DIR}/llm.err.log"
}

# ========== Markdown 文件路径解析 ==========
# 根据 MARKDOWN_GROUPING 决定今天写到哪个文件
get_target_markdown_path() {
  case "$MARKDOWN_GROUPING" in
    weekly)
      local year week
      year=$(date '+%Y')
      week=$(date '+%V')
      echo "${MARKDOWN_OUTPUT_DIR}/${year}/W${week}.md"
      ;;
    single)
      echo "${MARKDOWN_OUTPUT_DIR}/inspirations.md"
      ;;
    daily|*)
      local year month day
      year=$(date '+%Y')
      month=$(date '+%m')
      day=$(date '+%d')
      echo "${MARKDOWN_OUTPUT_DIR}/${year}/${month}/${day}.md"
      ;;
  esac
}

# 确保目标 Markdown 文件存在（首次创建时写入标题）
ensure_markdown_file() {
  local path
  path="$(get_target_markdown_path)"
  local dir
  dir=$(dirname "$path")
  mkdir -p "$dir"
  if [[ ! -f "$path" ]]; then
    {
      echo "# 灵感记录 — $(date '+%Y-%m-%d')"
      echo ""
      echo "> 由飞书灵感记录助手自动生成"
      echo ""
    } > "$path"
  fi
  echo "$path"
}

# ========== Markdown 写入 ==========
# 用法: append_to_markdown "原话" "AI整理后" "AI追问(可空)"
append_to_markdown() {
  local raw="$1"
  local refined="$2"
  local question="${3:-}"
  local ts
  ts=$(date '+%H:%M')
  local path
  path="$(ensure_markdown_file)"

  local lockdir="${STATE_DIR}/markdown-write.lockdir"
  local waited=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    if (( waited >= 30 )); then
      log reply "[append] 拿锁超时，跳过"
      return 1
    fi
    sleep 1
    waited=$((waited+1))
  done
  trap 'rmdir "$lockdir" 2>/dev/null' RETURN

  {
    echo ""
    echo "## ${ts}"
    echo ""
    echo "**原话**"
    echo ""
    # 多行原话保持原样
    while IFS= read -r line; do
      echo "$line"
    done <<< "$raw"
    echo ""
    if [[ -n "$refined" ]]; then
      echo "**整理**：${refined}"
      echo ""
    fi
    if [[ -n "$question" ]]; then
      echo "**追问**：${question}"
      echo ""
    fi
  } >> "$path"

  log reply "已写入 ${path}"
}

# 兜底：LLM 挂时只写原话，保证不丢
append_raw_only() {
  local raw="$1"
  local ts
  ts=$(date '+%H:%M')
  local path
  path="$(ensure_markdown_file)"

  {
    echo ""
    echo "## ${ts} (兜底)"
    echo ""
    while IFS= read -r line; do
      echo "$line"
    done <<< "$raw"
    echo ""
    echo "> LLM 调用失败，仅保留原话"
    echo ""
  } >> "$path"

  log reply "兜底写入 ${path}"
}

# ========== 消息去抖 ==========
# 几秒内连发多条 → 合并成一段一次性处理
enqueue_message() {
  local msg="$1"
  local buffer="${STATE_DIR}/pending-messages.txt"
  local last_ts="${STATE_DIR}/pending-last.ts"
  local flusher_lock="${STATE_DIR}/pending-flusher.lock"

  local is_first=0
  if [[ ! -f "$flusher_lock" ]]; then
    is_first=1
  else
    local old_pid
    old_pid=$(cat "$flusher_lock" 2>/dev/null)
    if [[ -z "$old_pid" ]] || ! kill -0 "$old_pid" 2>/dev/null; then
      is_first=1
      rm -f "$flusher_lock"
    fi
  fi

  printf '%s\n\x1f\n' "$msg" >> "$buffer"
  date +%s > "$last_ts"

  log listener "enqueue (first=$is_first): ${msg:0:40}"

  if (( is_first == 1 )); then
    lark_send_text "👂" >/dev/null 2>&1 || true
    nohup bash -c "
      source '${LIB_DIR}/lib.sh'
      flusher_loop
    " >>"${LOGS_DIR}/flusher.log" 2>&1 &
    echo $! > "$flusher_lock"
    log listener "启动 flusher (pid=$!)"
  fi
}

# Flusher 后台循环：静默够久才 flush
flusher_loop() {
  local buffer="${STATE_DIR}/pending-messages.txt"
  local last_ts="${STATE_DIR}/pending-last.ts"
  local flusher_lock="${STATE_DIR}/pending-flusher.lock"

  trap 'rm -f "$flusher_lock"' EXIT

  while true; do
    sleep "$FLUSHER_POLL_INTERVAL"
    [[ -f "$last_ts" ]] || return 0
    local last now diff
    last=$(cat "$last_ts")
    now=$(date +%s)
    diff=$(( now - last ))
    if (( diff >= DEBOUNCE_SECONDS )); then
      log flusher "静默 ${diff}s，开始 flush"
      break
    fi
  done

  [[ -f "$buffer" ]] || return 0
  local batch_file
  batch_file="${STATE_DIR}/batch-$(date +%s).txt"
  mv "$buffer" "$batch_file"
  rm -f "$last_ts"

  local combined
  combined=$(awk 'BEGIN{RS="\x1f\n"} NF{if(NR>1)printf "\n\n"; printf "%s", $0}' "$batch_file")

  log flusher "flush 批次：$(printf '%s' "$combined" | wc -c) 字"
  "${LIB_DIR}/reply.sh" "$combined" >>"${LOGS_DIR}/reply-runs.log" 2>&1
  rm -f "$batch_file"
}
