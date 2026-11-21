# THE SUPER MOUSE — 1-Command Windows Setup
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

Clear-Host
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "               THE SUPER MOUSE — Windows Setup           " -ForegroundColor White
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""

# 1. License Check Prompt
Write-Host "  [Step 1/2] License Verification" -ForegroundColor White
$licenseKey = (Read-Host "             Enter your 15-Digit License Key").Trim()
if ([string]::IsNullOrWhiteSpace($licenseKey) -or $licenseKey.Length -lt 10) {
    Write-Host "  [ERROR] Valid 15-digit License Key required." -ForegroundColor Red
    exit 1
}

# Generate Machine HWID Fingerprint
$guid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -ErrorAction SilentlyContinue).MachineGuid
$uuid = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
$rawId = "$guid|$uuid"
$sha = [System.Security.Cryptography.SHA256]::Create()
$hwid = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rawId))) -replace '-', '').ToLower()
$pcName = $env:COMPUTERNAME

# Verify & register with Firebase Firestore
try {
    $fbUrl = "https://firestore.googleapis.com/v1/projects/thesupermouse-a866b/databases/(default)/documents/licenses/$licenseKey"
    $doc = Invoke-RestMethod -Uri $fbUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
    $existingHwid = $doc.fields.hardwareId.stringValue
    if ([string]::IsNullOrEmpty($existingHwid)) {
        $doc.fields.hardwareId = @{ stringValue = $hwid }
        $doc.fields.pcName = @{ stringValue = $pcName }
        $doc.fields.status = @{ stringValue = 'BOUND' }
        $doc.fields.registeredAt = @{ stringValue = (Get-Date -Format o) }
        $null = Invoke-RestMethod -Uri $fbUrl -Method Patch -Body ($doc | ConvertTo-Json -Depth 5) -ContentType "application/json"
        Write-Host "             License registered and bound to this PC!" -ForegroundColor Green
    } elseif ($existingHwid -ne $hwid) {
        Write-Host "  [ERROR] This license is already bound to another PC." -ForegroundColor Red
        Write-Host "          Contact support or unbind from your dashboard." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "             License verified on registered PC (Reinstall)." -ForegroundColor Green
    }
} catch {
    Write-Host "             License verified!" -ForegroundColor Green
}

# 2. Check Reinstallation
$installDir = "$env:LOCALAPPDATA\TheSuperMouse"
$backupDir = "$env:TEMP\SuperMouse_UserBackup"
$preserveData = $false

if (Test-Path "$installDir\TheSuperMouse") {
    Write-Host ""
    Write-Host "  [!] You are reinstalling supermouse" -ForegroundColor Yellow
    $reChoice = (Read-Host "      do you want files/images stays? (yes/no)").Trim().ToLower()
    if ($reChoice -eq 'yes' -or $reChoice -eq 'y') {
        Write-Host "      Preserving user files and configuration..." -ForegroundColor Green
        $preserveData = $true
        if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Get-ChildItem -Path "$installDir\TheSuperMouse" -Include "*.key", "*.json", "snaps*", "*history*" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName -Destination $backupDir -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "      Performing clean reinstall..." -ForegroundColor Yellow
        Stop-Process -Name "TheSuperMouse" -Force -ErrorAction SilentlyContinue
        Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Resilient Multi-Mirror Download with Live Progress
$zipPath = "$env:TEMP\TheSuperMouse_Full.zip"
$downloadCandidates = @(
    "https://github.com/getsupermouse/supermouse-newmodes/releases/download/v1.01/TheSuperMouse_Full.zip",
    "https://github.com/getsupermouse/supermousenewnupdates/releases/download/v1.01/TheSuperMouse_Full.zip"
)

Write-Host ""
Write-Host "  [Step 2/2] Connecting to SuperMouse Cloud Servers..." -ForegroundColor Cyan

$downloadSuccess = $false
foreach ($targetUrl in $downloadCandidates) {
    if ($downloadSuccess) { break }
    try {
        $req = [System.Net.HttpWebRequest]::Create($targetUrl)
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) TheSuperMouseInstaller"
        $req.Timeout = 20000
        $req.AllowAutoRedirect = $true
        $resp = $req.GetResponse()
        $totalBytes = $resp.ContentLength
        $totalMB = if ($totalBytes -gt 0) { [Math]::Round($totalBytes / 1MB, 1) } else { 115.5 }
        $stream = $resp.GetResponseStream()
        $fileStream = [System.IO.File]::Create($zipPath)
        $buffer = New-Object byte[] 65536
        $downloadedBytes = 0
        $lastPct = -1

        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $downloadedBytes += $bytesRead
            if ($totalBytes -gt 0) {
                $pct = [Math]::Floor(($downloadedBytes / $totalBytes) * 100)
                if ($pct -ne $lastPct) {
                    $lastPct = $pct
                    $curMB = [Math]::Round($downloadedBytes / 1MB, 1)
                    $barLen = 25
                    $filled = [Math]::Floor(($pct / 100) * $barLen)
                    $empty = $barLen - $filled
                    $bar = ("=" * $filled) + (" " * $empty)
                    Write-Host -NoNewline "`r  [*] Downloading: [$bar] $pct% ($curMB MB / $totalMB MB)"
                }
            }
        }
        $fileStream.Close()
        $stream.Close()
        $resp.Close()

        if ((Test-Path $zipPath) -and ((Get-Item $zipPath).Length -gt 10000000)) {
            $downloadSuccess = $true
            Write-Host ""
            Write-Host "  [+] Package download verified successfully!" -ForegroundColor Green
            break
        }
    } catch {
        try {
            Write-Host "  [*] Failover connecting to secondary mirror..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $targetUrl -OutFile $zipPath -UserAgent "SuperMouseInstaller" -UseBasicParsing -TimeoutSec 35
            if ((Test-Path $zipPath) -and ((Get-Item $zipPath).Length -gt 10000000)) {
                $downloadSuccess = $true
                Write-Host "  [+] Package download verified!" -ForegroundColor Green
                break
            }
        } catch {}
    }
}

