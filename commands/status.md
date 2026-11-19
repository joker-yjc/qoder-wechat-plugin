---
description: 查看微信桥接状态（后端、账号、目录、模型、会话、运行实例、补发队列、隔离区、最近失败）
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

若 `QODER_PLUGIN_ROOT` 未设置，依次尝试全局安装的 `qoder-wechat status`，或 `npx -y @jcyao/qoder-wechat-bridge status`。启动器解析顺序是**全局 → 插件依赖 → npx**，与守护进程同版本。

2. 补取后端（**CLI `status` 不打印后端**，只有微信侧 `/status` 有「后端」行）：

```bash
# macOS / Linux —— 只取 qoderBin 一个字段，不要回显 token
node -p "require(process.env.HOME + '/.config/qoder-wechat-bridge/config.json').qoderBin || 'qodercli'"
```

```powershell
# Windows
(Get-Content "$env:USERPROFILE\.config\qoder-wechat-bridge\config.json" -Raw | ConvertFrom-Json).qoderBin
```

`qoderclicn` / `qodercn` 是 CN 版，其余（含空值回落的 `qodercli`）是国际版。

3. 同时检查进程与日志：

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

4. 用中文汇总：**后端（国际版 / CN）**、是否已登录、授权账号、工作目录、权限模式、当前模型、**运行实例（pid 与是否存活）**、会话数、待补发条数、隔离区条数、下行额度是否正常、**最近失败**、进程状态、最近一条日志。

- 「运行实例」与第 3 步的进程结果对不上时（如实例存活但 pgrep 找不到，或反之），说明运行记录过期或存在锁残留，转 `/qoder-wechat:doctor` 第 5 步。
- 待补发不为 0：说明会在下一次收到微信消息时补发。
- 隔离区不为 0：说明是连续失败后被搁置的消息，**不会自动送达**；手动恢复需停服编辑 `state.json` 的 `quarantine`，或等 7 天过期。
- 「最近失败」按 `errorClass` 说人话：`model_quota`=模型额度用尽（稍后重试或 `/model` 换模型）、`output_limit`=回答被截断（换输出上限更大的模型或拆小任务）、`auth`=CLI 凭据失效（本机执行对应后端 `login`）、`unknown`=未归类（去 `logs/diagnostics/` 看 `errorCode`）。**模型额度与微信下行额度是两回事，不要混着解释。**

**不要回显 token 内容。** 如果状态里 token 显示为"未配置"，提示用户执行 `/qoder-wechat:setup` 完成扫码登录。