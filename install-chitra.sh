#!/usr/bin/env sh
set -eu

# Standalone installer for the Chitra database-client TUI — installs (and updates)
# Chitra WITHOUT requiring the swavan CLI. Re-run it any time to update: it checks
# the published catalog and only downloads when a newer version is available.
#
#   curl -fsSL https://raw.githubusercontent.com/swavan/plugins/main/install-chitra.sh | sh
#
# Override the install dir with CHITRA_INSTALL_DIR (default: ~/.local/bin).

REPO="swavan/plugins"
BINARY="chitra"
CATALOG_URL="https://raw.githubusercontent.com/${REPO}/main/catalog.json"
INSTALL_DIR="${CHITRA_INSTALL_DIR:-$HOME/.local/bin}"

# Compare two dotted numeric versions. Echoes `gt`, `lt`, or `eq` for "$1 vs $2".
# Pure POSIX (no `sort -V`, which stock macOS lacks) so a re-run can refuse to
# downgrade a locally-newer build. Semver pre-release (`-…`) and build metadata
# (`+…`) are stripped, and each field is reduced to its LEADING digits (so a stray
# non-numeric field coerces to 0 rather than a garbage integer).
version_cmp() {
  # Strip build metadata then pre-release, leaving the dotted numeric core.
  a=${1%%+*}
  a=${a%%-*}
  b=${2%%+*}
  b=${b%%-*}
  IFS=.
  # shellcheck disable=SC2086
  set -- $a
  a1=${1:-0} a2=${2:-0} a3=${3:-0}
  # shellcheck disable=SC2086
  set -- $b
  b1=${1:-0} b2=${2:-0} b3=${3:-0}
  unset IFS
  for pair in "$a1 $b1" "$a2 $b2" "$a3 $b3"; do
    x=${pair% *}
    y=${pair#* }
    # Keep only leading digits (drop from the first non-digit), default empty → 0.
    x=${x%%[!0-9]*}
    y=${y%%[!0-9]*}
    x=${x:-0}
    y=${y:-0}
    [ "$x" -gt "$y" ] && { echo gt; return; }
    [ "$x" -lt "$y" ] && { echo lt; return; }
  done
  echo eq
}

# ── Detect OS ────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux"  ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    echo "Windows users: install with install-chitra.ps1 (see the README)." >&2
    exit 1
    ;;
esac

# ── Detect arch ──────────────────────────────────────────────────────────────
# macOS ships a single universal binary; Linux is per-arch (only x86_64 is
# published today — see release-chitra.yml).
if [ "$OS" = "darwin" ]; then
  ARCH="universal"
else
  case "$(uname -m)" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64)
      echo "Chitra does not yet publish a linux-aarch64 build." >&2
      echo "Install via the swavan CLI, or build from source." >&2
      exit 1
      ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
fi

