#Requires -Version 5.1
# Standalone installer for Termo — a fast native terminal & file workspace.
# Installs (and updates) Termo WITHOUT requiring the swavan CLI. Re-run it any
# time to update: it checks the published catalog and only downloads when a
# newer version is available.
#
#   irm https://raw.githubusercontent.com/swavan/plugins/main/install-termo.ps1 | iex
#
# Override the install dir with $env:TERMO_INSTALL_DIR
# (default: %LOCALAPPDATA%\Programs\Termo\bin).

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Make cmdlet errors terminating so a failed download / extract / binary swap can't
# be silently ignored and then falsely reported as a successful install.
$ErrorActionPreference = "Stop"

$Repo       = "swavan/plugins"
$Binary     = "termo"
$CatalogUrl = "https://raw.githubusercontent.com/$Repo/main/catalog.json"
$Os         = "windows"
$Arch       = "x86_64"

$InstallDir = if ($env:TERMO_INSTALL_DIR) {
    $env:TERMO_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "Programs\Termo\bin"
}

# Compare dotted numeric versions (pre-release suffix after '-' ignored). Returns
# 'gt' / 'lt' / 'eq' for "$a vs $b", or 'ne' when a side isn't a parseable version.
function Compare-TermoVersion($a, $b) {
    try {
        $va = [version]($a -replace '-.*$', '')
        $vb = [version]($b -replace '-.*$', '')
        if ($va -gt $vb) { 'gt' } elseif ($va -lt $vb) { 'lt' } else { 'eq' }
    } catch {
        if ($a -eq $b) { 'eq' } else { 'ne' }
    }
}

# ── Resolve the latest published version ─────────────────────────────────────
# Termo is NOT the "latest" GitHub release of the plugins repo, so resolve the
# version from the public catalog instead of /releases/latest. raw.githubusercontent
# serves catalog.json as text/plain, which Invoke-RestMethod does NOT auto-deserialize
# on Windows PowerShell 5.1 — fetch the raw text and ConvertFrom-Json explicitly.
Write-Host "Resolving the latest Termo version ..."
try {
    $CatalogText = (Invoke-WebRequest -Uri $CatalogUrl -UseBasicParsing).Content
    $Catalog = $CatalogText | ConvertFrom-Json
} catch {
    Write-Error "Could not fetch or parse the plugin catalog: $CatalogUrl"
    exit 1
}
$Version = ($Catalog | Where-Object { $_.name -eq $Binary } | Select-Object -First 1).version
if (-not $Version) {
    Write-Error "Could not determine the latest Termo version from the catalog ($CatalogUrl)."
    exit 1
}

# ── Decide install vs update vs skip ─────────────────────────────────────────
# Compare by version (not string equality) so a re-run is a no-op when up to date
# and NEVER silently downgrades a locally-newer build. Set $env:TERMO_FORCE=1 to
# reinstall/downgrade.
$Existing = Join-Path $InstallDir "$Binary.exe"
if (Test-Path $Existing) {
    $Current = $null
    try { $Current = (& $Existing --version 2>$null).Split()[1] } catch { }
    if ($Current) {
        switch (Compare-TermoVersion $Current $Version) {
            'eq' {
                Write-Host "Termo $Version is already installed at $Existing - up to date."
                exit 0
            }
            'lt' {
                Write-Host "Updating Termo $Current -> $Version ..."
            }
            default {
                # 'gt' (installed is newer) OR 'ne' (unparseable): don't overwrite
                # with the catalog version without an explicit override.
                if ($env:TERMO_FORCE -eq '1') {
                    Write-Host "Reinstalling Termo $Version over $Current (TERMO_FORCE=1) ..."
                } else {
                    Write-Host "Installed Termo $Current is newer than or not comparable to the catalog's $Version - not overwriting."
                    Write-Host "Set `$env:TERMO_FORCE=1 to install $Version anyway."
                    exit 0
                }
            }
        }
    } else {
        Write-Host "Installing Termo $Version ..."
    }
} else {
    Write-Host "Installing Termo $Version ..."
}

$Asset = "$Binary-$Os-$Arch.tar.gz"
$Url   = "https://github.com/$Repo/releases/download/$Binary-v$Version/$Asset"

