#!/bin/bash
# ============================================================================
# 改完 .env 或脚本后重启 bot
# ============================================================================

set -euo pipefail

PLIST_LABEL="ai.lark-inspiration-bot.listener"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "[ERROR] 没找到 $PLIST_PATH，请先运行 ./install.sh"
  exit 1
fi

echo "→ 停掉旧的 listener"
launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true
sleep 1

echo "→ 启动新的 listener"
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
sleep 2

echo "→ 检查状态"
if launchctl print "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null | grep -q "state = running"; then
  echo "✓ 重启成功，bot 正在运行"
else
  echo "⚠ 状态异常，看一眼日志：tail -f logs/listener.log"
fi
