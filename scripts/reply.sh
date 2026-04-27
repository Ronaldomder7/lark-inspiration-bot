#!/bin/bash
# ============================================================================
# 收到消息批次后的处理逻辑
# ============================================================================
# 由 lib.sh 的 flusher_loop 调用，参数是合并后的所有消息文本。
# 流程：
#   1. 拼 prompt（人设 + 用户原话）
#   2. 调 LLM 拿到 JSON {"reply": "...", "refined": "...", "question": "..."}
#   3. 飞书回 reply
#   4. Markdown 文件追加 原话+整理+追问
#   5. LLM 挂 → 兜底只写原话
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

USER_INPUT="${1:-}"
if [[ -z "$USER_INPUT" ]]; then
  log reply "空输入，跳过"
  exit 0
fi

log reply "处理输入 (${#USER_INPUT} 字符)"

# 构造 prompt
# 让 LLM 输出 JSON，方便 shell 解析三个字段
PROMPT="${BOT_PERSONA}

用户刚发来的内容（可能是连发多条已合并）：
\"\"\"
${USER_INPUT}
\"\"\"

请输出严格 JSON，三个字段：
{
  \"reply\": \"回给用户的话，1-2 句，简短确认\",
  \"refined\": \"把用户原话整理成一句精炼的话\",
  \"question\": \"如果有价值就给一个深入追问，否则留空字符串\"
}

只输出 JSON，不要任何前后说明文字、不要 markdown 代码块包裹。"

LLM_OUT=$(llm_run "$PROMPT")

if [[ -z "$LLM_OUT" ]]; then
  log reply "LLM 返回空，走兜底"
  lark_send_text "记下了 ✓（AI 整理失败，只保留了你的原话）" >/dev/null 2>&1 || true
  append_raw_only "$USER_INPUT"
  exit 0
fi

# 解析 JSON（允许 LLM 偶尔包了 ```json ``` 代码块）
PARSED=$(echo "$LLM_OUT" | python3 -c '
import json, sys, re
raw = sys.stdin.read().strip()
# 剥掉 ```json ... ``` 包裹
m = re.match(r"^```(?:json)?\s*(.+?)\s*```$", raw, re.DOTALL)
if m:
    raw = m.group(1)
try:
    d = json.loads(raw)
    print(d.get("reply", "").strip())
    print("===SEP===")
    print(d.get("refined", "").strip())
    print("===SEP===")
    print(d.get("question", "").strip())
except Exception as e:
    sys.stderr.write(f"[reply] JSON parse failed: {e}\n   raw: {raw[:200]}\n")
    sys.exit(1)
' 2>>"${LOGS_DIR}/reply.err.log")

if [[ -z "$PARSED" ]]; then
  log reply "JSON 解析失败，把整段当 reply 用"
  lark_send_text "$LLM_OUT" >/dev/null 2>&1 || true
  append_raw_only "$USER_INPUT"
  exit 0
fi

REPLY=$(echo "$PARSED"   | awk 'BEGIN{RS="===SEP===\n"} NR==1')
REFINED=$(echo "$PARSED" | awk 'BEGIN{RS="===SEP===\n"} NR==2')
QUESTION=$(echo "$PARSED"| awk 'BEGIN{RS="===SEP===\n"} NR==3')

# 飞书回复
FULL_REPLY="$REPLY"
if [[ -n "$QUESTION" ]]; then
  FULL_REPLY="${REPLY}

${QUESTION}"
fi
lark_send_text "$FULL_REPLY" >/dev/null 2>&1 || log reply "飞书发送失败"

# Markdown 落盘
append_to_markdown "$USER_INPUT" "$REFINED" "$QUESTION"

log reply "完成"
