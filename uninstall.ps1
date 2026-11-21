# THE SUPER MOUSE — Official Fast Clean Uninstaller
$ErrorActionPreference = 'SilentlyContinue'
Clear-Host
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Red
Write-Host "               THE SUPER MOUSE — Uninstaller             " -ForegroundColor White
Write-Host "  =======================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  [*] Terminating any active SuperMouse processes..." -ForegroundColor Cyan
Stop-Process -Name "TheSuperMouse" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SuperMouseShellServer" -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object { $_.Path -like "*TheSuperMouse*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "  [*] Removing installed application files..." -ForegroundColor Cyan
$installDir = "$env:LOCALAPPDATA\TheSuperMouse"
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "  [*] Removing shortcuts & autostart..." -ForegroundColor Cyan
$desktop = [System.Environment]::GetFolderPath('Desktop')
$startup = [System.Environment]::GetFolderPath('Startup')
Remove-Item "$desktop\THE SUPER MOUSE.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$desktop\TheSuperMouse.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$startup\THE SUPER MOUSE.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$startup\TheSuperMouse.lnk" -Force -ErrorAction SilentlyContinue

Write-Host "  [*] Cleaning Windows Settings registration & cache..." -ForegroundColor Cyan
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TheSuperMouse" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\TheSuperMouse*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\SuperMouse*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "  [+] THE SUPER MOUSE has been completely and cleanly    " -ForegroundColor Green
Write-Host "      uninstalled from this PC.                          " -ForegroundColor Green
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
exit 0
