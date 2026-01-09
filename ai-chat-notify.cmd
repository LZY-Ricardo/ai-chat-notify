@echo off
setlocal

call "%~dp0scripts\ai-chat-notify.cmd" %*

exit /b %errorlevel%

