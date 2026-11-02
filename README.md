# qoder-wechat（Qoder 插件）

Qoder 插件薄壳：在 Qoder 里查看、诊断、启动本机的「微信 ↔ Qoder」桥接服务。

**它不实现微信通道。** 真正的收发、会话映射、额度控制都在独立进程
[`@jcyao/qoder-wechat-bridge`](https://www.npmjs.com/package/@jcyao/qoder-wechat-bridge)
（[源码](https://github.com/joker-yjc/qoder-wechat-bridge)）里。
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
bin/qwb                          # 命令启动器：插件依赖 → 全局 → npx
bin/qwb.cmd                      # Windows 版启动器，解析顺序同上
scripts/pack.sh                  # 打包发布用 zip（npm run pack）
skills/qoder-wechat/SKILL.md     # 运维知识：何时用、诊断顺序、禁止操作
commands/setup.md                # /qoder-wechat:setup
commands/status.md               # /qoder-wechat:status
commands/doctor.md               # /qoder-wechat:doctor
```

## 依赖与版本

插件只依赖 npm 上的 `@jcyao/qoder-wechat-bridge`，`package.json` 里声明为 `^0.1.0`；
桥接包要求 **Node ≥ 20** 和一个已登录的 Qoder CLI。

`bin/qwb` 的解析顺序是「插件自带依赖 → 全局安装的 `qoder-wechat` → `npx` 线上包」，三种装法都能跑：

```bash
npm run install:bridge                  # 装进插件目录的 node_modules
npm i -g @jcyao/qoder-wechat-bridge     # 或全局安装
                                        # 都不装 → 首次调用走 npx 拉线上包
```

> 分发时注意：Qoder 安装插件时只复制插件文件，**不会复制 `node_modules`**。
> 所以别人装完插件后，要么全局安装桥接包，要么让 `npx` 首次自动拉取。

## 安装

```bash
# 本地目录
qodercli plugins install .

# 或先校验
qodercli plugins validate .
```

安装后在 Qoder 里可以用：

- `/qoder-wechat:setup` — 引导式安装：检查环境、装包、扫码、启动、验证
- `/qoder-wechat:status` — 账号、目录、模型、会话、补发队列
- `/qoder-wechat:doctor` — 按顺序诊断 node / qodercli / 进程 / token / 日志

## 开机自启

桥接进程默认**不会自启**。`run` 是前台进程：重启电脑、关掉运行它的终端、或者进程被杀掉之后，
微信那边就不再回复了。想让它常驻，交给系统自带的服务管理器——插件和桥接包都不代管这件事。

**macOS（用户级 LaunchAgent）**

存成 `~/Library/LaunchAgents/com.example.qoder-wechat-bridge.plist`，
其中 `/usr/local/bin/qoder-wechat` 换成 `command -v qoder-wechat` 的实际输出（必须是全局安装的那份，不要指向 npx）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.qoder-wechat-bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/qoder-wechat</string>
    <string>run</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>WorkingDirectory</key>
  <string>/Users/yourname</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>/tmp/qoder-wechat-bridge.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/qoder-wechat-bridge.err.log</string>
</dict>
</plist>
```

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.qoder-wechat-bridge.plist
launchctl print gui/$(id -u)/com.example.qoder-wechat-bridge    # 查状态
launchctl bootout gui/$(id -u)/com.example.qoder-wechat-bridge   # 停止并取消自启
```

五点必须知道：

- **`PATH` 不能省。** launchd 给进程的默认 PATH 里没有 `/usr/local/bin`，桥接进程会因为找不到 `qodercli` 而起不来。把 `command -v qodercli` 所在目录写进上面的 `PATH`（Apple Silicon 上常是 `/opt/homebrew/bin`）。
- `WorkingDirectory` 填你的家目录（`echo $HOME`），与桥接配置里的工作目录保持一致，否则相对路径产物会落到别处。
- 触发时机是**用户登录**，不是开机。停在登录界面、或 FileVault 还没解锁时，服务不跑。
- 托管之后不要再手动 `run`，会和托管实例抢 `get_updates` 游标；也不要 `kill`——会被拉起。要停就执行 `qoder-wechat stop`，它识别出 launchd 托管后不会发信号，而是打印出可直接执行的 `launchctl bootout …` 命令。
- 升级桥接包（`npm update -g @jcyao/qoder-wechat-bridge`）不用改 plist，路径不变。

**Windows**：用「任务计划程序」建一个登录时触发的任务，命令指向全局安装生成的 `qoder-wechat.cmd run`；
想更贴近服务语义就用 NSSM 之类把它注册成 Windows 服务。

## 打包发布

```bash
npm run pack        # → dist/qoder-wechat-<version>.zip，并打印条目数、大小、sha256
```

打包清单以 git 为准（`git ls-files --cached --others --exclude-standard`），所以 `node_modules`、`dist/`
和被 `.gitignore` 忽略的内容不会进包；脚本还会校验 zip 根目录存在 `.qoder-plugin/plugin.json`。
文件名取自 `.qoder-plugin/plugin.json` 的 `name` + `version`，发新版前先改 `version`，并让 GitHub tag 与它一致。

拿到 zip 后两条分发路：拖进 GitHub Release 当 asset（直链可直接 `qodercli plugins install <URL>`），
或提交到 Qoder 官方市场。**不要用 tag 自动生成的源码包**——它会把仓库套在一层目录里，
违反「zip 根目录即插件根目录」，装不上。

## 限制

- 没有入站推送：插件不能"微信来消息自动唤醒 Qoder"。
- 同一 token 只能有一个消费者；桥接进程在跑时不要再启动第二个。
- 扫码登录需要手机确认，属于人工步骤。

## 许可

MIT，见 [LICENSE](LICENSE)。
