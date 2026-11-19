---
description: 诊断微信桥接常见问题（node、桥接版本、Qoder CLI 后端、进程与锁、token、日志）
---

# /qoder-wechat:doctor

按顺序检查，每项给出结论（正常 / 异常 + 原因 + 修复命令）。**先判断系统**：Windows 用 PowerShell 的 `Get-CimInstance` / `Get-Content` / `Select-String` / `ConvertFrom-Json`，不要用 `pgrep` / `tail` / `grep`；启动器用 `bin\qwb.cmd`。下文 `<qwb>` 代指启动器（macOS/Linux `bash "${QODER_PLUGIN_ROOT}/bin/qwb"`）。

1. **Node 版本**：`node -v`，必须 ≥ 20。低于 20 时提示用 `n 22` 或安装更新版本。

2. **桥接版本与后端**（先做这步，版本错配会让后面所有结论不可信）：

```bash
bash "${QODER_PLUGIN_ROOT}/bin/qwb" --version     # 薄壳实际调用的版本
pgrep -fl "qoder-wechat run|cli\.js run"          # 守护进程实际跑的是哪个路径
node -p "require(process.env.HOME + '/.config/qoder-wechat-bridge/config.json').qoderBin || 'qodercli'"
```

```powershell
& "$env:QODER_PLUGIN_ROOT\bin\qwb.cmd" --version
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*qoder-wechat*" -and $_.CommandLine -like "*run*" } | Select-Object ProcessId, CommandLine
(Get-Content "$env:USERPROFILE\.config\qoder-wechat-bridge\config.json" -Raw | ConvertFrom-Json).qoderBin
```

- 启动器解析顺序是**全局 → 插件依赖 → npx**。拿守护进程那个路径直接执行 `--version`，与薄壳版本比对；不一致就是错配，先统一版本再诊断（`npm update -g @jcyao/qoder-wechat-bridge`，或删掉插件目录的 `node_modules`）。
- 第三条命令给出当前后端：`qoderclicn` / `qodercn` 是 CN，其余（含空值回落的 `qodercli`）是国际版。**第 3 步必须用这个结果，不要硬写 `qodercli`。**
- 只取 `qoderBin` 这一个字段，**不要回显 token**。

3. **Qoder CLI（按第 2 步得到的后端）**：国际版查 `qodercli --version`，CN 查 `qoderclicn --version`。命令不存在就提示装对应 CLI（CN 是 `npm i -g @qodercn-ai/qoderclicn`，**勿装 `@qoder-ai/qoderclicn@0.0.1`，疑似抢注包**）。报 `Not logged in` 时提示执行对应后端的 `login`（`qodercli login` / `qoderclicn login`）浏览器授权——**CN 凭据独立于国际版，桌面端迁移不等于 CLI 已登录**。

4. **桥接配置**：`<qwb> status`，看 token 与授权账号是否为空，并读「运行实例」「最近失败」「下行额度」三行。注意 **CLI `status` 不打印后端**，后端只在第 2 步的配置字段或微信侧 `/status` 的「后端」行里。

5. **进程单实例与锁**：macOS/Linux `pgrep -fl "qoder-wechat run|cli\.js run"`；Windows 用第 2 步那条 `Get-CimInstance`。模式必须同时覆盖 npx、全局安装与 `node dist/cli.js` 三种启动形态，只写 `dist/cli.js run` 会漏掉前两种。
   - 0.4.0 起由双锁强制单实例：`<stateDir>/run.lock` 与 `~/.local/state/qoder-wechat-bridge/instances/<sha1(botId) 前 16 位>.lock`。`run` 报「已在运行：pid …」并退出码 1 是**保护不是故障**，按它打印的处置命令先停旧实例。
   - 停掉实例用 `<qwb> stop`：退出码 0=已停、1=发信号后超时（再执行一次 `stop`，第二次信号立即结束）、2=launchd 托管未停（把它打印的 `launchctl bootout …` 交给用户执行，**不要自己 kill**，会被 KeepAlive 拉起）。
   - `stop` 后新实例一时起不来属预期：在途任务 3 秒内没排空时锁按设计保留，等任务落定才补释放（上界 `QWB_TIMEOUT_MS`，默认 10 分钟）。
   - 对方 pid 看着像无关进程（pid 复用/僵尸）时实现不会删别人的锁；**确认机器上没有桥接实例后**，才执行 `run` 输出里给出的那条 `rm "<锁文件>"`。

