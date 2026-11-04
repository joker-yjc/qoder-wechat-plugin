---
description: 查看微信桥接状态（账号、目录、模型、会话、补发队列、隔离区）
---

# /qoder-wechat:status

1. 执行状态命令（先判断系统）：

```bash
# macOS / Linux
bash "${QODER_PLUGIN_ROOT}/bin/qwb" status
```

```bat
rem Windows
"%QODER_PLUGIN_ROOT%\bin\qwb.cmd" status
```

若 `QODER_PLUGIN_ROOT` 未设置，依次尝试全局安装的 `qoder-wechat status`，或 `npx -y @jcyao/qoder-wechat-bridge status`。

2. 同时检查进程与日志：

```bash
# macOS / Linux
pgrep -fl "qoder-wechat run|cli\.js run" || echo "未运行"
tail -5 "$HOME/.local/state/qoder-wechat-bridge/logs/bridge-$(date +%F).jsonl" 2>/dev/null
```

```powershell
# Windows
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*qoder-wechat*" -and $_.CommandLine -like "*run*" }
Get-Content "$env:USERPROFILE\.local\state\qoder-wechat-bridge\logs\bridge-$(Get-Date -Format yyyy-MM-dd).jsonl" -Tail 5
```

3. 用中文汇总：是否已登录、授权账号、工作目录、当前模型、会话数、待补发条数、隔离区条数、下行额度是否正常、进程状态、最近一条日志。
   待补发或隔离区不为 0 时，顺带说明：待补发会在下一次收到微信消息时补发；隔离区是连续失败后被搁置的消息，不会自动送达。

**不要回显 token 内容。** 如果状态里 token 显示为"未配置"，提示用户执行 `/qoder-wechat:setup` 完成扫码登录。
