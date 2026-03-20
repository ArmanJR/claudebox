#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/ArmanJR/claudebox/main"
INSTALL_DIR="${INSTALL_DIR:-}"

log() { printf '[claudebox] %s\n' "$*" >&2; }
die() { printf '[claudebox] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Determine install location
# ---------------------------------------------------------------------------
if [ -z "$INSTALL_DIR" ]; then
    if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
        INSTALL_DIR="/usr/local/bin"
    else
        INSTALL_DIR="${HOME}/.local/bin"
        mkdir -p "$INSTALL_DIR"
    fi
fi

TARGET="${INSTALL_DIR}/claudebox"

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
log "Downloading claudebox..."
curl -fsSL "${REPO}/claudebox" -o "$TARGET" || die "Download failed."
chmod +x "$TARGET"
log "Installed to ${TARGET}"

# ---------------------------------------------------------------------------
# PATH check
# ---------------------------------------------------------------------------
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    log ""
    log "Add to your PATH (then restart your shell):"
    case "$(basename "${SHELL:-bash}")" in
        zsh)  log "  echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.zshrc" ;;
        *)    log "  echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.bashrc" ;;
    esac
fi

log ""
log "Done. Run 'claudebox help' to get started."
