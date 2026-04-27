#!/bin/bash
# ============================================================================
# 飞书灵感记录助手 — 一键安装脚本
# ============================================================================
# 这个脚本会做：
#   1. 检测系统（macOS）
#   2. 检测/装依赖（lark-cli、jq、python3）
#   3. 引导你填 .env（飞书凭据、DashScope key、open_id、输出目录）
#   4. 渲染 launchd plist 模板
#   5. 加载 launchd（开机自启 + 挂掉自动重启）
#   6. 发条测试消息验证
# ============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PLIST_LABEL="ai.lark-inspiration-bot.listener"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_yellow() { printf "\033[33m%s\033[0m" "$*"; }
c_red() { printf "\033[31m%s\033[0m" "$*"; }
c_bold() { printf "\033[1m%s\033[0m" "$*"; }

step() {
  echo ""
  echo "$(c_bold "==== $* ====")"
}

# ----------------------------------------------------------------------------
step "1/6 系统检查"

if [[ "$(uname)" != "Darwin" ]]; then
  c_red "✗ 这个脚本只支持 macOS。Linux 用户需要自己改 launchd 部分（参考 docs/05-常见问题.md）"
  echo ""
  exit 1
fi
echo "$(c_green "✓") macOS 已识别"

# ----------------------------------------------------------------------------
step "2/6 依赖安装"

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  c_red "✗ 没装 Homebrew。先去 https://brew.sh/ 装一下，然后重跑这个脚本"
  echo ""
  exit 1
fi
echo "$(c_green "✓") Homebrew 已装"

# jq
if ! command -v jq >/dev/null 2>&1; then
  echo "→ 安装 jq..."
  brew install jq
fi
echo "$(c_green "✓") jq 已装"

# python3
if ! command -v python3 >/dev/null 2>&1; then
  c_red "✗ 没找到 python3。macOS 自带的应该够用，运行 'xcode-select --install' 试试"
  echo ""
  exit 1
fi
echo "$(c_green "✓") python3 已装"

# lark-cli
if ! command -v lark-cli >/dev/null 2>&1; then
  echo ""
  c_yellow "✗ 没装 lark-cli。请先到 https://github.com/larksuite/lark-cli 按官方指引安装。"
  echo ""
  c_yellow "  装完后，运行 'lark-cli auth login' 完成飞书授权（详见 docs/01-申请飞书机器人.md）"
  echo ""
  exit 1
fi
echo "$(c_green "✓") lark-cli 已装"

# ----------------------------------------------------------------------------
step "3/6 配置文件 (.env)"

ENV_PATH="${PROJECT_ROOT}/.env"

if [[ -f "$ENV_PATH" ]]; then
  c_yellow "已存在 .env 文件。"
  read -p "  覆盖重新填？[y/N] " ow
  if [[ "$ow" != "y" && "$ow" != "Y" ]]; then
    echo "  保留现有 .env，跳过这一步"
  else
    rm "$ENV_PATH"
  fi
fi

if [[ ! -f "$ENV_PATH" ]]; then
  cp "${PROJECT_ROOT}/.env.example" "$ENV_PATH"
  echo ""
  echo "现在我会问你 5 个问题，每个问题都有教程链接。"
  echo "随时按 Ctrl+C 退出，已填的会保留。"
  echo ""

  read -p "$(c_bold "[1/5] DashScope API Key") (sk-... 见 docs/02): " val
  sed -i '' "s|^DASHSCOPE_API_KEY=.*|DASHSCOPE_API_KEY=${val}|" "$ENV_PATH"

  read -p "$(c_bold "[2/5] 飞书 App ID") (cli_... 见 docs/01): " val
  sed -i '' "s|^LARK_APP_ID=.*|LARK_APP_ID=${val}|" "$ENV_PATH"

  read -p "$(c_bold "[3/5] 飞书 App Secret") (见 docs/01): " val
  sed -i '' "s|^LARK_APP_SECRET=.*|LARK_APP_SECRET=${val}|" "$ENV_PATH"

  read -p "$(c_bold "[4/5] 你的飞书 open_id") (ou_... 见 docs/03): " val
  sed -i '' "s|^LARK_USER_OPEN_ID=.*|LARK_USER_OPEN_ID=${val}|" "$ENV_PATH"

  default_out="${HOME}/lark-inspirations"
  read -p "$(c_bold "[5/5] Markdown 输出目录") [默认 ${default_out}]: " val
  val="${val:-$default_out}"
  # 转义 sed 特殊字符
  val_escaped=$(printf '%s\n' "$val" | sed 's/[\/&]/\\&/g')
  sed -i '' "s|^MARKDOWN_OUTPUT_DIR=.*|MARKDOWN_OUTPUT_DIR=${val_escaped}|" "$ENV_PATH"

  mkdir -p "$val"
  chmod 600 "$ENV_PATH"
  echo "$(c_green "✓") .env 已生成（chmod 600）"
