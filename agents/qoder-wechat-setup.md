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

启动器解析顺序是**全局 → 插件依赖 → npx**（全局优先，保证与常驻进程同版本）。后续所有桥接命令都通过这个入口执行，不要自己拼 dist 路径。

## 后端：先确定，再检查

桥接支持国际版 `qodercli` 与 CN 版 `qoderclicn`（或 dispatcher `qodercn`），由配置里的 `qoderBin` 决定。**检测优先，不主动推销 CN**：

- 已有配置 → 按它的后端走，不要擅自改 `qoderBin`。
- 没有配置 → 默认国际版；只有用户明确说要接 CN，或机器上只装了 CN CLI 时，才走 CN 分支。

```bash
# macOS / Linux：读后端，配置不存在时回落 qodercli
node -p "require(process.env.HOME + '/.config/qoder-wechat-bridge/config.json').qoderBin || 'qodercli'" 2>/dev/null || echo qodercli
```

```powershell
# Windows
$cfg = "$env:USERPROFILE\.config\qoder-wechat-bridge\config.json"
if (Test-Path $cfg) { (Get-Content $cfg -Raw | ConvertFrom-Json).qoderBin } else { "qodercli" }
```

结果是 `qoderclicn` / `qodercn` → CN 分支；其余 → 国际版分支。**只取 `qoderBin` 这一个字段，不要回显 token。**

需要装 CN CLI 时：`npm i -g @qodercn-ai/qoderclicn`（scope 是 `@qodercn-ai`）。npm 上的 `@qoder-ai/qoderclicn@0.0.1` 疑似抢注包，**不要装**。CN 凭据独立于国际版，装完必须 `qoderclicn login`，桌面端数据迁移不等于 CLI 已登录。

## 步骤

### 1. 环境检查（不能跳过）

```bash
node -v                      # 必须 >= 20
<对应后端的 CLI> --version    # 国际版 qodercli / CN qoderclicn
<对应后端的 CLI> -p -o json "只回复OK"   # 是否已登录
```

- Node 低于 20：停止，告诉用户升级方法（nodejs.org LTS 或 `n 22`）。
- CLI 不存在：说明需要先安装对应版本的 Qoder CLI（CN 见上一节）。
- 输出里有 `Not logged in` 或 `is_error: true`：让用户在终端执行对应后端的 `login`（`qodercli login` / `qoderclicn login`，浏览器授权），完成后再继续。这是一次点击，不用扫码。

### 2. 安装桥接包

判据是**有没有全局命令**，不是"能不能跑起来"：`bash "$QWB" --version` 在什么都没装的机器上也会成功（它会落到 `npx -y` 在线拉包），用它判断会永远以为已安装。

```bash
command -v qoder-wechat >/dev/null 2>&1 && qoder-wechat --version    # Windows 用 where qoder-wechat
```

- 找到了：已安装，进第 3 步。
- 没找到：执行 `npm i -g @jcyao/qoder-wechat-bridge`，装完再判一次。装的是 npm 上当时的最新版，用 `qoder-wechat --version` 确认。
- 装失败（无网络、权限不足等）：**告知后继续，不要卡在这一步**——告诉用户"现在先用在线方式跑，每次启动都要联网、首次会比较慢；等网络可用后重新执行本步骤，就能装成常驻命令"，然后接着做第 3 步。

安装报错时原样展示错误，不要擅自换镜像源或猜原因。

已装但版本旧于线上最新（`npm view @jcyao/qoder-wechat-bridge version`）时，提示用户可 `npm update -g @jcyao/qoder-wechat-bridge`；**不要在服务正跑着的时候擅自升级或重启**。

### 3. 判断是否已登录

```bash
bash "$QWB" status
```

如果显示 `Token：已配置` 且 `授权账号` 不为空，跳到第 5 步。

### 4. 扫码登录（唯一需要用户操作的一步）

先确认没有服务在跑：

```bash
pgrep -fl "qoder-wechat run|cli\.js run"
```

有的话告诉用户"已有服务在运行，换绑前需要先停止"，征得同意后执行 `bash "$QWB" stop`，按退出码分支：

- **0**（输出"桥接服务已停止"）：可以继续。
- **2**（输出"由 launchd 托管"）：**不要自己 kill**（会被自动拉起），把它打印的 `launchctl bootout …` 原样交给用户执行，等用户确认后再继续。
- **1**（提示超时未退出）：再执行一次 `stop`，第二次信号会立即结束。

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

