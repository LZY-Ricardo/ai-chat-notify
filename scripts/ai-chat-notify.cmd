@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

if not "%AI_CHAT_NOTIFY_LOG%"=="" (
  echo [%DATE% %TIME%] ai-chat-notify.cmd %*>>"%AI_CHAT_NOTIFY_LOG%"
) else if not "%CODEX_NOTIFY_LOG%"=="" (
  echo [%DATE% %TIME%] ai-chat-notify.cmd %*>>"%CODEX_NOTIFY_LOG%"
)

set "PS_EXE="
where pwsh >nul 2>nul && set "PS_EXE=pwsh"
if not defined PS_EXE where powershell >nul 2>nul && set "PS_EXE=powershell"
if not defined PS_EXE set "PS_EXE=powershell"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%ai-chat-notify.ps1" %*

exit /b 0