fi

# 校验填了
set -a
# shellcheck disable=SC1090
source "$ENV_PATH"
set +a
for var in DASHSCOPE_API_KEY LARK_APP_ID LARK_APP_SECRET LARK_USER_OPEN_ID; do
  if [[ -z "${!var:-}" ]] || [[ "${!var}" == *"在这里填"* ]]; then
    c_red "✗ .env 里 ${var} 还没填。手动改一下 ${ENV_PATH}，然后重跑 install.sh"
    echo ""
    exit 1
  fi
done

# ----------------------------------------------------------------------------
step "4/6 渲染 launchd 配置"

mkdir -p "${HOME}/Library/LaunchAgents"
mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/state"

# 用 sed 替换模板里的 {{PROJECT_ROOT}} 和 {{USER_PATH}}
# PATH 要带上 brew 和 lark-cli 的路径
USER_PATH="/usr/local/bin:/opt/homebrew/bin:${HOME}/.lark-cli/bin:/usr/bin:/bin"
PROJECT_ROOT_ESC=$(printf '%s\n' "$PROJECT_ROOT" | sed 's/[\/&]/\\&/g')
USER_PATH_ESC=$(printf '%s\n' "$USER_PATH" | sed 's/[\/&]/\\&/g')

sed -e "s|{{PROJECT_ROOT}}|${PROJECT_ROOT_ESC}|g" \
    -e "s|{{USER_PATH}}|${USER_PATH_ESC}|g" \
    "${PROJECT_ROOT}/templates/launchd-listener.plist.tpl" \
    > "$PLIST_PATH"
echo "$(c_green "✓") plist 已生成：${PLIST_PATH}"

# 给所有脚本加可执行权限
chmod +x "${PROJECT_ROOT}/scripts/"*.sh "${PROJECT_ROOT}/install.sh" "${PROJECT_ROOT}/uninstall.sh"

# ----------------------------------------------------------------------------
step "5/6 启动 listener"

launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
sleep 3

if launchctl print "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null | grep -q "state = running"; then
  echo "$(c_green "✓") listener 启动成功"
else
  c_yellow "⚠ listener 启动状态未确认，看 logs/listener.log 排查"
fi

# ----------------------------------------------------------------------------
step "6/6 测试"

echo ""
echo "现在去你的飞书，找到刚才创建的 bot，给它发一句话试试，比如："
echo "    $(c_bold "今天突然觉得，做事先想清楚为什么")"
echo ""
echo "5 秒后应该会收到 bot 的回复，并且 ${MARKDOWN_OUTPUT_DIR} 里应该出现新的 .md 文件。"
echo ""
echo "$(c_bold "如果没反应：")"
echo "  · 看日志：$(c_bold "tail -f ${PROJECT_ROOT}/logs/listener.log")"
echo "  · 看 LLM 错误：$(c_bold "tail -f ${PROJECT_ROOT}/logs/llm.err.log")"
echo "  · 排障文档：$(c_bold "docs/05-常见问题.md")"
echo ""
echo "$(c_green "🎉 装完了") 改了 .env 后运行 $(c_bold "./scripts/reload.sh") 重启生效。"
echo ""