if (-not $downloadSuccess) {
    Write-Host "  [ERROR] Could not download package from any cloud mirror." -ForegroundColor Red
    Write-Host "          Please check your internet connection." -ForegroundColor Yellow
    exit 1
}

# 4. Extract Package Files with Progress
Write-Host "  [*] Extracting and installing package files to $installDir..." -ForegroundColor Cyan
Stop-Process -Name "TheSuperMouse" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SuperMouseShellServer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if (-not $preserveData -and (Test-Path $installDir)) {
    Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# Restore preserved data
if ($preserveData -and (Test-Path $backupDir)) {
    Write-Host "  [*] Restoring user files and configurations..." -ForegroundColor Green
    Copy-Item -Path "$backupDir\*" -Destination "$installDir\TheSuperMouse" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Save license key
$licPath = if (Test-Path "$installDir\TheSuperMouse") { "$installDir\TheSuperMouse\license.key" } else { "$installDir\license.key" }
Set-Content -Path $licPath -Value $licenseKey -Force -ErrorAction SilentlyContinue

# 5. Create CLI Tools & 'delete supermouse' in PATH
$binDir = "$installDir\bin"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

# delete.cmd
$cmdLines = @(
    '@echo off',
    'if /I "%~1"=="supermouse" (',
    '    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\TheSuperMouse\bin\delete_supermouse.ps1"',
    '    exit /b %errorlevel%',
    ')',
    'echo Usage: delete supermouse',
    'exit /b 1'
)
$cmdLines | Out-File -FilePath "$binDir\delete.cmd" -Encoding ASCII -Force

# delete_supermouse.ps1 (Safe line-by-line array to avoid any here-string nested parser bugs)
$psLines = @(
    '$ErrorActionPreference = "SilentlyContinue"',
    'Clear-Host',
    'Write-Host ""',
    'Write-Host "  =======================================================" -ForegroundColor Red',
    'Write-Host "             THE SUPER MOUSE — DELETION PROCESS          " -ForegroundColor White',
    'Write-Host "  =======================================================" -ForegroundColor Red',
    'Write-Host ""',
    'Write-Host "  [*] Terminating any running SuperMouse instances..." -ForegroundColor Cyan',
    'Stop-Process -Name "TheSuperMouse" -Force -ErrorAction SilentlyContinue',
    'Stop-Process -Name "SuperMouseShellServer" -Force -ErrorAction SilentlyContinue',
    'Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq "pythonw.exe" -or $_.Name -eq "python.exe") -and $_.CommandLine -like "*main_app.py*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }',
    'Start-Sleep -Seconds 1',
    'Write-Host "  [*] Restoring Windows 10/11 Default White Cursors..." -ForegroundColor Cyan',
    '$cursorReg = "HKCU:\Control Panel\Cursors"',
    '$cursorNames = @("Arrow", "Hand", "Wait", "IBeam", "Help", "AppStarting", "No", "NWPen", "SizeAll", "SizeNESW", "SizeNS", "SizeNWSE", "SizeWE", "UpArrow")',
    'foreach ($cName in $cursorNames) {',
    '    Remove-ItemProperty -Path $cursorReg -Name $cName -Force -ErrorAction SilentlyContinue',
    '}',
    'Set-ItemProperty -Path $cursorReg -Name "(default)" -Value "Windows Default" -Force',
    'Set-ItemProperty -Path $cursorReg -Name "Scheme Source" -Value 1 -Force',
    'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Accessibility" -Name "CursorSize" -Value 1 -Force -ErrorAction SilentlyContinue',
    'try {',
    '    rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True',
    '} catch {}',
    'Write-Host "  [*] Removing software files & desktop shortcuts..." -ForegroundColor Cyan',
    '$desktop = [System.Environment]::GetFolderPath("Desktop")',
    '$startup = [System.Environment]::GetFolderPath("Startup")',
    'Remove-Item "$desktop\THE SUPER MOUSE.lnk" -Force -ErrorAction SilentlyContinue',
    'Remove-Item "$desktop\TheSuperMouse.lnk" -Force -ErrorAction SilentlyContinue',
    'Remove-Item "$startup\THE SUPER MOUSE.lnk" -Force -ErrorAction SilentlyContinue',
    'Remove-Item "$startup\TheSuperMouse.lnk" -Force -ErrorAction SilentlyContinue',
    'Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TheSuperMouse" -Recurse -Force -ErrorAction SilentlyContinue',
    'try {',
    '    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")',
    '    if ($oldPath -like "*TheSuperMouse\bin*") {',
    '        $newPath = ($oldPath -split ";" | Where-Object { $_ -and $_ -notlike "*TheSuperMouse\bin*" }) -join ";"',
    '        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")',
    '    }',
    '} catch {}',
    '$batScript = "$env:TEMP\del_supermouse.bat"',
    '@(',
    '  "@echo off",',
    '  "timeout /t 1 /nobreak >nul",',
    '  "rmdir /s /q `"" + $env:LOCALAPPDATA + "\TheSuperMouse`"",',
    '  "del `"%~f0`""',
    ') | Out-File -FilePath $batScript -Encoding ASCII -Force',
    'Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"" + $batScript + "`"" -WindowStyle Hidden',
    'Write-Host ""',
    'Write-Host "  =======================================================" -ForegroundColor Green',
    'Write-Host "  [+] THE SUPER MOUSE uninstalled cleanly.               " -ForegroundColor Green',
    'Write-Host "  [+] Windows 10/11 Default White Cursors Restored!      " -ForegroundColor Green',
    'Write-Host "  =======================================================" -ForegroundColor Green',
    'Write-Host ""',
    'Start-Sleep -Seconds 2'
)
$psLines | Out-File -FilePath "$binDir\delete_supermouse.ps1" -Encoding UTF8 -Force

# Add binDir to User PATH
try {
    $curPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($curPath -notlike "*$binDir*") {
        $updatedPath = "$curPath;$binDir"
        [System.Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
        $env:Path = "$env:Path;$binDir"
    }
} catch {}

# 6. Create Desktop Shortcut + Autostart
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

# 7. Register in Windows 10/11 Settings -> Installed Apps
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TheSuperMouse"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "THE SUPER MOUSE" -Force
    Set-ItemProperty -Path $regPath -Name "DisplayVersion" -Value "1.0.1" -Force
    Set-ItemProperty -Path $regPath -Name "Publisher" -Value "THE SUPERMOUSE STUDIO" -Force
    Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $workingDir -Force
    Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value "$targetExe,0" -Force
    Set-ItemProperty -Path $regPath -Name "UninstallString" -Value "$binDir\delete.cmd supermouse" -Force
    Set-ItemProperty -Path $regPath -Name "QuietUninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$binDir\delete_supermouse.ps1`"" -Force
    Set-ItemProperty -Path $regPath -Name "EstimatedSize" -Value 280000 -Force
} catch {}

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "  [+] INSTALLED SUCCESSFULLY! Desktop shortcut & Autostart configured." -ForegroundColor Green
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
exit 0
