# THE SUPER MOUSE — Official Fast Clean Uninstaller & Cursor Restorer
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
Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'pythonw.exe' -or $_.Name -eq 'python.exe') -and $_.CommandLine -like '*main_app.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1

Write-Host "  [*] Restoring Windows 10/11 Default White Cursors..." -ForegroundColor Cyan
$cursorReg = 'HKCU:\Control Panel\Cursors'
$cursorNames = @('Arrow', 'Hand', 'Wait', 'IBeam', 'Help', 'AppStarting', 'No', 'NWPen', 'SizeAll', 'SizeNESW', 'SizeNS', 'SizeNWSE', 'SizeWE', 'UpArrow')
foreach ($cName in $cursorNames) {
    Remove-ItemProperty -Path $cursorReg -Name $cName -Force -ErrorAction SilentlyContinue
}
Set-ItemProperty -Path $cursorReg -Name '(default)' -Value 'Windows Default' -Force
Set-ItemProperty -Path $cursorReg -Name 'Scheme Source' -Value 1 -Force
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Accessibility' -Name 'CursorSize' -Value 1 -Force -ErrorAction SilentlyContinue

try {
    $csharpCode = @"
using System;
using System.Runtime.InteropServices;
public class WinCursorReset {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    [DllImport("user32.dll")]
    public static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);
    [DllImport("user32.dll")]
    public static extern bool SetSystemCursor(IntPtr hcur, uint id);
}
"@
    Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue
    [WinCursorReset]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x01 -bor 0x02)
    $ocrIds = @(32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650)
    foreach ($cid in $ocrIds) {
        $h = [WinCursorReset]::LoadCursor([IntPtr]::Zero, $cid)
        if ($h -ne [IntPtr]::Zero) { [WinCursorReset]::SetSystemCursor($h, $cid) }
    }
} catch {}

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

# Clean PATH
try {
    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($oldPath -like "*TheSuperMouse\bin*") {
        $newPath = ($oldPath -split ';' | Where-Object { $_ -and $_ -notlike "*TheSuperMouse\bin*" }) -join ';'
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
} catch {}

Write-Host "  [*] Cleaning Windows Settings registration & cache..." -ForegroundColor Cyan
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TheSuperMouse" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\TheSuperMouse*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\SuperMouse*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "  [+] THE SUPER MOUSE has been completely and cleanly    " -ForegroundColor Green
Write-Host "      uninstalled from this PC.                          " -ForegroundColor Green
Write-Host "  [+] Windows 10/11 Default White Cursors Restored!      " -ForegroundColor Green
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
exit 0
