---
name: qoder-wechat
description: 管理本机「微信 ↔ Qoder」桥接服务。当用户说微信机器人、微信接 Qoder、桥接状态、扫码登录、微信发不出消息、查看微信桥接日志时使用。
---

# Qoder WeChat 桥接运维

本插件不实现消息通道，只负责在 Qoder 里操作 `@jcyao/qoder-wechat-bridge` 这个常驻进程。

## 调用方式

先判断系统，再选启动器（下文用 `<qwb>` 代指）：

- **macOS / Linux**：`bash "${QODER_PLUGIN_ROOT}/bin/qwb"`
- **Windows**：`"%QODER_PLUGIN_ROOT%\bin\qwb.cmd"`

`QODER_PLUGIN_ROOT` 未设置时，依次尝试：

```bash
node "../qoder-wechat-bridge/dist/cli.js"          # 本地开发（Windows 用 ..\qoder-wechat-bridge\dist\cli.js）
npx -y @jcyao/qoder-wechat-bridge                  # 已发布
```

Windows 下的进程与日志检查用 PowerShell，不要用 `pgrep`/`tail`/`grep`：

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*dist/cli.js run*" }
Get-Content "$env:USERPROFILE\.local\state\qoder-wechat-bridge\logs\bridge-$(Get-Date -Format yyyy-MM-dd).jsonl" -Tail 20
```

## 可用命令

| 命令 | 作用 |
|---|---|
| `status` | 查看 token、授权账号、工作目录、模型、会话与补发队列 |
| `login` | 扫码登录微信（会输出二维码，需要用户手机确认） |
| `notify "内容"` | 主动推送提醒；窗口不可用时自动排队，下次入站补发 |
| `send-file <路径> [--text "文案"]` | 把图片/文件/视频发到微信（≤10MB，文案与媒体分两条） |
| ~~`send-voice`~~ | **不要使用**：客户端不渲染出站语音；需要音频请用 `send-file` 发文件 |

微信用户侧内置命令：`/help`、`/status`、`/model`、`/reset`、`/stop`（停止当前任务，`/cancel` 同义）。
| `run` | 启动常驻桥接进程（前台运行，不要阻塞式调用） |

## 给用户发文件

任务产物需要发回微信时（截图、图表、报告、压缩包）：

```bash
<qwb> send-file /absolute/path/to/file.png --text "生成好了"
```

（Windows 路径用 `C:\...`，启动器换成 `bin\qwb.cmd`。）

- 图片（png/jpg/gif/webp）会直接在聊天里显示；其它类型作为文件发送；mp4/mov 作为视频。
- 单文件 ≤ 10MB；文案与媒体各占一条下行额度。
- 依赖最近一次入站留下的 `context_token`；没有窗口时会直接报错，先用文字回一句再发。

## 需要用户决策时

任务执行中需要用户确认、或发现重要情况要通知时，执行：

```bash
<qwb> notify "需要你确认：是否覆盖已有分支？"
```

注意：推送依赖 `context_token`（约 24h 窗口）。返回"已排队"说明窗口不可用，提醒会在用户下次发消息时补发，不要重复调用。

## 架构事实（回答用户前先记住）

- 消息链路：微信 → 桥接进程（长轮询）→ `qodercli -p` → 回传微信。
- 桥接进程与 Qoder Desktop 会话是两套东西：会话在 CLI 侧，桌面 GUI 历史里看不到。
- 官方 iLink 通道**只支持单聊**，且单条入站约 10 条下行额度、`context_token` 约 24h 时效。
- 同一 token 只能有一个消费者，重复启动会抢 `get_updates` 游标。

## 诊断顺序

1. `status` 看 token 是否已配置、授权账号是否为空。
2. `node -v` 必须 ≥ 20；`qodercli --version` 必须可用且已登录。
3. 进程是否在跑：`pgrep -fl "dist/cli.js run"`。
4. 日志：`~/.local/state/qoder-wechat-bridge/logs/bridge-$(date +%F).jsonl`。

## 禁止事项

- 不要打印或回显 `config.json` 里的 token。
- 不要为了"试试"反复执行 `login`（会触发风控）。
- 在已有桥接进程运行时，不要再次 `run`。
- 不要把本插件描述成"MCP 工具"或"实时推送"——它是命令行薄壳，实时性由常驻进程决定。
