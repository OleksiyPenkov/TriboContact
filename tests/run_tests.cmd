@echo off
setlocal
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
msbuild "%~dp0TriboContactTests.dproj" /t:Build /p:Config=Debug /p:Platform=Win64 /nologo /v:minimal
if errorlevel 1 exit /b %errorlevel%
if "%~1"=="" (
  "%~dp0..\out\bin\TriboContactTests.exe" -exit:Continue
) else (
  "%~dp0..\out\bin\TriboContactTests.exe" -exit:Continue --run:%1
)
exit /b %errorlevel%
