@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0..\"
set "DSH_HOME=%~dp0..\data\dsh"
if not exist "%DSH_HOME%" mkdir "%DSH_HOME%" >nul 2>nul
set "npm_config_cache=%~dp0..\tools\npm-cache"
if exist "%~dp0..\tools\node\node.exe" (
  if not exist "%~dp0..\tools\node\dsh.cmd" (
    echo [ERROR] DeepSeek Harness not installed yet / 尚未安装 DeepSeek Harness
    echo Run ..\开始安装.cmd, or double-click start-web.cmd to auto-install / 请运行 ..\开始安装.cmd，或双击本目录的 start-web.cmd 自动安装并启动
    pause
    exit /b 1
  )
  set "PATH=%~dp0..\tools\node;%PATH%"
  set "DSH_BIN=%~dp0..\tools\node\dsh.cmd"
) else (
  where dsh >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] DeepSeek Harness not found / 未找到 DeepSeek Harness
    echo Run ..\开始安装.cmd, or double-click start-web.cmd to auto-install / 请运行 ..\开始安装.cmd，或双击本目录的 start-web.cmd 自动安装并启动
    pause
    exit /b 1
  )
  set "DSH_BIN=dsh"
)
title DeepSeek Harness - dsh
if "%~1"=="" goto interactive
"%DSH_BIN%" %*
set "EC=%ERRORLEVEL%"
endlocal & exit /b %EC%

:interactive
echo.
echo ==========================================================
echo   DeepSeek Harness - dsh 命令行
echo   输入 dsh 命令后回车，例如:
echo     dsh --help            查看帮助
echo     dsh web               启动 Web UI
echo     dsh --version         查看版本
echo   输入 exit 关闭本窗口
echo ==========================================================
echo.
cmd /k
endlocal & exit /b 0
