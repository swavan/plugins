#Requires -Version 5.1
# Standalone uninstaller for Chitra (Windows) — removes a Chitra installed WITHOUT
# the swavan CLI. Deletes the binary and removes the install dir from your user
# PATH, and KEEPS your data by default; pass -Purge (or $env:CHITRA_PURGE=1) to
# also remove %USERPROFILE%\.config\chitra (saved connections, encrypted vault,
# config).
#
#   irm https://raw.githubusercontent.com/swavan/plugins/main/uninstall-chitra.ps1 | iex
#   # to also delete data, download then run with -Purge, or set $env:CHITRA_PURGE=1 first.
#
# Override the install dir with $env:CHITRA_INSTALL_DIR.

param([switch]$Purge)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$Binary = "chitra"
$InstallDir = if ($env:CHITRA_INSTALL_DIR) {
    $env:CHITRA_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "Programs\Chitra\bin"
}
$DoPurge = $Purge -or ($env:CHITRA_PURGE -eq "1")

# Chitra's data dir mirrors its Rust config_dir(): the HOME ENVIRONMENT variable if
# set, else %USERPROFILE% on Windows. (NOT PowerShell's automatic $HOME, which is
# always %USERPROFILE% and would diverge when the process HOME env var is set.)
# Resolve the same way, and only when the result is an absolute path — else refuse
# to purge rather than risk deleting the wrong tree.
$HomeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $null }
$DataDir = $null
if ($HomeDir -and [System.IO.Path]::IsPathRooted($HomeDir)) {
    $DataDir = Join-Path $HomeDir ".config\chitra"
}

# ── Remove the binary ────────────────────────────────────────────────────────
$Target = Join-Path $InstallDir "$Binary.exe"
if (Test-Path $Target) {
    Remove-Item -Force $Target
    Write-Host "Removed $Target"
} else {
    Write-Host "No Chitra binary at $Target (nothing to remove there)."
}

# ── Remove the install dir from the user PATH ────────────────────────────────
# Remove ONLY exact `;`-segments equal to InstallDir (normalized for a trailing
# backslash + case, since Windows paths are case-insensitive). Other segments —
# including empty ones — are preserved untouched, and PATH is only rewritten (and
# reported) when InstallDir was actually present.
$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($UserPath) {
    $Norm = $InstallDir.TrimEnd('\')
    $Parts = $UserPath.Split(';')
    $Kept = $Parts | Where-Object { $_.TrimEnd('\') -ine $Norm }
    if ($Kept.Count -ne $Parts.Count) {
        [Environment]::SetEnvironmentVariable("PATH", ($Kept -join ';'), "User")
        Write-Host "Removed $InstallDir from your user PATH (restart your terminal)."
    }
}

# ── Optionally remove data ───────────────────────────────────────────────────
if ($DoPurge) {
    if (-not $DataDir) {
        Write-Warning "Skipped data purge: HOME is not a valid absolute path; remove your data manually."
    } elseif (Test-Path $DataDir) {
        Remove-Item -Recurse -Force $DataDir
        Write-Host "Removed data directory $DataDir (saved connections + vault)."
    } else {
        Write-Host "No data directory at $DataDir."
    }
} elseif ($DataDir -and (Test-Path $DataDir)) {
    Write-Host ""
    Write-Host "Kept your data at $DataDir (saved connections + encrypted vault)."
    Write-Host "Re-run with -Purge to remove it too."
}
