#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.claude"
CREDENTIALS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
PLATFORM="$(uname -s)"

log() { echo "[setup-auth] $*" >&2; }
die() { echo "[setup-auth] ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Read raw credential JSON from platform store
# ---------------------------------------------------------------------------
read_raw_credential() {
    case "$PLATFORM" in
        Darwin)
            security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null && return 0
            return 1
            ;;
        Linux)
            [ -f "$CREDENTIALS_FILE" ] && cat "$CREDENTIALS_FILE" && return 0
            return 1
            ;;
        *) die "Unsupported platform: $PLATFORM" ;;
    esac
}

# ---------------------------------------------------------------------------
# Check if stored token is expired (returns 0=expired/unknown, 1=valid)
# ---------------------------------------------------------------------------
is_token_expired() {
    local raw_json="$1"
    local expires_at
    expires_at=$(echo "$raw_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth'].get('expiresAt',0))" 2>/dev/null) \
        || return 0
    if [ "$expires_at" -gt 0 ] 2>/dev/null; then
        local now_ms
        now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
        [ "$now_ms" -ge "$expires_at" ] && return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Run platform-specific login
# ---------------------------------------------------------------------------
run_login() {
    command -v claude >/dev/null 2>&1 \
        || die "Claude CLI not found. Install it first: npm install -g @anthropic-ai/claude-code"

    case "$PLATFORM" in
        Darwin)
            log "Running 'claude setup-token'..."
            claude setup-token || die "'claude setup-token' failed."
            security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1 \
                || die "Credentials still not found after setup-token."
            ;;
        Linux)
            log "Running 'claude login'..."
            claude login || die "'claude login' failed."
            [ -f "$CREDENTIALS_FILE" ] \
                || die "Credentials still not found after login."
            ;;
    esac
    log "Authentication successful."
}

# ---------------------------------------------------------------------------
# Ensure valid (present + not expired) credentials exist
# ---------------------------------------------------------------------------
ensure_auth() {
    local raw_json
    if raw_json=$(read_raw_credential); then
        if ! is_token_expired "$raw_json"; then
            return 0
        fi
        log "OAuth token has expired."
    else
        log "No credentials found."
    fi
    run_login
}

# ---------------------------------------------------------------------------
# Extract access token from credential store
# ---------------------------------------------------------------------------
extract_token() {
    local raw_json
    raw_json=$(read_raw_credential) || die "Failed to read credentials."

    local access_token expires_at
    access_token=$(echo "$raw_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null) \
        || die "Failed to parse accessToken from credential JSON."

    [ -n "$access_token" ] || die "Extracted access token is empty."

    expires_at=$(echo "$raw_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth'].get('expiresAt',0))" 2>/dev/null) \
        || expires_at=0
    if [ "$expires_at" -gt 0 ] 2>/dev/null; then
        local now_ms remaining_hrs
        now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
        remaining_hrs=$(( (expires_at - now_ms) / 3600000 ))
        log "Token valid for ~${remaining_hrs}h"
    fi

    echo "$access_token"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ensure_auth
TOKEN=$(extract_token)

echo "CLAUDE_CODE_OAUTH_TOKEN=$TOKEN" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
log "Wrote $ENV_FILE"
