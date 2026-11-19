#requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$AppVersion = '1.0.0',
    [string]$RsVars     = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat',
    [string]$Iscc       = '',
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'

$installerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir      = Split-Path -Parent $installerDir
if (-not $OutputRoot) { $OutputRoot = Join-Path $repoDir 'dist' }

$iss      = Join-Path $installerDir 'tribocontact.iss'
$guiProj  = Join-Path $repoDir 'TriboContact.dproj'
$cliProj  = Join-Path $repoDir 'TriboContactCLI.dproj'
$guiExe   = Join-Path $repoDir 'out\bin\TriboContact.exe'
$cliExe   = Join-Path $repoDir 'out\bin\TriboContactCLI.exe'
$helpSrc  = Join-Path $repoDir 'Help'
$matJson  = Join-Path $repoDir 'data\materials.json'
$exSrc    = Join-Path $repoDir 'examples'
$licFile  = Join-Path $repoDir 'LICENSE'
$readme   = Join-Path $repoDir 'README.md'

foreach ($p in @($iss, $guiProj, $cliProj, $helpSrc, $matJson, $exSrc, $licFile, $readme)) {
    if (-not (Test-Path $p)) { throw "Required path not found: $p" }
}

function Invoke-Delphi([string]$Command, [string]$What) {
    if (-not (Test-Path $RsVars)) { throw "rsvars.bat not found: $RsVars (pass -RsVars)." }
    & cmd.exe /c "call `"$RsVars`" && $Command"
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)." }
}

if (-not $SkipBuild) {
    $started = Get-Date
    Remove-Item (Join-Path $repoDir 'TriboContact.res') -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $repoDir 'TriboContactCLI.res') -ErrorAction SilentlyContinue
    Invoke-Delphi "msbuild `"$cliProj`" /t:Rebuild /p:Config=Release /p:Platform=Win64 /nologo /v:minimal" 'TriboContactCLI Release build'
    Invoke-Delphi "msbuild `"$guiProj`" /t:Rebuild /p:Config=Release /p:Platform=Win64 /nologo /v:minimal" 'TriboContact Release build'
    foreach ($e in @($guiExe, $cliExe)) {
        if (-not (Test-Path $e) -or (Get-Item $e).LastWriteTime -lt $started) {
            throw "Build did not produce a fresh exe: $e"
        }
    }
}

foreach ($e in @($guiExe, $cliExe)) {
    if (-not (Test-Path $e)) { throw "Exe missing (run without -SkipBuild): $e" }
}

$stageDir = Join-Path $OutputRoot 'installer-stage'
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir, (Join-Path $stageDir 'data'), (Join-Path $stageDir 'examples') | Out-Null

Copy-Item $guiExe $stageDir
Copy-Item $cliExe $stageDir
Copy-Item $licFile $stageDir
Copy-Item $readme $stageDir
Copy-Item $matJson (Join-Path $stageDir 'data')
Copy-Item (Join-Path $exSrc '*') (Join-Path $stageDir 'examples') -Recurse
Copy-Item $helpSrc (Join-Path $stageDir 'Help') -Recurse

function Resolve-Iscc([string]$Override) {
    if ($Override) {
        if (Test-Path $Override) { return $Override }
        throw "ISCC.exe not found at -Iscc path: $Override"
    }
    $cmd = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' }),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    foreach ($hive in @('HKLM', 'HKCU')) {
        try {
            $reg = Get-ItemProperty "${hive}:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1" -ErrorAction Stop
            if ($reg.InstallLocation) {
                $p = Join-Path $reg.InstallLocation 'ISCC.exe'
                if (Test-Path $p) { return $p }
            }
        } catch { }
    }
    throw "ISCC.exe (Inno Setup 6) not found. Install it or pass -Iscc <path>."
}

$isccPath = Resolve-Iscc $Iscc
Write-Host "Building TriboContact installer v$AppVersion with ISCC: $isccPath" -ForegroundColor Cyan

& $isccPath "/DAppVersion=$AppVersion" "/DStageDir=$stageDir" "/DRepoDir=$repoDir" "/DOutputRoot=$OutputRoot" $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC compile failed (exit $LASTEXITCODE)." }

$setup = Join-Path $OutputRoot "TriboContact-Setup-$AppVersion.exe"
if (-not (Test-Path $setup)) { throw "Setup exe not produced: $setup" }
$sizeMB = [math]::Round((Get-Item $setup).Length / 1MB, 2)
Write-Host "Installer built: $setup ($sizeMB MB)" -ForegroundColor Green
