@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
where powershell >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PowerShell not found on this system.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\panel-server.ps1" %*
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo [Panel exited with errors - see above / 面板异常退出，请查看上方信息]
  pause
)
endlocal & exit /b %EC%
