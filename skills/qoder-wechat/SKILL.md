---
name: qoder-wechat
description: 管理本机「微信 ↔ Qoder」桥接服务。当用户说微信机器人、微信接 Qoder、桥接状态、扫码登录、微信发不出消息、查看微信桥接日志、切换 qodercli/qoderclicn 后端时使用。
---

# Qoder WeChat 桥接运维

本插件不实现消息通道，只负责在 Qoder 里操作 `@jcyao/qoder-wechat-bridge` 这个常驻进程。
本文档对齐桥接包 **0.6.0**；命令语义跟着桥接包走，先用 `<qwb> --version` 确认实际版本再套用。

## 调用方式

先判断系统，再选启动器（下文用 `<qwb>` 代指）：

- **macOS / Linux**：`bash "${QODER_PLUGIN_ROOT}/bin/qwb"`
- **Windows**：`"%QODER_PLUGIN_ROOT%\bin\qwb.cmd"`

`QODER_PLUGIN_ROOT` 未设置时，依次尝试全局安装的 `qoder-wechat`（Windows 用 `where qoder-wechat`），都没有则用 `npx -y @jcyao/qoder-wechat-bridge`。

启动器解析顺序是**全局 → 插件依赖 → npx**。全局优先是刻意的：常驻进程跑的就是全局那份，`stop`/`status` 的锁与运行记录语义必须与守护进程同版本。若 `--version` 与运行实例的版本不一致，先解决错配再诊断，否则结论不可信。

