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

# Every step below that can fail (a copied/piped script has no reliable
# way to guarantee PowerShell's own uncaught-exception output shows up in
# full when run non-interactively via `-Command "... | iex"` -- it can
# surface as nothing more than the bare exception message, e.g. just
# "Access is denied." with zero context) goes through this instead of a
# raw try/catch, so a failure always prints something a person can act on.
function Fail([string]$Context, $ErrorRecord) {
    $detail = $ErrorRecord.Exception.Message
    Write-Host ""
    Write-Host "$Context" -ForegroundColor Red
    Write-Host "  $detail" -ForegroundColor Red
    if ($detail -match "Access is denied") {
        Write-Host ""
        Write-Host "This usually means Windows Defender's Controlled Folder Access is blocking" -ForegroundColor Yellow
        Write-Host "powershell.exe from writing to Documents/Desktop. Open Windows Security ->" -ForegroundColor Yellow
        Write-Host "Virus & threat protection -> Manage ransomware protection -> Controlled" -ForegroundColor Yellow
        Write-Host "folder access, then either turn it off or allow powershell.exe through it," -ForegroundColor Yellow
        Write-Host "and run this installer again." -ForegroundColor Yellow
    }
    exit 1
}

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
try {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers
} catch {
    Fail "Couldn't reach GitHub to check the latest release." $_
}

$ExeAsset = $Release.assets | Where-Object { $_.name -eq $ExeName }
$ChecksumAsset = $Release.assets | Where-Object { $_.name -eq "$ExeName.sha256" }

if (-not $ExeAsset) {
    Write-Host "No '$ExeName' asset found on the latest release ($($Release.tag_name))." -ForegroundColor Red
    exit 1
}
if (-not $ChecksumAsset) {
    Write-Host "No checksum file found on the latest release ($($Release.tag_name)) -- refusing to install an unverifiable build." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($Release.tag_name). Downloading..." -ForegroundColor Cyan
try {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
} catch {
    Fail "Couldn't create the install folder '$InstallDir'." $_
}

# Download to the system temp dir, not straight into $InstallDir -- so a
# failed checksum never leaves a half-verified file sitting next to (or
# overwriting) a working previous install.
$TempExe = Join-Path $env:TEMP "$ExeName.download"
$TempChecksum = Join-Path $env:TEMP "$ExeName.sha256.download"
try {
    Invoke-WebRequest -Uri $ExeAsset.browser_download_url -OutFile $TempExe -Headers $Headers
    Invoke-WebRequest -Uri $ChecksumAsset.browser_download_url -OutFile $TempChecksum -Headers $Headers
} catch {
    Fail "Couldn't download the release files." $_
}

Write-Host "Verifying checksum..." -ForegroundColor Cyan
$Expected = (Get-Content $TempChecksum -Raw).Trim().Split()[0].ToLower()
$Actual = (Get-FileHash -Path $TempExe -Algorithm SHA256).Hash.ToLower()
Remove-Item $TempChecksum -Force -ErrorAction SilentlyContinue

if ($Actual -ne $Expected) {
    Remove-Item $TempExe -Force -ErrorAction SilentlyContinue
    Write-Host "Checksum mismatch -- the downloaded file doesn't match the published release. Aborting install." -ForegroundColor Red
    exit 1
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
        Fail "Couldn't remove the existing installation at '$ExePath' -- if Skybox to Skybox is currently running, close it and run this installer again." $_
    }
}

try {
    Move-Item -Path $TempExe -Destination $ExePath -Force
} catch {
    Remove-Item $TempExe -Force -ErrorAction SilentlyContinue
    Fail "Couldn't install to '$ExePath'." $_
}

Write-Host "Installed $($Release.tag_name) to $ExePath" -ForegroundColor Green

# Shortcuts are a nice-to-have, not the actual install -- a Controlled
# Folder Access block on just the Desktop (or Start Menu) shouldn't sink
# an otherwise-successful install, so this warns instead of exiting.
function New-AppShortcut([string]$Path) {
    try {
        $Shell = New-Object -ComObject WScript.Shell
        $Shortcut = $Shell.CreateShortcut($Path)
        $Shortcut.TargetPath = $ExePath
        $Shortcut.WorkingDirectory = $InstallDir
        $Shortcut.IconLocation = $ExePath
        $Shortcut.Save()
        return $true
    } catch {
        Write-Host "Couldn't create shortcut '$Path': $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

$StartMenuPrograms = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
$startMenuOk = New-AppShortcut (Join-Path $StartMenuPrograms "Skybox to Skybox.lnk")
$desktopOk = New-AppShortcut (Join-Path ([Environment]::GetFolderPath("Desktop")) "Skybox to Skybox.lnk")
if ($startMenuOk -or $desktopOk) {
    Write-Host "Shortcuts created." -ForegroundColor Green
}

Write-Host "Launching Skybox to Skybox..." -ForegroundColor Cyan
try {
    Start-Process -FilePath $ExePath
} catch {
    Write-Host "Installed successfully, but couldn't launch it automatically: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Start it yourself from $ExePath" -ForegroundColor Yellow
}
