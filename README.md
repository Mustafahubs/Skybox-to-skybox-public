# Skybox to Skybox — releases

This repo holds nothing but **built releases** of Skybox to Skybox: the Windows exe, its SHA256 checksum, and this install script. No source code lives here — that's in a private repo. This one exists purely so the built app can be installed and self-updated without needing any credential (this repo being public is what makes that possible).

## Install

**PowerShell:**

```powershell
irm https://raw.githubusercontent.com/Mustafahubs/Skybox-to-skybox-public/main/install.ps1 | iex
```

**Command Prompt (cmd.exe):**

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Mustafahubs/Skybox-to-skybox-public/main/install.ps1 | iex"
```

Either way, this downloads the latest release, verifies its SHA256 checksum, installs it to `Documents\Skybox-to-skybox`, adds Start Menu and Desktop shortcuts, and launches it. Safe to re-run any time to reinstall/force-update — it replaces the previous exe in place; just close the app first if it's currently running.

Once installed, the app checks for newer releases on its own each time it launches and offers to update itself in place — you shouldn't normally need to re-run the installer after the first time.
