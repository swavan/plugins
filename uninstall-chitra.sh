#!/usr/bin/env sh
set -eu

# Standalone uninstaller for Chitra (macOS/Linux) — removes a Chitra installed
# WITHOUT the swavan CLI. Deletes only the binary and KEEPS your data by default;
# pass --purge (or CHITRA_PURGE=1) to also remove ~/.config/chitra (saved
# connections, the encrypted vault, config).
#
#   curl -fsSL https://raw.githubusercontent.com/swavan/plugins/main/uninstall-chitra.sh | sh
#   ... | sh -s -- --purge      # also delete your data
#
# Override the install dir with CHITRA_INSTALL_DIR (default: ~/.local/bin).

BINARY="chitra"

PURGE="${CHITRA_PURGE:-0}"
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    *)
      echo "Unknown option: $arg (use --purge to also remove your data)" >&2
      exit 1
      ;;
  esac
done

# HOME must be a set, non-empty, absolute path before we build any path under it —
# otherwise `$HOME/...` degrades to a relative or root-level path and a purge could
# delete the wrong tree. `set -u` already aborts on an UNSET HOME; also reject an
# empty or relative one when we actually need it.
home_is_safe() {
  case "${HOME:-}" in
    /*) [ -n "$HOME" ] ;;
    *) return 1 ;;
  esac
}

# Fall back to ~/.local/bin only when HOME is safe; otherwise CHITRA_INSTALL_DIR
# must be provided explicitly.
if [ -n "${CHITRA_INSTALL_DIR:-}" ]; then
  INSTALL_DIR="$CHITRA_INSTALL_DIR"
elif home_is_safe; then
  INSTALL_DIR="$HOME/.local/bin"
else
  echo "HOME is not a valid absolute path — set CHITRA_INSTALL_DIR to the install dir." >&2
  exit 1
fi

# ── Remove the binary ────────────────────────────────────────────────────────
TARGET="$INSTALL_DIR/$BINARY"
if [ -e "$TARGET" ]; then
  rm -f "$TARGET"
  echo "Removed $TARGET"
else
  echo "No Chitra binary at $TARGET (nothing to remove there)."
fi

# ── Optionally remove data ───────────────────────────────────────────────────
# Only resolve/purge the data dir when HOME is safe (see home_is_safe): an unset /
# empty / relative HOME would make DATA_DIR a wrong path to recursively delete.
if home_is_safe; then
  DATA_DIR="$HOME/.config/chitra"
  if [ "$PURGE" = "1" ]; then
    if [ -d "$DATA_DIR" ]; then
      rm -rf "$DATA_DIR"
      echo "Removed data directory $DATA_DIR (saved connections + vault)."
    else
      echo "No data directory at $DATA_DIR."
    fi
  elif [ -d "$DATA_DIR" ]; then
    echo ""
    echo "Kept your data at $DATA_DIR (saved connections + encrypted vault)."
    echo "Re-run with --purge to remove it too."
  fi
elif [ "$PURGE" = "1" ]; then
  echo "Skipped data purge: HOME is not a valid absolute path; remove your data manually." >&2
fi

# ── PATH note ────────────────────────────────────────────────────────────────
# The installer only PRINTS a PATH hint on macOS/Linux (it never edits your shell
# rc), so there's nothing to unwind here — remove the export line yourself if you
# added one.
