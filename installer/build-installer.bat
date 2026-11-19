@echo off
setlocal
set "SCRIPT=%~dp0build-installer.ps1"
if not exist "%SCRIPT%" (
    echo [build-installer] Script not found: "%SCRIPT%"
    exit /b 1
)
where pwsh >nul 2>nul
if errorlevel 1 (
    echo [build-installer] PowerShell 7 ^(pwsh^) was not found on PATH.
    exit /b 1
)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
