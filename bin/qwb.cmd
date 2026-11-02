@echo off
chcp 65001 >nul
setlocal
rem qwb：转发到 qoder-wechat-bridge 的 Windows 启动器
rem 解析顺序：插件自带依赖 -> 全局命令 -> npm 线上包

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
if not defined QODER_PLUGIN_ROOT set "QODER_PLUGIN_ROOT=%ROOT%"

if exist "%ROOT%\node_modules\.bin\qoder-wechat.cmd" (
  call "%ROOT%\node_modules\.bin\qoder-wechat.cmd" %*
  exit /b %errorlevel%
)

where qoder-wechat >nul 2>nul
if %errorlevel%==0 (
  call qoder-wechat %*
  exit /b %errorlevel%
)

npx -y @jcyao/qoder-wechat-bridge %*
exit /b %errorlevel%
