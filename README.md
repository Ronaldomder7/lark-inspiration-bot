# 飞书灵感记录助手

> *Feishu/Lark inspiration capture bot — turn your scattered thoughts into a structured local Markdown archive.*

在飞书随手发想法 → AI 整理 → 自动归档到本地 Markdown 文件。

---

## 装完你能获得什么

✅ **一个属于你的飞书 AI 对话伙伴**
你在飞书私聊里给它发任何文字，它都会回你（5 秒内）。

✅ **每天自动生成的灵感日志**
你说的每一句话都会被存到本地 Markdown 文件，按 `年/月/日.md` 归档。
长这样：

```markdown
# 灵感记录 — 2026-04-27

## 14:32

**原话**

今天突然觉得 做内容应该先想清楚给谁看 再想说什么

**整理**：内容创作的优先级——先有受众洞察，再谈表达欲。

**追问**：那你现在做的内容，受众画像清晰吗？
```

✅ **AI 帮你整理 + 追问**
不只是存档，AI 会帮你把碎碎念整理成一句精炼的话，偶尔追问一下推你深入想想。

✅ **连发不打断**
你连着发 5 条想法，bot 不会回 5 次，会等你停手 5 秒后合并成一段一次性回。

✅ **开机自启 + 挂掉自愈**
装完不用管，电脑开着就一直在工作。

✅ **数据全在你电脑里**
不上传到任何第三方。Markdown 文件你想放 iCloud / Obsidian / Dropbox 同步都行，多设备能看。

---

## 适合谁

- 想用飞书做"个人闪念笔记本"的人
- 用 Obsidian / Logseq / 任何 Markdown 笔记系统的人
- 经常坐地铁/走路时有灵感、但不想专门打开笔记 app 的人
- macOS 用户（暂不支持 Windows / Linux）

---

## 5 步装好（10 分钟）

### 前置条件

- macOS 电脑（M 芯片或 Intel 都行）
- 一个飞书账号
- 装了 [Homebrew](https://brew.sh/)（没装的话先装这个）
- 装了 [lark-cli](https://github.com/larksuite/lark-cli)（飞书官方 CLI 工具）
- ~10 块钱往 [阿里云 DashScope](https://bailian.console.aliyun.com/) 充值（够用一年）

### 步骤

```bash
# 1. clone 这个项目
git clone https://github.com/ASI-Mark/lark-inspiration-bot.git
cd lark-inspiration-bot

# 2. 跑一键安装
./install.sh
```

`install.sh` 会引导你交互式填 5 个值：

| 要填的 | 在哪儿拿 |
|--------|---------|
| DashScope API Key | [docs/02-获取-DashScope-Key.md](docs/02-获取-DashScope-Key.md) |
| 飞书 App ID + Secret | [docs/01-申请飞书机器人.md](docs/01-申请飞书机器人.md) |
| 你的飞书 open_id | [docs/03-找到自己的-open-id.md](docs/03-找到自己的-open-id.md) |
| Markdown 输出目录 | 你想存哪儿就填哪儿，比如 `~/Obsidian/灵感` |

填完它会自动：
- ✓ 装依赖（jq）
- ✓ 写 launchd 配置（开机自启）
- ✓ 启动 listener
- ✓ 等你去飞书发条消息测试

---

## 装完后怎么用

打开飞书 → 找到你的 bot → 私聊 → 随便发：

> 今天看《纳瓦尔宝典》里说 财富不是赚来的 是积累来的

5 秒后 bot 会回你：

> 记下了 ✓ 这是不是说，杠杆比时薪更重要？
>
> 你现在的工作里，有杠杆性资产在累积吗？

同时本地 `~/你设的目录/2026/04/27.md` 会被追加这条记录。

---

## 常用操作

```bash
# 改了 .env 后重启生效
./scripts/reload.sh

# 看 bot 在不在跑
tail -f logs/listener.log

# 看 LLM 出错了没
tail -f logs/llm.err.log

# 一键卸载（保留你的 .env 和 markdown 文件）
./uninstall.sh
```

---

## 想自定义？

7 个改了立刻生效的点（改 `.env` 然后 `./scripts/reload.sh`）：

| 想干啥 | 改这个 |
|--------|--------|
| 让 AI 用别的人设/语气 | `BOT_PERSONA` |
| 让 bot 等更久才回（适合慢慢打长段） | `DEBOUNCE_SECONDS` |
| 用更聪明的模型（贵 5 倍） | `LLM_MODEL=qwen-max` |
| 改输出目录 | `MARKDOWN_OUTPUT_DIR` |
| 改文件命名（按周/单文件） | `MARKDOWN_GROUPING` |
| 换接收消息的人 | `LARK_USER_OPEN_ID` |
| 换 LLM 后端（换 OpenAI / Claude） | 改 `scripts/lib.sh` 里的 `llm_run()` 函数 |

详细说明：[docs/04-自定义指南.md](docs/04-自定义指南.md)

---

## 出问题了？

看 [docs/05-常见问题.md](docs/05-常见问题.md)，里面有 8 个最常见问题的解法。

---

## 项目结构

```
lark-inspiration-bot/
├── README.md              ← 你正在看的
├── install.sh             ← 一键安装
├── uninstall.sh           ← 一键卸载
├── .env.example           ← 配置模板
├── scripts/
│   ├── lib.sh             ← 共享函数（LLM / 飞书 / 去抖 / Markdown）
│   ├── listener.sh        ← 飞书消息监听守护进程
│   ├── reply.sh           ← 收到消息后处理
│   └── reload.sh          ← 改完配置重启
├── templates/
│   └── launchd-listener.plist.tpl   ← launchd 模板（install 时渲染）
└── docs/
    ├── 01-申请飞书机器人.md
    ├── 02-获取-DashScope-Key.md
    ├── 03-找到自己的-open-id.md
    ├── 04-自定义指南.md
    └── 05-常见问题.md
```

---

## License

MIT

---

## 致谢

底层架构来自一个个人项目「coach-v2」（飞书私人教练 bot）的简化版，去掉了所有个人耦合（人设 / 私人方法论 / Obsidian 路径），只保留通用骨架。
