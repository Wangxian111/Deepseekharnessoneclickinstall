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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\uninstall.ps1" %*
endlocal & exit /b %ERRORLEVEL%
