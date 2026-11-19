@echo off
chcp 65001 >nul
setlocal
rem qwb：转发到 qoder-wechat-bridge 的 Windows 启动器
rem 解析顺序：全局命令 -> 插件自带依赖 -> npm 线上包
rem 全局优先是刻意的：常驻进程（任务计划/NSSM）跑的就是全局那份，
rem stop/status 的锁与运行记录语义必须与守护进程同版本，否则旧 CLI 会误判。

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
if not defined QODER_PLUGIN_ROOT set "QODER_PLUGIN_ROOT=%ROOT%"

where qoder-wechat >nul 2>nul
if %errorlevel%==0 (
  call qoder-wechat %*
  exit /b %errorlevel%
)

if exist "%ROOT%\node_modules\.bin\qoder-wechat.cmd" (
  call "%ROOT%\node_modules\.bin\qoder-wechat.cmd" %*
  exit /b %errorlevel%
)

npx -y @jcyao/qoder-wechat-bridge %*
exit /b %errorlevel%
