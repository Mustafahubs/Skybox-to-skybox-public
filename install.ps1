<#
Skybox to Skybox -- installer

Downloads the latest published build of Skybox to Skybox, verifies it
against the published SHA256 checksum, installs it to
Documents\Skybox-to-skybox (no admin rights needed), adds Start Menu
and Desktop shortcuts, and launches it.

Safe to re-run any time to reinstall or force-update: it always fetches
whatever the latest release is, replacing the previous exe in place
(close the app first if it's currently running -- Windows won't let a
running exe's file content be overwritten, only its own self-update
flow, see skybox/updater.py, works around that with a wait-then-swap
script since it controls when the app exits).

Run with:
  irm https://raw.githubusercontent.com/Mustafahubs/Skybox-to-skybox-public/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# Older Windows/PowerShell defaults to a TLS version GitHub's API and CDN
# reject outright -- force 1.2 so this doesn't fail with a cryptic
# connection error on those machines.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = "Mustafahubs/Skybox-to-skybox-public"
$ExeName = "skybox-to-skybox.exe"
# The active user's own Documents folder -- a visible, easy-to-find
# location (rather than e.g. AppData) since this is meant to be found and
# double-clicked like any normal installed app, not hidden away.
$InstallDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Skybox-to-skybox"
$ExePath = Join-Path $InstallDir $ExeName
# GitHub's API rejects requests with no User-Agent at all.
$Headers = @{ "User-Agent" = "skybox-to-skybox-installer" }

Write-Host "Checking latest release..." -ForegroundColor Cyan
$Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers

$ExeAsset = $Release.assets | Where-Object { $_.name -eq $ExeName }
$ChecksumAsset = $Release.assets | Where-Object { $_.name -eq "$ExeName.sha256" }

if (-not $ExeAsset) {
    throw "No '$ExeName' asset found on the latest release ($($Release.tag_name))."
}
if (-not $ChecksumAsset) {
    throw "No checksum file found on the latest release ($($Release.tag_name)) -- refusing to install an unverifiable build."
}

Write-Host "Found $($Release.tag_name). Downloading..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Download to the system temp dir, not straight into $InstallDir -- so a
# failed checksum never leaves a half-verified file sitting next to (or
# overwriting) a working previous install.
$TempExe = Join-Path $env:TEMP "$ExeName.download"
$TempChecksum = Join-Path $env:TEMP "$ExeName.sha256.download"
Invoke-WebRequest -Uri $ExeAsset.browser_download_url -OutFile $TempExe -Headers $Headers
Invoke-WebRequest -Uri $ChecksumAsset.browser_download_url -OutFile $TempChecksum -Headers $Headers

Write-Host "Verifying checksum..." -ForegroundColor Cyan
$Expected = (Get-Content $TempChecksum -Raw).Trim().Split()[0].ToLower()
$Actual = (Get-FileHash -Path $TempExe -Algorithm SHA256).Hash.ToLower()
Remove-Item $TempChecksum -Force

if ($Actual -ne $Expected) {
    Remove-Item $TempExe -Force -ErrorAction SilentlyContinue
    throw "Checksum mismatch -- the downloaded file doesn't match the published release. Aborting install."
}

# Re-running this script (to reinstall or force-update) means an old copy
# may already be sitting at $ExePath -- remove it explicitly rather than
# relying only on Move-Item's -Force, so a stale exe never lingers if
# something below fails partway.
if (Test-Path $ExePath) {
    Write-Host "Existing installation found -- replacing it." -ForegroundColor Yellow
    try {
        Remove-Item -Path $ExePath -Force -ErrorAction Stop
    } catch {
        Remove-Item $TempExe -Force -ErrorAction SilentlyContinue
        throw "Couldn't remove the existing installation at '$ExePath' -- if Skybox to Skybox is currently running, close it and run this installer again. ($($_.Exception.Message))"
    }
}

try {
    Move-Item -Path $TempExe -Destination $ExePath -Force
} catch {
    Remove-Item $TempExe -Force -ErrorAction SilentlyContinue
    throw "Couldn't install to '$ExePath' -- if Skybox to Skybox is currently running, close it and run this installer again. ($($_.Exception.Message))"
}

Write-Host "Installed $($Release.tag_name) to $ExePath" -ForegroundColor Green

function New-AppShortcut([string]$Path) {
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($Path)
    $Shortcut.TargetPath = $ExePath
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.IconLocation = $ExePath
    $Shortcut.Save()
}

$StartMenuPrograms = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
New-AppShortcut (Join-Path $StartMenuPrograms "Skybox to Skybox.lnk")
New-AppShortcut (Join-Path ([Environment]::GetFolderPath("Desktop")) "Skybox to Skybox.lnk")
Write-Host "Shortcuts created (Start Menu and Desktop)." -ForegroundColor Green

Write-Host "Launching Skybox to Skybox..." -ForegroundColor Cyan
Start-Process -FilePath $ExePath
