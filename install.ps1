# THE SUPER MOUSE — 1-Click Fast Windows Installer
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "               THE SUPER MOUSE — Windows Setup           " -ForegroundColor White
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""

$installDir = "$env:LOCALAPPDATA\TheSuperMouse"
$zipPath = "$env:TEMP\TheSuperMouse_Full.zip"
$downloadUrl = "https://github.com/getsupermouse/supermousenewnupdates/releases/download/v1.0/TheSuperMouse_Full.zip"

Write-Host "  [*] Downloading THE SUPER MOUSE from GitHub..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

Write-Host "  [*] Installing to $installDir..." -ForegroundColor Cyan
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# Create Desktop Shortcut
$wsh = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')
$targetExe = "$installDir\TheSuperMouse\TheSuperMouse.exe"
$workingDir = "$installDir\TheSuperMouse"
if (-not (Test-Path $targetExe)) {
    if (Test-Path "$installDir\TheSuperMouse.exe") {
        $targetExe = "$installDir\TheSuperMouse.exe"
        $workingDir = "$installDir"
    } elseif (Test-Path "$installDir\TheSuperMouse\main_app.py") {
        $targetExe = "$installDir\TheSuperMouse\main_app.py"
        $workingDir = "$installDir\TheSuperMouse"
    } elseif (Test-Path "$installDir\main_app.py") {
        $targetExe = "$installDir\main_app.py"
        $workingDir = "$installDir"
    }
}
$shortcut = $wsh.CreateShortcut("$desktop\THE SUPER MOUSE.lnk")
$shortcut.TargetPath = $targetExe
$shortcut.WorkingDirectory = $workingDir
$shortcut.Save()

# Windows Startup folder (autostart)
$startup = [System.Environment]::GetFolderPath('Startup')
$autoShortcut = $wsh.CreateShortcut("$startup\THE SUPER MOUSE.lnk")
$autoShortcut.TargetPath = $targetExe
$autoShortcut.WorkingDirectory = $workingDir
$autoShortcut.Save()

Write-Host "  [+] INSTALLED SUCCESSFULLY! Desktop shortcut & Autostart configured." -ForegroundColor Green
Write-Host "  [*] Launching THE SUPER MOUSE..." -ForegroundColor Yellow
Start-Process -FilePath $targetExe -WorkingDirectory $workingDir