# ── Download ─────────────────────────────────────────────────────────────────
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    $AssetPath = Join-Path $Tmp $Asset
    Write-Host "Downloading $Asset ..."
    Invoke-WebRequest -Uri $Url -OutFile $AssetPath -UseBasicParsing

    # ── Verify checksum (MANDATORY, fails closed) ─────────────────────────────
    $ChecksumUrl  = "$Url.sha256"
    $ChecksumPath = "$AssetPath.sha256"
    try {
        Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath -UseBasicParsing
    } catch {
        Write-Error "Could not download the checksum ($ChecksumUrl). Refusing to install an unverified binary."
        exit 1
    }
    $ChecksumRaw = Get-Content $ChecksumPath -Raw
    if (-not $ChecksumRaw) {
        Write-Error "The downloaded checksum ($ChecksumUrl) is empty. Refusing to install an unverified binary."
        exit 1
    }
    $Expected = $ChecksumRaw.Trim().Split()[0]
    $Actual   = (Get-FileHash $AssetPath -Algorithm SHA256).Hash.ToLower()
    if ($Actual -ne $Expected) {
        Write-Error "Checksum mismatch!`n  expected: $Expected`n  actual:   $Actual"
        exit 1
    }
    Write-Host "Checksum verified."

    # ── Extract ───────────────────────────────────────────────────────────────
    # The tarball lays the binary out at bin\termo.exe (plus manifest.json + icons).
    # `tar` ships with Windows 10+ (bsdtar); older hosts would need it installed.
    $ExtractDir = Join-Path $Tmp "extract"
    New-Item -ItemType Directory -Path $ExtractDir | Out-Null
    tar -xzf $AssetPath -C $ExtractDir

    $Src = Join-Path $ExtractDir "bin\$Binary.exe"
    if (-not (Test-Path $Src)) {
        Write-Error "bin\$Binary.exe not found in $Asset"
        exit 1
    }

    # ── Install ───────────────────────────────────────────────────────────────
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    # A running termo.exe can't be OVERWRITTEN, but Windows allows RENAMING it.
    # Move the old one aside so the new binary can take its place; the renamed file
    # is deleted best-effort (a still-running instance keeps a lock, so a leftover
    # `.old` is simply cleaned up on the next run).
    if (Test-Path $Existing) {
        $Old = "$Existing.old"
        Remove-Item -Force $Old -ErrorAction SilentlyContinue
        Move-Item -Force $Existing $Old
        Remove-Item -Force $Old -ErrorAction SilentlyContinue
    }
    Copy-Item -Path $Src -Destination $Existing -Force
    Write-Host "Installed Termo $Version to $Existing"

    # ── Start Menu shortcut (Termo is a GUI app) ──────────────────────────────
    $StartMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    $Shortcut  = Join-Path $StartMenu "Termo.lnk"
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $lnk = $WshShell.CreateShortcut($Shortcut)
        $lnk.TargetPath = $Existing
        $lnk.WorkingDirectory = $InstallDir
        $lnk.Description = "A fast native terminal & file workspace"
        $lnk.Save()
        Write-Host "Created Start Menu shortcut: $Shortcut"
    } catch {
        Write-Host "Note: could not create a Start Menu shortcut (run termo.exe directly)."
    }

    # ── PATH ──────────────────────────────────────────────────────────────────
    # Match on exact `;`-delimited segments (not a substring, which would false-skip
    # when another entry merely contains InstallDir) and handle an unset User PATH.
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not $UserPath) { $UserPath = "" }
    $Segments = $UserPath.Split(';') | Where-Object { $_ -ne "" }
    if ($Segments -notcontains $InstallDir) {
        $NewPath = if ($UserPath) { "$InstallDir;$UserPath" } else { $InstallDir }
        [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
        Write-Host ""
        Write-Host "Added $InstallDir to your user PATH."
        Write-Host "Restart your terminal for it to take effect."
    }

    Write-Host ""
    Write-Host "Termo $Version installed. Launch it from the Start Menu or run 'termo'."
    Write-Host "Update later: re-run this installer."
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