# ── Resolve the latest published version ─────────────────────────────────────
# Chitra is NOT the "latest" GitHub release of the plugins repo (the CLI owns that
# slot), so resolve the version from the public catalog instead of
# /releases/latest. A tiny JSON scrape keeps this dependency-free (no jq).
echo "Resolving the latest Chitra version …"
CATALOG=$(curl --proto '=https' --tlsv1.2 -sSfL "$CATALOG_URL")
# Pull the "version" that follows this plugin's "name":"chitra" object. The catalog
# is an array of {"name","version","description"} — match chitra's entry and take
# the first "version" after it.
VERSION=$(printf '%s' "$CATALOG" \
  | tr ',' '\n' \
  | awk '
      /"name"[[:space:]]*:[[:space:]]*"'"$BINARY"'"/ { found=1 }
      found && /"version"[[:space:]]*:/ {
        gsub(/.*"version"[[:space:]]*:[[:space:]]*"/, "")
        gsub(/".*/, "")
        print
        exit
      }')

if [ -z "${VERSION:-}" ]; then
  echo "Could not determine the latest Chitra version from the catalog." >&2
  echo "  catalog: $CATALOG_URL" >&2
  exit 1
fi

# ── Decide install vs update vs skip ─────────────────────────────────────────
# `chitra --version` prints "chitra <version>"; compare by version (not string
# equality) so a re-run is a cheap no-op when up to date and NEVER silently
# downgrades a locally-newer build. Set CHITRA_FORCE=1 to reinstall/downgrade.
EXISTING="$INSTALL_DIR/$BINARY"
if [ -x "$EXISTING" ]; then
  CURRENT=$("$EXISTING" --version 2>/dev/null | awk '{print $2}' || true)
  if [ -n "$CURRENT" ]; then
    case "$(version_cmp "$CURRENT" "$VERSION")" in
      eq)
        echo "Chitra $VERSION is already installed at $EXISTING — up to date."
        exit 0
        ;;
      gt)
        if [ "${CHITRA_FORCE:-}" = "1" ]; then
          echo "Reinstalling Chitra $VERSION over newer $CURRENT (CHITRA_FORCE=1) …"
        else
          echo "Installed Chitra $CURRENT is newer than the catalog's $VERSION — not downgrading."
          echo "Set CHITRA_FORCE=1 to install $VERSION anyway."
          exit 0
        fi
        ;;
      *)
        echo "Updating Chitra $CURRENT → $VERSION …"
        ;;
    esac
  else
    echo "Installing Chitra $VERSION …"
  fi
else
  echo "Installing Chitra $VERSION …"
fi

ASSET="${BINARY}-${OS}-${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${BINARY}-v${VERSION}/${ASSET}"

# ── Download & verify ────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $ASSET …"
curl --proto '=https' --tlsv1.2 -sSfL "$URL" -o "$TMP/$ASSET"

# Checksum verification is MANDATORY and fails closed — this script pipes a
# downloaded binary onto your PATH, so a missing checksum or missing sha256 tool
# is a hard error, never a silent skip.
CHECKSUM_URL="${URL}.sha256"
echo "Verifying checksum …"
if ! curl --proto '=https' --tlsv1.2 -sSfL "$CHECKSUM_URL" -o "$TMP/$ASSET.sha256" 2>/dev/null; then
  echo "Error: could not download the checksum ($CHECKSUM_URL)." >&2
  echo "Refusing to install an unverified binary." >&2
  exit 1
fi
EXPECTED=$(awk '{print $1}' "$TMP/$ASSET.sha256")
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$TMP/$ASSET" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL=$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')
else
  echo "Error: no sha256 tool (sha256sum or shasum) found — cannot verify the download." >&2
  exit 1
fi
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Checksum mismatch!" >&2
  echo "  expected: $EXPECTED" >&2
  echo "  actual:   $ACTUAL" >&2
  exit 1
fi

# ── Install ──────────────────────────────────────────────────────────────────
# The tarball lays the binary out at `bin/chitra` (plus a manifest.json the
# standalone binary doesn't need — its version is compiled in).
EXTRACT_DIR="$TMP/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TMP/$ASSET" -C "$EXTRACT_DIR"

SRC="$EXTRACT_DIR/bin/$BINARY"
if [ ! -f "$SRC" ]; then
  echo "Error: bin/$BINARY not found in $ASSET" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
# Install to a temp name then rename, so an in-place update is atomic and can't
# leave a half-written binary if the copy is interrupted.
install -m 755 "$SRC" "$INSTALL_DIR/.$BINARY.new"
mv -f "$INSTALL_DIR/.$BINARY.new" "$INSTALL_DIR/$BINARY"

echo "Installed Chitra $VERSION to $INSTALL_DIR/$BINARY"

# ── PATH hint ────────────────────────────────────────────────────────────────
case ":${PATH}:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo ""
    echo "Add $INSTALL_DIR to your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

echo ""
echo "Run 'chitra' to start, or 'chitra --self-update' to update later."