6. **日志错误**：macOS/Linux `grep -E '"(error|warn)"' "$HOME/.local/state/qoder-wechat-bridge/logs/bridge-$(date +%F).jsonl" | tail -10`；Windows 用 `Select-String -Pattern '"error"|"warn"' -Path "$env:USERPROFILE\.local\state\qoder-wechat-bridge\logs\bridge-$(Get-Date -Format yyyy-MM-dd).jsonl" | Select-Object -Last 10`。CLI 失败的完整 stdout / stderr 落在同级 `logs/diagnostics/YYYY-MM-DD/`（单文件 ≤64KB，保留 7 天，头部含 `errorClass` / `errorCode`），要看详细报错去那里找。

常见错误对照：

| 现象 | 原因 | 处理 |
|---|---|---|
| `sdk_worker_removed` | 从 Qoder 桌面终端启动，继承了 `QODER_*` / `QODERCN_*` | 升级到最新版（`npm update -g @jcyao/qoder-wechat-bridge`，spawn CLI 前已剥离两个前缀，仅按后端补回记忆开关与配置目录）；或改从系统终端启动 |
| `SyntaxError: Invalid regular expression flags` | node 是 16 | `n 22` |
| `Not logged in · Please run /login` | 对应后端的 CLI 未登录 | 国际版 `qodercli login` / CN `qoderclicn login` |
| `模型额度已用尽`（`errorClass=model_quota`） | CLI 报 `error_code=110` 或 `Billing daily count exceeded` | 稍后重试或微信发 `/model` 换模型；不是硬性全天封锁 |
| `回答被截断`（`errorClass=output_limit`） | `max_output_tokens`，或 `stop_reason=max_tokens` 且 `is_error=true` | `/model` 换输出上限更大的模型，或把任务拆小 |
| `Qoder 凭据已失效`（`errorClass=auth`） | CLI 登录态失效 | **本机**执行对应后端 `login`，微信侧没有入口 |
| `执行失败：…（退出码 N）`（`errorClass=unknown`） | 传输层失败或错误码未收录 | 看 `logs/diagnostics/` 头部的 `errorCode`；这类不去重，每次发完整提示 |
| 反复收到「同 HH:MM 那条，本次为第 N 次，已略」 | 前三类语义错误在 10 分钟去重窗口内的短回执 | 属预期行为，不是消息被无视；窗口用 `QWB_ERROR_DEDUP_WINDOW_MS` 调整，重启即重置 |
| `ret=-2` | 微信下行额度耗尽 / context_token 失效 | 消息留在 outbox，下次入站优先补发，**不计失败也不隔离**；连续出现看 `status` 的额度告警 |
| 已在运行：pid … | 双锁互斥（或旧版实例被 `run.json` 兜底拦下） | 按输出先停旧实例再起新的；launchd 用 `bootout` |
| `stop` 退出码 2 | launchd 托管，未真正停止 | 执行它打印的 `launchctl bootout gui/<uid>/<label>` |
| 刚重启过，某条消息没回 | 停止窗口内已拉取但未起跑的消息被丢弃（游标已推进，iLink 不再重投） | 属设计取舍，请对方重发 |
| `-14` | 微信会话过期 | 重新登录，但不要高频重登 |
| `binded_redirect` | 微信号已绑过其它机器人 | 先解绑或换号 |
| CN 记忆没生效 | `qoderBin` 不是标准名（wrapper / 改名软链 / 直指 bundle），回落国际版画像设错开关 | 改用 `qoderclicn`、`qodercn` 或绝对路径 |
| `/model` 列不出 CN 自定义模型 | `~/.qoder-cn/settings.json` 的 `providers` 缺失或损坏 | 自定义列表降级为空（内置模型仍在），不报错；修配置即可 |
| 任务跑完但微信没收到 | 队列积压或消息进了隔离区 | `<qwb> status` 看「待补发」「隔离区」「下行额度」；隔离区里的消息不会自动送达 |

最后用中文给出"最可能的问题 + 下一步动作"，不要一次性列出无关项。