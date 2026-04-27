# 03 — 找到你自己的飞书 open_id

> 目标：拿到 `LARK_USER_OPEN_ID`（以 `ou_` 开头的一串字符）。
>
> Bot 只会回复你这个 ID 发的消息，防止 bot 被陌生人滥用。

---

## 方法一：用 lark-cli 一键拿（推荐）

前提：已经按 [01-申请飞书机器人.md](01-申请飞书机器人.md) 完成了 `lark-cli auth login`。

```bash
# 拿当前登录账号自己的信息
lark-cli contact +user-info-self
```

输出里找 `open_id` 字段，复制 `ou_xxxxxxxxx` 那串。

---

## 方法二：通过手机号查（如果方法一不行）

```bash
lark-cli contact +user-search --keyword "你的手机号"
```

在结果里找到自己，复制 `open_id`。

---

## 方法三：让 bot 自己告诉你

如果上面都不行，临时加一段调试代码：

1. 编辑 `scripts/listener.sh`，在 `# 只处理` 那段之前加一行：

```bash
log listener "DEBUG: 收到消息，sender_id=$sender_id"
```

2. 运行 `./scripts/reload.sh`
3. 飞书私聊 bot 发任意消息
4. 看日志：

```bash
tail -1 logs/listener.log
```

输出里 `sender_id=ou_xxxxx` 那串就是你的 open_id。

5. 拿到后把那行 debug log 删掉，再 reload 一次。

---

## 验证

```bash
# 用 bot 给自己发个消息
lark-cli im +messages-send \
  --as bot \
  --user-id <你的open_id> \
  --text "test"
```

飞书里收到 "test"，说明 open_id 对了。

---

## 关于 open_id

- 同一个用户在**不同应用下** open_id 不一样（这是飞书设计）
- 所以这个 open_id 是绑死你这个 bot 应用的
- 换了 bot 应用要重新拿
