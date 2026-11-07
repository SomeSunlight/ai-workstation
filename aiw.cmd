@echo off
rem AIW native Windows entry point. In a checkout: .\aiw
rem After optional user-level registration: aiw from any directory.
setlocal
where.exe pwsh.exe >nul 2>&1
if errorlevel 1 (
  echo [XX] PowerShell 7 is required: pwsh.exe was not found in PATH. 1>&2
  exit /b 1
)
if /I "%~1"=="register" goto :register
if /I "%~1"=="unregister" goto :unregister
if /I "%~1"=="command-status" goto :command_status
pwsh.exe -NoProfile -File "%~dp0bootstrap\windows\Services.ps1" %*
exit /b %errorlevel%
:register
pwsh.exe -NoProfile -File "%~dp0bootstrap\windows\Register-AiwCommand.ps1" -Action Install
exit /b %errorlevel%
:unregister
pwsh.exe -NoProfile -File "%~dp0bootstrap\windows\Register-AiwCommand.ps1" -Action Remove
exit /b %errorlevel%
:command_status
pwsh.exe -NoProfile -File "%~dp0bootstrap\windows\Register-AiwCommand.ps1" -Action Status
exit /b %errorlevel%
