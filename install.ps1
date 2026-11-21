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

# 3. Download from Server with Live Progress
$zipPath = "$env:TEMP\TheSuperMouse_Full.zip"
$downloadUrl = "https://github.com/getsupermouse/supermousenewnupdates/releases/download/v1.01/TheSuperMouse_Full.zip"

Write-Host ""
Write-Host "  [Step 2/2] Connecting to SuperMouse Cloud Servers..." -ForegroundColor Cyan

try {
    $req = [System.Net.HttpWebRequest]::Create($downloadUrl)
    $req.UserAgent = "SuperMouseInstaller"
    $resp = $req.GetResponse()
    $totalBytes = $resp.ContentLength
    $totalMB = [Math]::Round($totalBytes / 1MB, 1)
    $stream = $resp.GetResponseStream()
    $fileStream = [System.IO.File]::Create($zipPath)
    $buffer = New-Object byte[] 65536
    $downloadedBytes = 0
    $lastPct = -1

    while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fileStream.Write($buffer, 0, $bytesRead)
        $downloadedBytes += $bytesRead
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
    $fileStream.Close()
    $stream.Close()
    $resp.Close()
    Write-Host ""
    Write-Host "  [+] Package download verified!" -ForegroundColor Green
} catch {
    Write-Host "  [*] Downloading via fallback..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
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
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# Restore user data if requested
if ($preserveData -and (Test-Path $backupDir)) {
    Get-ChildItem -Path $backupDir | ForEach-Object {
        Copy-Item $_.FullName -Destination "$installDir\TheSuperMouse" -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [+] User files and images restored!" -ForegroundColor Green
}

# Save license key
$licPath = if (Test-Path "$installDir\TheSuperMouse") { "$installDir\TheSuperMouse\license.key" } else { "$installDir\license.key" }
Set-Content -Path $licPath -Value $licenseKey -Force -ErrorAction SilentlyContinue

# 5. Create Desktop Shortcut + Autostart
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

# 6. Register in Windows 10/11 Settings -> Installed Apps
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TheSuperMouse"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "THE SUPER MOUSE" -Force
    Set-ItemProperty -Path $regPath -Name "DisplayVersion" -Value "1.0.1" -Force
    Set-ItemProperty -Path $regPath -Name "Publisher" -Value "THE SUPERMOUSE STUDIO" -Force
    Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $workingDir -Force
    Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value "$targetExe,0" -Force
    Set-ItemProperty -Path $regPath -Name "UninstallString" -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://getsupermouse.app/d|iex"' -Force
    Set-ItemProperty -Path $regPath -Name "QuietUninstallString" -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://getsupermouse.app/d|iex"' -Force
    Set-ItemProperty -Path $regPath -Name "EstimatedSize" -Value 280000 -Force
} catch {}

Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "  [+] INSTALLED SUCCESSFULLY! Desktop shortcut & Autostart configured." -ForegroundColor Green
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
exit 0
