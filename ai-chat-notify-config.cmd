@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0configurator.ps1" %*

exit /b 0

