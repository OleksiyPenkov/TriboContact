@echo off
setlocal
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
del /q "%~dp0TriboContact.res" 2>nul
del /q "%~dp0TriboContactCLI.res" 2>nul
msbuild "%~dp0TriboContactCLI.dproj" /t:Rebuild /p:Config=Debug /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
msbuild "%~dp0TriboContactCLI.dproj" /t:Rebuild /p:Config=Release /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
msbuild "%~dp0TriboContact.dproj" /t:Rebuild /p:Config=Debug /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
msbuild "%~dp0TriboContact.dproj" /t:Rebuild /p:Config=Release /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
msbuild "%~dp0tests\TriboContactTests.dproj" /t:Rebuild /p:Config=Debug /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
if exist "%~dp0Help" (
  xcopy "%~dp0Help" "%~dp0out\bin\Help" /E /I /Y /Q >nul
  if errorlevel 1 exit /b %errorlevel%
)
exit /b 0
