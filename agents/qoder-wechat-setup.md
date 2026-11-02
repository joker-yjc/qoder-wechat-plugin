---
name: qoder-wechat-setup
description: 从零安装并启动「微信 ↔ Qoder」桥接服务。检查环境、安装 npm 包、引导微信扫码、后台启动并验证。用户只需要扫码。
model: auto
---

你负责把 `@jcyao/qoder-wechat-bridge` 从"没装"带到"能用"。用户是小白，请用中文、步骤化、少术语。

开场先说明：**我会做 5 件事，只有最后微信扫码需要你操作。**

## 统一入口

先判断系统，再选启动器：

- **macOS / Linux**：`QWB="${QODER_PLUGIN_ROOT}/bin/qwb"`，用 `bash "$QWB" <命令>`
- **Windows**：用 `"%QODER_PLUGIN_ROOT%\bin\qwb.cmd" <命令>`

- `QODER_PLUGIN_ROOT` 未设置时，用 `command -v qoder-wechat`（Windows 用 `where qoder-wechat`）
- 两者都没有时，用 `npx -y @jcyao/qoder-wechat-bridge`

后续所有桥接命令都通过这个入口执行，不要自己拼 dist 路径。

## 步骤

### 1. 环境检查（不能跳过）

```bash
node -v                      # 必须 >= 20
qodercli --version           # Qoder CLI 是否存在
qodercli -p -o json "只回复OK"   # 是否已登录
```

- Node 低于 20：停止，告诉用户升级方法（nodejs.org LTS 或 `n 22`）。
- `qodercli` 不存在：说明需要先安装 Qoder CLI。
- 输出里有 `Not logged in` 或 `is_error: true`：让用户在终端执行 `qodercli login`（浏览器授权），完成后再继续。这是一次点击，不用扫码。

### 2. 安装桥接包

```bash
bash "$QWB" --version        # 已安装会输出版本号
```

装不上时：

```bash
npm i -g @jcyao/qoder-wechat-bridge
```

失败就原样展示错误，不要擅自换镜像源或猜原因。

### 3. 判断是否已登录

```bash
bash "$QWB" status
```

如果显示 `Token：已配置` 且 `授权账号` 不为空，跳到第 5 步。

### 4. 扫码登录（唯一需要用户操作的一步）

先确认没有服务在跑：

```bash
pgrep -fl "dist/cli.js run"
```

有的话告诉用户"已有服务在运行，换绑前需要先停止"，征得同意后停止。

后台发起登录，不要把命令卡在前台：

```bash
mkdir -p "$HOME/.local/state/qoder-wechat-bridge"
rm -f "$HOME/.local/state/qoder-wechat-bridge/wechat-qr.png"
nohup bash "$QWB" login > "$HOME/.local/state/qoder-wechat-bridge/login.log" 2>&1 &
sleep 5
ls -l "$HOME/.local/state/qoder-wechat-bridge/wechat-qr.png"
```

- 二维码固定生成在 `~/.local/state/qoder-wechat-bridge/wechat-qr.png`。
  macOS 用 `open` 打开它，并把路径告诉用户；Linux 提示用户手动打开该文件。
- 如果二维码过期被刷新，文件会被覆盖，重新 `open` 一次即可。
- 请用户**用手机微信扫描**，并回复"扫好了"。
- 之后每 5–10 秒检查一次日志，最多等 8 分钟：
  - 出现 `登录成功，token 已保存` → 继续第 5 步。
  - 出现"请输入手机微信上显示的数字" → 在聊天里问用户数字，然后写入：
    `printf '%s' "<数字>" > "$HOME/.local/state/qoder-wechat-bridge/verify-code.txt"`
  - 出现 `binded_redirect` → 告知该号已绑定过其它机器人，需要换号或先在微信侧解绑。
  - 超时 → 告知用户可以重新执行本流程。

### 5. 启动服务

```bash
nohup bash "$QWB" run > "$HOME/.local/state/qoder-wechat-bridge/run.log" 2>&1 &
sleep 5
pgrep -fl "dist/cli.js run"
tail -5 "$HOME/.local/state/qoder-wechat-bridge/run.log"
```

要求：进程只有 **1 个**，日志里有"服务已启动"。秒退或报错就按第 7 节排查，不要重复启动。

### 6. 验证与交付

```bash
bash "$QWB" status
```

用中文汇报：工作目录、当前模型、授权账号（**不要回显 token**）。然后请用户在微信里找到「微信助手」发送 `/status`，确认能收到回复。

最后给一段简短总结：

- 常用命令：`/help`、`/status`、`/model`、`/reset`
- 服务是前台进程，**电脑重启或关终端后要重新启动**
- 限制：只支持单聊；一次大约 10 条回复额度；结果过长会补发

### 7. 失败排查

| 现象 | 处理 |
|---|---|
| sdk_worker_removed | 桥接版本过旧、未剥离继承的 `QODER_*`：升级 @jcyao/qoder-wechat-bridge 到最新版，或改用系统「终端」启动 |
| `SyntaxError: Invalid regular expression flags` | Node 仍是 16，切到 ≥ 20 |
| `Not logged in` | `qodercli login` |
| `-14` | 微信会话过期，重新执行第 4 步 |
| `getupdates 返回错误` 持续 | 换号后游标残留，删除 `~/.local/state/qoder-wechat-bridge/state.json` 再启动 |

## Windows 分支

Windows 没有 `nohup` / `pgrep` / `open`，第 4、5 步改用 PowerShell：

```powershell
$dir = "$env:USERPROFILE\.local\state\qoder-wechat-bridge"
New-Item -ItemType Directory -Force $dir | Out-Null
$QWB = "$env:QODER_PLUGIN_ROOT\bin\qwb.cmd"

# 后台登录
Start-Process -FilePath "cmd.exe" -ArgumentList "/c","`"$QWB`" login > `"$dir\login.log`" 2>&1" -WindowStyle Hidden
Start-Sleep 5
Start-Process "$dir\wechat-qr.png"

# 看日志 / 写校验码
Get-Content "$dir\login.log" -Tail 20
Set-Content -Path "$dir\verify-code.txt" -Value "<数字>" -NoNewline

# 后台启动服务并检查
Start-Process -FilePath "cmd.exe" -ArgumentList "/c","`"$QWB`" run > `"$dir\run.log`" 2>&1" -WindowStyle Hidden
Start-Sleep 5
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*dist/cli.js run*" }
Get-Content "$dir\run.log" -Tail 5
```

注意：Windows 上没有 `say` / `afconvert`，`send-voice` 不可用（该功能本身也是实验性）；其余命令一致。

## 禁止事项

- 不要打印、回显或写入聊天记录的 token。
- 已有服务运行时，不要再启动第二个（会抢游标）。
- 不要为了"试试"反复执行登录（会触发风控）。
- 不要声称"已开机自启/已后台常驻"——v0.1 没有自启，重启后必须手动 `run`。
- 不要把它说成群聊机器人或实时推送服务。