启动前先确认**后端与已登录的 CLI 一致**：`qoderBin` 指向哪个 CLI，就必须是哪个 CLI 已登录。不一致时先问用户要接哪一版，不要自行改配置。

```bash
nohup bash "$QWB" run > "$HOME/.local/state/qoder-wechat-bridge/run.log" 2>&1 &
sleep 5
pgrep -fl "qoder-wechat run|cli\.js run"
tail -5 "$HOME/.local/state/qoder-wechat-bridge/run.log"
```

要求：进程只有 **1 个**，日志里有"服务已启动"。秒退或报错就按第 7 节排查，不要重复启动。

- 日志 `桥接服务启动` 那条含 `qoderBin` / `backend` / `memoryEnv` / `configDir`，用它确认后端真的生效（CN 应为 `backend=cn`、`memoryEnv=QODERCN_MEMORY_HEADLESS`）。
- 报「已在运行：pid …」并退出码 1 是**双锁保护，不是启动失败**：按它打印的处置命令先停旧实例，不要反复重试，也不要去删锁文件（除非确认机器上没有桥接实例，且删的是输出里指名的那个）。

### 6. 验证与交付

```bash
bash "$QWB" status
```

用中文汇报：**后端（国际版 / CN）**、工作目录、当前模型、授权账号、运行实例 pid（**不要回显 token**）。然后请用户在微信里找到「微信助手」发送 `/status`，确认能收到回复，并核对「后端」行与本机一致。

最后给一段简短总结：

- 常用命令：`/help`、`/status`、`/model`（`/model <序号>` 切换、`/model default` 恢复）、`/reset`、`/sessions`、`/switch`、`/new`、`/rename`、`/delete`、`/stop`
- 服务是前台进程，**电脑重启或关终端后要重新启动**；想让它常驻，见插件 README 的「开机自启」一节（macOS 用 LaunchAgent、Windows 用任务计划程序），本插件不代配。
- 限制：只支持单聊；一次大约 10 条回复额度；结果过长会补发

### 7. 失败排查

| 现象 | 处理 |
|---|---|
| sdk_worker_removed | 桥接版本过旧、未剥离继承的 `QODER_*` / `QODERCN_*`：升级 @jcyao/qoder-wechat-bridge 到最新版，或改用系统「终端」启动 |
| `SyntaxError: Invalid regular expression flags` | Node 仍是 16，切到 ≥ 20 |
| `Not logged in` | 对应后端登录：国际版 `qodercli login` / CN `qoderclicn login` |
| 已在运行：pid … | 双锁互斥保护。按输出先停旧实例（launchd 用 `bootout`）再起新的 |
| `stop` 后一时起不来 | 在途任务 3 秒内没排空，锁按设计保留，等任务落定才补释放（上界默认 10 分钟）；属预期 |
| CN 记忆没生效 / 模型列表不对 | `qoderBin` 不是标准名（wrapper、改名软链、直指 bundle）会回落国际版画像。改用 `qoderclicn`、`qodercn` 或绝对路径 |
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
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -like "*qoder-wechat*" -and $_.CommandLine -like "*run*" }
Get-Content "$dir\run.log" -Tail 5
```

注意：Windows 上没有 `say` / `afconvert`，`send-voice` 不可用（该功能本身也是实验性）；其余命令一致。Windows 的 `stop` 是直接结束进程，没有 POSIX 那套优雅关闭，正在跑的任务子进程可能残留——这条路径尚未在 Windows 真机验证。

## 禁止事项

- 不要打印、回显或写入聊天记录的 token。读配置只取需要的字段（如 `qoderBin`）。
- 已有服务运行时，不要再启动第二个（双锁会拒绝，旧版会抢游标）。
- 不要删不属于本次确认的锁文件；只有确认无实例在跑时，才执行 `run` 输出里指名的那条 `rm "<锁文件>"`。
- 不要为了"试试"反复执行登录（会触发风控）。
- 不要擅自改 `qoderBin`、升级正在运行的桥接包或重启用户的服务——切换后端与升级都要用户明确要求。
- 不要声称"已开机自启/已后台常驻"——桥接包本身不带自启，重启后必须手动 `run`。
- 不要把它说成群聊机器人或实时推送服务。