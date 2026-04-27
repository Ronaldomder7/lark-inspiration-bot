# 02 — 获取阿里云 DashScope API Key

> 目标：拿到 `DASHSCOPE_API_KEY`（以 `sk-` 开头的一串字符）。
>
> DashScope 是阿里云的大模型服务，国内可直接访问，不用翻墙。

---

## 为什么用 DashScope

- ✅ **国内直连**，速度快，不用代理
- ✅ **便宜**：qwen-plus 大约 0.8 元 / 100 万 token
  实测一天聊天用不到 0.1 元
- ✅ **新用户送 100 万 token**（够用大半年）

---

## 步骤

### 第一步：注册阿里云账号

1. 打开 https://www.aliyun.com/
2. 用手机号注册（如果你已经有阿里云账号，直接登录就行）

### 第二步：开通 DashScope（百炼）

1. 打开 https://bailian.console.aliyun.com/
2. 第一次进会让你**开通服务**，点确认即可（免费开通）
3. 开通后会自动送你 100 万 token 的免费额度

### 第三步：创建 API Key

1. 在百炼控制台左侧菜单找到 **"API-KEY 管理"**（或者直接打开 https://bailian.console.aliyun.com/?apiKey=1）
2. 点 **"创建 API-KEY"**
3. 起个名字（随便，比如 `inspiration-bot`）
4. 创建后复制那串 `sk-...` 开头的 key

⚠️ **API Key 只会显示一次，复制后存好。如果丢了只能重新创建。**

---

## 验证

终端跑：

```bash
curl https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Authorization: Bearer 你的key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-plus",
    "messages": [{"role": "user", "content": "说一句你好"}]
  }'
```

如果返回里有 `"content": "你好"` 类似内容，说明 key 通了。

---

## 充值（可选）

免费 100 万 token 用完后，需要充值才能继续用。

1. 进 https://bailian.console.aliyun.com/?tab=expense
2. 充 10 元一般够用很久（重度使用一年都用不完）

---

## 切别的模型

`.env` 里改 `LLM_MODEL` 即可：

| 模型 | 价格（元/百万token输入） | 适合 |
|------|------------------------|------|
| `qwen-turbo` | 0.3 | 最便宜，回复偶尔不深 |
| `qwen-plus` | 0.8 | **推荐**，性价比最高 |
| `qwen-max` | 2.4 | 最聪明，贵 3 倍 |

改完跑 `./scripts/reload.sh` 生效。
