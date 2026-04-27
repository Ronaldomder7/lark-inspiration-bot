#!/bin/bash
# ============================================================================
# 一键卸载（不会删你的 .env 和 markdown 文件）
# ============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PLIST_LABEL="ai.lark-inspiration-bot.listener"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "→ 停 listener"
launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true

echo "→ 删 plist"
rm -f "$PLIST_PATH"

echo "→ 清状态文件"
rm -rf "${PROJECT_ROOT}/state"

echo ""
echo "✓ 卸载完成。"
echo ""
echo "保留的东西："
echo "  · .env 配置（${PROJECT_ROOT}/.env）"
echo "  · 日志文件夹（${PROJECT_ROOT}/logs/）"
echo "  · 你的灵感 markdown 文件（在你 .env 里设的目录）"
echo ""
echo "想完全清掉，手动 rm 这些目录即可。"
