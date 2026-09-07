<#
Skybox to Skybox -- installer

Downloads the latest published build of Skybox to Skybox, verifies it
against the published SHA256 checksum, installs it to
%LOCALAPPDATA%\SkyboxToSkybox (no admin rights needed), adds Start Menu
and Desktop shortcuts, and launches it.

Safe to re-run any time -- it always fetches whatever the latest release
is and reinstalls over the previous copy (close the app first if it's
currently running, since Windows won't let a running exe's file content
be overwritten).

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
$InstallDir = Join-Path $env:LOCALAPPDATA "SkyboxToSkybox"
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

$TempExe = Join-Path $InstallDir "$ExeName.download"
$TempChecksum = Join-Path $InstallDir "$ExeName.sha256.download"
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
