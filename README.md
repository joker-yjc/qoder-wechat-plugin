# qoder-wechat（Qoder 插件）

Qoder 插件薄壳：在 Qoder 里查看、诊断、启动本机的「微信 ↔ Qoder」桥接服务。

**它不实现微信通道。** 真正的收发、会话映射、额度控制都在独立进程
[`@jcyao/qoder-wechat-bridge`](https://www.npmjs.com/package/@jcyao/qoder-wechat-bridge) 里。
本插件只负责让 Qoder 的 agent 知道怎么操作它。

## 为什么不做 MCP

桥接包的本质是「通道 + 后台转发进程」，把它封成 MCP 会让包职责混乱，还要多维护一套协议。
插件用 Skill + 命令调用 CLI 已经足够：查看状态、诊断、扫码登录都是低频操作，
不需要结构化工具层。实时消息链路由常驻进程负责，插件不承担。

## 两种用法

**小白：交给 Agent。** 安装插件后，在 Qoder 里输入 `/qoder-wechat:setup`，`qoder-wechat-setup` Agent 会依次检查 Node、Qoder CLI 登录态、安装 npm 包、拉起扫码、后台启动并验证。你只需要用微信扫一次码。

**运维：用命令。** `/qoder-wechat:status` 看状态，`/qoder-wechat:doctor` 按顺序诊断。

## 目录

```
.qoder-plugin/plugin.json        # 插件清单
agents/qoder-wechat-setup.md     # 一键安装 Agent（含完整 runbook 与禁止事项）
bin/qwb                          # 命令启动器：插件依赖 → 本地仓库 → 全局 → npx
skills/qoder-wechat/SKILL.md     # 运维知识：何时用、诊断顺序、禁止操作
commands/setup.md                # /qoder-wechat:setup
commands/status.md               # /qoder-wechat:status
commands/doctor.md               # /qoder-wechat:doctor
```

## 依赖与版本

`package.json` 里现在是本地依赖，方便联调：

```json
"@jcyao/qoder-wechat-bridge": "file:../qoder-wechat-bridge"
```

桥接包发布到 npm 后，改成版本号即可：

```json
"@jcyao/qoder-wechat-bridge": "^0.1.0"
```

`bin/qwb` 的解析顺序是「插件自带依赖 → 同级本地仓库 → 全局安装的 `qoder-wechat` → `npx` 线上包」，
所以两种模式都能跑。

> 本地联调时注意：Qoder 安装插件时只复制插件文件，**不会复制 `node_modules`**。
> 所以要么先 `npm i -g ../qoder-wechat-bridge`（本地包全局安装），
> 要么等桥接包发布后用 `npx` 兜底。

## 安装

```bash
# 本地目录
qodercli plugins install .

# 或先校验
qodercli plugins validate .
```

安装后在 Qoder 里可以用：

- `/qoder-wechat:status` — 账号、目录、模型、会话、补发队列
- `/qoder-wechat:doctor` — 按顺序诊断 node / qodercli / 进程 / token / 日志

## 限制

- 没有入站推送：插件不能"微信来消息自动唤醒 Qoder"。
- 同一 token 只能有一个消费者；桥接进程在跑时不要再启动第二个。
- 扫码登录需要手机确认，属于人工步骤。
