---
description: 诊断微信桥接常见问题（node、qodercli、进程、token、日志）
---

# /qoder-wechat:doctor

按顺序检查，每项给出结论（正常 / 异常 + 原因 + 修复命令）。**先判断系统**：Windows 用 PowerShell 的 `Get-CimInstance` / `Get-Content` / `Select-String`，不要用 `pgrep` / `tail` / `grep`；启动器用 `bin\qwb.cmd`。

1. **Node 版本**：`node -v`，必须 ≥ 20。低于 20 时提示用 `n 22` 或安装更新版本。
2. **Qoder CLI**：`qodercli --version`；若报 `Not logged in`，提示用户执行 `qodercli login` 浏览器授权。
3. **桥接配置**：`<qwb> status`（macOS/Linux 用 `bash bin/qwb`，Windows 用 `bin\qwb.cmd`），看 token 与授权账号是否为空。
4. **进程单实例**：macOS/Linux `pgrep -fl "qoder-wechat run|cli\.js run"`；Windows `Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*qoder-wechat*" -and $_.CommandLine -like "*run*" }`。多于 1 个说明在抢游标，需保留一个。模式必须同时覆盖 npx、全局安装与 `node dist/cli.js` 三种启动形态，只写 `dist/cli.js run` 会漏掉前两种。停掉实例用 `<qwb> stop`，它停的是运行记录里登记的那个 pid；登记之外的残留实例要按上面的命令定位后单独处理。
5. **日志错误**：macOS/Linux `grep -E '"(error|warn)"' "$HOME/.local/state/qoder-wechat-bridge/logs/bridge-$(date +%F).jsonl" | tail -10`；Windows 用 `Select-String -Pattern '"error"|"warn"' -Path "$env:USERPROFILE\.local\state\qoder-wechat-bridge\logs\bridge-$(Get-Date -Format yyyy-MM-dd).jsonl" | Select-Object -Last 10`。

常见错误对照：

| 现象 | 原因 | 处理 |
|---|---|---|
| `sdk_worker_removed` | 桥接版本过旧，未剥离继承的 `QODER_*` | 升级到 ≥ 0.1.0（已在 spawn qodercli 前剥离 `QODER_*`，仅补回 `QODER_MEMORY_HEADLESS`）；或改从系统终端启动 |
| `SyntaxError: Invalid regular expression flags` | node 是 16 | `n 22` |
| `Not logged in · Please run /login` | qodercli 未登录 | `qodercli login` |
| `ret=-2` | context_token 过期或下行额度耗尽 | 结果会进补发队列，下次入站重试 |
| `-14` | 微信会话过期 | 重新登录，但不要高频重登 |
| `binded_redirect` | 微信号已绑过其它机器人 | 先解绑或换号 |

最后用中文给出"最可能的问题 + 下一步动作"，不要一次性列出无关项。
