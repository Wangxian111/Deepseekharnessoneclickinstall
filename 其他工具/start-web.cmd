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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\start-web.ps1" %*
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo [Failed to start - see errors above / 启动失败，请查看上方错误信息]
  pause
)
endlocal & exit /b %EC%