Windows 下的进程与日志检查用 PowerShell，不要用 `pgrep`/`tail`/`grep`：

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*qoder-wechat*" -and $_.CommandLine -like "*run*" }
Get-Content "$env:USERPROFILE\.local\state\qoder-wechat-bridge\logs\bridge-$(Get-Date -Format yyyy-MM-dd).jsonl" -Tail 20
```

## 后端：国际版 qodercli / CN 版 qoderclicn

`qoderBin` 是**唯一**切换开关，三种写法等价（优先级：命令行 > 环境变量 > 配置文件）：

```bash
<qwb> run --qoder-bin qoderclicn      # 仅本次运行
QWB_QODER_BIN=qoderclicn              # 环境变量
# config.json 里 "qoderBin": "qoderclicn"   # 持久
```

后端画像由 bin 名**纯函数推导**：取 basename、去掉 `.cmd/.exe/.bat/.ps1`、转小写，命中 `qoderclicn` 或 `qodercn` 才是 CN，**其它任何名字一律回落国际版**。

| 项 | 国际版 `qodercli` | CN 版 `qoderclicn` / `qodercn` |
|---|---|---|
| 记忆开关 env | `QODER_MEMORY_HEADLESS` | `QODERCN_MEMORY_HEADLESS` |
| 配置目录覆盖 env | `QODER_CONFIG_DIR` | `QODERCN_CONFIG_DIR` |
| 用户配置目录 | `~/.qoder` | `~/.qoder-cn` |
| 自定义模型来源 | `~/.qoder/settings.json` | `~/.qoder-cn/settings.json` |
| 会话存储 | `~/.qoder/projects/…` | `~/.qoder-cn/projects/…` |
| 登录命令 | `qodercli login` | `qoderclicn login`（凭据独立，桌面端迁移≠CLI 已登录） |

**确认当前后端**（CLI `status` 不打印后端，别在那儿找）：

- 读 `~/.config/qoder-wechat-bridge/config.json` 的 `qoderBin` 字段（**只取这一个字段，不要回显 token**）。
- 微信里发 `/status`，看「后端」行。
- 启动日志 `桥接服务启动` 那条含 `qoderBin` / `backend` / `memoryEnv` / `configDir`。

后端相关的坑：

- **CN 记忆没生效**：先看 bin 名是否标准。自定义 wrapper、改名软链、直接指向 `bundle/qoderclicn.js` 都会回落国际版画像、设错记忆开关。改用标准名或绝对路径（如 `/usr/local/bin/qoderclicn`）。
- **覆盖变量设错后端会被忽略**：CN 只认 `QODERCN_CONFIG_DIR`，国际版只认 `QODER_CONFIG_DIR`。覆盖目录必须含登录态，否则 CLI 报 auth。建议写绝对路径（相对值按桥接进程 cwd 解析，不展开 `~`）。
- **切换后端后第一条消息开了新会话**：属预期。会话指针带 bin 标签，跨后端直接新建，不浪费一次失败往返。旧会话仍在原 CLI 存储，切回后经 `/sessions` + `/switch` 找回。
- **装 CN CLI**：`npm i -g @qodercn-ai/qoderclicn`（scope 是 `@qodercn-ai`）。npm 上的 `@qoder-ai/qoderclicn@0.0.1` 疑似抢注包，**勿装**。
- 桥接拉起 CLI 前会剥离全部 `QODER_*` 与 `QODERCN_*`（避免 `sdk_worker_removed`），再按后端补回记忆开关与配置目录。依赖这些 env 配置的 VPC/服务账号场景当前不支持。

## 可用命令

| 命令 | 作用 |
|---|---|
| `status` | 查看 token、授权账号、工作目录、权限模式、人设、附件目录、**运行实例**、会话、待补发队列、隔离区、下行额度、**最近失败** |
| `login` | 扫码登录微信（会输出二维码，需要用户手机确认） |
| `run` | 启动常驻桥接进程（前台运行，不要阻塞式调用）；旗标 `--cwd` `--permission-mode` `--model` `--qoder-bin` `--owner` `--allow` `--timeout-ms` `--inbox-dir` `--base-url`，仅本次生效不写配置 |
| `stop` | 停止**整个桥接服务**；退出码 0=已停、1=发信号后超时、2=launchd 托管未停。别与微信里的 `/stop`（只停当前任务）混淆 |
| `notify "内容"` | 主动推送提醒；窗口不可用时自动排队，下次入站补发。可选 `--user <id>` |
| `send-file <路径> [--text "文案"]` | 把图片/文件/视频发到微信（≤10MB，文案与媒体分两条）。可选 `--to <id>` |
| `clean [--days N] [--all]` | 清理入站附件（默认只删 7 天前的；`--days 1` 只留最近 1 天；`--all` 全删） |
| ~~`send-voice`~~ | **不要使用**：客户端不渲染出站语音；需要音频请用 `send-file` 发文件 |

微信用户侧内置命令：`/help`、`/status`（含「后端」行）、`/model`（列模型）、`/model <序号>`、`/model [provider] <名称>`、`/model default`（恢复 Auto）、`/reset`、`/stop`（停止当前任务，`/cancel` 同义）、`/sessions`（列会话，默认最多 10 条，`QWB_SESSION_LIST_LIMIT` 可配）、`/switch <序号|id|名称>`、`/new [名称]`、`/rename <名称>`（会消耗一次模型轮次）、`/delete <序号|id|名称>`（需再发 `/delete yes <序号>` 确认，60 秒内有效，不可恢复）。

`/switch`、`/new`、`/rename`、`/delete` 在任务执行中会被拒绝，需先 `/stop`；`/sessions` 只读随时可用。自定义 provider 的模型必须写成 `<providerId>/<model>`，只写短名会被 Qoder 静默回落到 `auto`——`/model` 内部已做这层映射。

## 实例互斥与停服

`run` 在开始长轮询前先占两把锁：`<stateDir>/run.lock`（同一状态目录只允许一个实例）与 `~/.local/state/qoder-wechat-bridge/instances/<sha1(botId) 前 16 位>.lock`（跨状态目录跑同一个 bot 也拦）。

- 已有存活实例时**拒绝启动并退出码 1**，打印对方 pid、状态目录、启动时间、工作目录与处置命令。launchd 在跑而你想手动起，看到这个提示是**保护不是故障**。
- 停服顺序：停止入站 → 取消已启动的 Qoder 任务 → 等队列排空（上限 3 秒）→ 清 `run.json` 并释放锁。
- **排空超时会保留锁**，等任务落定后补释放。此时立刻再起会被拒绝，最长等到在途任务结束（上界 `QWB_TIMEOUT_MS`，默认 10 分钟）。launchd 场景由 KeepAlive 的 30s 节流自然重试，不用人工干预。
- 锁内 pid 存活但命令行不像桥接进程（pid 被复用/僵尸）时，实现**不会删别人的锁**，只拒绝启动。确认无实例后按提示 `rm "<锁文件>"` 是唯一人工出口。
- **停止窗口内已拉取的消息会被丢弃**：游标在轮询阶段已推进，iLink 不再重投。正在下载附件或还在排队没起跑的消息不会再处理，只留一条 info 日志。让对方重发即可。

## 失败语义与去重

Qoder CLI 失败分两层：`errorKind`（传输层：`timeout`/`spawn`/`empty`/`parse`/`exit`/`is_error`）与 `errorClass`（业务语义），两者正交，都记在日志与诊断文件头。

| `errorClass` | 识别特征 | 用户看到 | 处置 |
|---|---|---|---|
| `model_quota` | `error_code=110`，或 `error_message` 含 `Billing daily count exceeded` | `模型额度已用尽：…` | 稍后重试或 `/model` 换模型 |
| `output_limit` | `error_code="max_output_tokens"`，或 `stop_reason="max_tokens"` 且 `is_error=true` | `回答被截断：…` | `/model` 换输出上限更大的模型，或拆小任务 |
| `auth` | `error_code="authentication_failed"` | `Qoder 凭据已失效：…` | **本机**执行对应后端登录命令，微信侧没有入口 |
| `unknown` | 以上都没命中 | `执行失败：…（退出码 N）` | 看诊断文件里的 `errorCode`，攒样本再补规则 |

- 前三类在**同一会话 10 分钟窗口**内只发一条完整提示，其余发 ≤60 字回执（如「同 23:13 那条，本次为第 4 次，已略」）。窗口用 `QWB_ERROR_DEDUP_WINDOW_MS` 调整，存在内存里，服务重启即重置。`unknown` **不去重**，每次发完整提示。
- **错误提示不进补发队列**：发送失败只写日志，不会塞满 outbox。
- **两种「额度」不要混**：`model_quota` 是 Qoder 侧模型调用额度（看 `status` 的「最近失败」行）；`quota` 是微信侧下行额度 `ret=-2`（看「下行额度」行）。两者毫无关系。
- `ret=-2` 按**额度耗尽**处理：消息留在 outbox，下次入站优先补发，**不计失败次数、不进隔离区**。连续多个窗口出现时 `status` 会告警。

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

- 消息链路：微信 → 桥接进程（长轮询）→ Qoder CLI（`qoderBin` 决定国际版还是 CN）→ 回传微信。
- 桥接进程与 Qoder Desktop 会话是两套东西：会话在 CLI 侧，桌面 GUI 历史里看不到。
- 官方 iLink 通道**只支持单聊**，且单条入站约 10 条下行额度、`context_token` 约 24h 时效。
- 出站有队列：待补发默认 200 条 / 24 小时，超限丢最旧；永久失败达 3 次（`poisonMaxAttempts`）或瞬时失败达 10 次（`transientMaxAttempts`）移入隔离区（默认 500 条 / 7 天），不再自动送达，后续消息照常发送。
- 同一 bot 只能有一个消费者，0.4.0 起由双锁强制（见上）。
- 服务默认**不自启**：`run` 是前台进程，重启电脑或关掉它的终端后，微信就不再收到回复了。要常驻得自己配 LaunchAgent / 任务计划程序（见 README「开机自启」）。用户说"昨天还好好的，今天不回"时，先问机器是否重启过、再看进程是否在跑。

## 诊断顺序

1. `<qwb> --version` 与运行实例版本是否一致（错配先解决，否则后续结论不可信）。
2. `<qwb> status` 看 token 是否已配置、授权账号是否为空、「运行实例」是否存活、「最近失败」是什么类别。
3. 取 `config.json` 的 `qoderBin` 确定后端，再查对应 CLI：`node -v` 必须 ≥ 20；`qodercli --version` 或 `qoderclicn --version` 必须可用且已登录。
4. 进程是否在跑：`pgrep -fl "qoder-wechat run|cli\.js run"`。
5. 日志：`~/.local/state/qoder-wechat-bridge/logs/bridge-$(date +%F).jsonl`；CLI 失败的完整输出在同级 `logs/diagnostics/YYYY-MM-DD/`（单文件 ≤64KB，保留 7 天，头部含 `errorClass`/`errorCode`）。

## 禁止事项

- 不要打印或回显 `config.json` 里的 token。读配置只取需要的字段（如 `qoderBin`）。
- 不要为了"试试"反复执行 `login`（会触发风控）。
- 在已有桥接进程运行时，不要再次 `run`；也不要把「已在运行：pid …」当成启动失败去反复重试。
- **不要删不属于本次确认的锁文件**。只有在确认机器上没有桥接实例后，才执行 `run` 输出里给出的那条 `rm "<锁文件>"`。
- 停止一律用 `stop`，不要自己 `kill`：被 LaunchAgent 托管时 `kill` 会在 `ThrottleInterval` 内被重新拉起，中断更难排查。`stop` 会自己识别托管关系，只把 `launchctl bootout gui/<uid>/<label>` 打印出来交给你执行（退出码 2）；发信号后最多等 10 秒，超时返回 1，再执行一次 `stop`（第二次信号立即结束）。
- 不要为了"修复"去改 `qoderBin` 或重启用户正在跑的服务，除非用户明确要求切换后端。
- 不要把本插件描述成"MCP 工具"或"实时推送"——它是命令行薄壳，实时性由常驻进程决定。