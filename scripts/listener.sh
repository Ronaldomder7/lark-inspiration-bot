#!/bin/bash
# ============================================================================
# 飞书消息监听守护进程
# ============================================================================
# 订阅飞书 im.message.receive_v1 事件，过滤出你自己的 p2p 文本消息，
# 入队到 debounce buffer。由 launchd KeepAlive 守护，挂掉自动重启。
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

log listener "==== listener 启动 (pid=$$) ===="

# 防重入
LOCK_FILE="${STATE_DIR}/listener.lock"
if [[ -f "$LOCK_FILE" ]]; then
  OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    log listener "已有 listener 在跑 (pid=$OLD_PID)，本进程退出"
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; log listener "listener 退出 (pid=$$)"' EXIT

# 启动事件订阅
lark-cli event +subscribe \
  --as bot \
  --event-types im.message.receive_v1 \
  --compact --quiet 2>>"${LOGS_DIR}/listener.err.log" \
| while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    sender_id=$(echo "$line" | jq -r '.sender_id // empty' 2>/dev/null)
    chat_type=$(echo "$line" | jq -r '.chat_type // empty' 2>/dev/null)
    msg_type=$(echo "$line"  | jq -r '.message_type // empty' 2>/dev/null)
    content=$(echo "$line"   | jq -r '.content // empty' 2>/dev/null)

    # 只处理：我自己发的、p2p、文本
    [[ "$sender_id" != "$LARK_USER_OPEN_ID" ]] && continue
    [[ "$chat_type" != "p2p" ]] && continue

    if [[ "$msg_type" != "text" ]]; then
      lark_send_text "（暂只支持文本消息）" >/dev/null 2>&1 || true
      continue
    fi
    [[ -z "$content" ]] && continue

    log listener "收到消息：${content:0:60}"
    enqueue_message "$content"
  done

log listener "listener while-loop 退出（订阅断开）"
exit 1   # 非 0 → launchd KeepAlive 重启
