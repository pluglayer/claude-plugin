@echo off
setlocal
set "PLUGLAYER_INSTALL_DIR=%~dp0"
set "PLUGLAYER_INSTALL_TARGET=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod 'https://raw.githubusercontent.com/pluglayer/claude-plugin/main/install.ps1' | Invoke-Expression } catch { Write-Error $_; exit 1 }"
exit /b %ERRORLEVEL%
