@echo off
setlocal
set "EXE=%~dp0out\bin\TriboContact.exe"
if not exist "%EXE%" (
  call "%~dp0build.cmd"
  if errorlevel 1 exit /b %errorlevel%
)
start "" "%EXE%"
