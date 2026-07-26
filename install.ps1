#Requires -Version 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo   = "swavan/plugins"
$Binary = "swavan"
$Asset  = "${Binary}-windows-x86_64.tar.gz"
$Url    = "https://github.com/$Repo/releases/latest/download/$Asset"

$InstallDir = if ($env:SWAVAN_INSTALL_DIR) {
    $env:SWAVAN_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "Programs\Swavan\bin"
}

# ── Download ──────────────────────────────────────────────────────────────────
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    $AssetPath = Join-Path $Tmp $Asset
    Write-Host "Downloading $Asset ..."
    Invoke-WebRequest -Uri $Url -OutFile $AssetPath -UseBasicParsing

    # ── Verify checksum ───────────────────────────────────────────────────────
    $ChecksumUrl  = "${Url}.sha256"
    $ChecksumPath = "${AssetPath}.sha256"
    try {
        Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath -UseBasicParsing
        $Expected = (Get-Content $ChecksumPath -Raw).Trim().Split()[0]
        $Actual   = (Get-FileHash $AssetPath -Algorithm SHA256).Hash.ToLower()
        if ($Actual -ne $Expected) {
            Write-Error "Checksum mismatch!`n  expected: $Expected`n  actual:   $Actual"
            exit 1
        }
        Write-Host "Checksum verified."
    } catch {
        Write-Warning "Could not fetch checksum — skipping verification."
    }

    # ── Extract ───────────────────────────────────────────────────────────────
    $ExtractDir = Join-Path $Tmp "extract"
    New-Item -ItemType Directory -Path $ExtractDir | Out-Null
    tar -xzf $AssetPath -C $ExtractDir

    # ── Install ───────────────────────────────────────────────────────────────
    # The release tarball contains the `swavan` CLI plus any sibling binaries
    # the CLI invokes at runtime (e.g. `swavan-plugin-shell.exe` for
    # `swavan launch`). Copy every top-level file from the archive so future
    # binaries install automatically without script changes.
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Sanity check: the CLI itself must always be present.
    $CliSrc = Join-Path $ExtractDir "${Binary}.exe"
    if (-not (Test-Path $CliSrc)) {
        Write-Error "${Binary}.exe not found in $Asset"
        exit 1
    }

    $Installed = @()
    Get-ChildItem -Path $ExtractDir -File | ForEach-Object {
        $Dest = Join-Path $InstallDir $_.Name
        Copy-Item -Path $_.FullName -Destination $Dest -Force
        $Installed += $Dest
    }

    Write-Host "Installed to ${InstallDir}:"
    foreach ($Path in $Installed) {
        Write-Host "  - $Path"
    }

    # ── PATH ──────────────────────────────────────────────────────────────────
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$InstallDir;$UserPath", "User")
        Write-Host ""
        Write-Host "Added $InstallDir to your user PATH."
        Write-Host "Restart your terminal (or run '. `$PROFILE') for it to take effect."
    }
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
