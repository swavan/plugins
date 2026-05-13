#!/usr/bin/env sh
set -eu

REPO="swavan/plugins"
BINARY="swavan"
INSTALL_DIR="${SWAVAN_INSTALL_DIR:-$HOME/.local/bin}"

# ── Detect OS ────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux"  ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    echo "Windows users: download from https://github.com/$REPO/releases" >&2
    exit 1
    ;;
esac

# ── Detect arch ──────────────────────────────────────────────────────────────
if [ "$OS" = "darwin" ]; then
  ARCH="universal"
else
  case "$(uname -m)" in
    x86_64|amd64) ARCH="x86_64"  ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
fi

ASSET="${BINARY}-${OS}-${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

# ── Download & verify ────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $ASSET ..."
curl --proto '=https' --tlsv1.2 -sSfL "$URL" -o "$TMP/$ASSET"

CHECKSUM_URL="${URL}.sha256"
if curl --proto '=https' --tlsv1.2 -sSfL "$CHECKSUM_URL" -o "$TMP/$ASSET.sha256" 2>/dev/null; then
  echo "Verifying checksum ..."
  EXPECTED=$(awk '{print $1}' "$TMP/$ASSET.sha256")
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "$TMP/$ASSET" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')
  else
    echo "Warning: no sha256 tool found, skipping checksum verification" >&2
    ACTUAL="$EXPECTED"
  fi
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "Checksum mismatch!" >&2
    echo "  expected: $EXPECTED" >&2
    echo "  actual:   $ACTUAL" >&2
    exit 1
  fi
fi

# ── Install ──────────────────────────────────────────────────────────────────
# The release tarball contains the `swavan` CLI plus any sibling binaries
# the CLI invokes at runtime (e.g. `swavan-plugin-shell` for `swavan launch`).
# Extract everything and install every regular file with executable bits set,
# so future binaries added to the tarball install automatically without
# script changes.
EXTRACT_DIR="$TMP/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TMP/$ASSET" -C "$EXTRACT_DIR"

# Sanity check: the CLI itself must always be present.
if [ ! -f "$EXTRACT_DIR/$BINARY" ]; then
  echo "Error: $BINARY not found in $ASSET" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
INSTALLED=""
# Top-level files only: the `[ -f "$SRC" ]` guard skips any directory that
# might end up in the tarball later (e.g. a resources/ tree). If a
# subdirectory layout is ever added, this loop should be revisited.
for SRC in "$EXTRACT_DIR"/*; do
  [ -f "$SRC" ] || continue
  NAME=$(basename "$SRC")
  install -m 755 "$SRC" "$INSTALL_DIR/$NAME"
  INSTALLED="${INSTALLED}  - $INSTALL_DIR/$NAME
"
done

echo "Installed to $INSTALL_DIR:"
printf '%s' "$INSTALLED"

# ── PATH hint ────────────────────────────────────────────────────────────────
case ":${PATH}:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo ""
    echo "Add $INSTALL_DIR to your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac
