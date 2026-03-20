#!/bin/bash

# ---------------------------------------------------------------------------
# Auth: resolve CLAUDE_CODE_OAUTH_TOKEN
#   1. Already set via env_file / environment  → use it (macOS path)
#   2. Mounted credentials file exists          → extract from it (Linux path)
#   3. Neither                                  → fail with instructions
# ---------------------------------------------------------------------------
CREDENTIALS_MOUNT="/run/claude-credentials"

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    if [ -f "$CREDENTIALS_MOUNT" ]; then
        echo "Reading OAuth token from mounted credentials file..."
        CLAUDE_CODE_OAUTH_TOKEN=$(node -e "
            const creds = JSON.parse(require('fs').readFileSync('$CREDENTIALS_MOUNT', 'utf8'));
            const token = creds.claudeAiOauth && creds.claudeAiOauth.accessToken;
            if (!token) { console.error('No accessToken found in credentials file'); process.exit(1); }
            process.stdout.write(token);
        ") || { echo "ERROR: Failed to parse credentials file."; exit 1; }
        export CLAUDE_CODE_OAUTH_TOKEN
    else
        echo "ERROR: No authentication found."
        echo ""
        echo "  Linux users:  credentials are mounted automatically if you have"
        echo "                run 'claude login' on this machine."
        echo ""
        echo "  macOS users:  run ./setup-auth.sh once (Keychain can't be mounted)."
        exit 1
    fi
fi

ALLOWED_DOMAINS_FILE="/etc/allowed-domains.txt"

# Setup firewall rules with sudo (container must have NET_ADMIN capability)
echo "Setting up firewall rules..."

# Allow loopback
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS to Docker gateway (internal DNS) and external resolver for domain resolution
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
if [ -n "$GATEWAY_IP" ]; then
    echo "Allowing DNS to Docker gateway: $GATEWAY_IP"
    sudo iptables -A OUTPUT -d $GATEWAY_IP -p udp --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -d $GATEWAY_IP -p tcp --dport 53 -j ACCEPT
fi
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Resolve and allow domains from the allowlist
if [ -f "$ALLOWED_DOMAINS_FILE" ]; then
    while IFS= read -r domain || [ -n "$domain" ]; do
        domain=$(echo "$domain" | xargs)
        [[ -z "$domain" || "$domain" == \#* ]] && continue
        echo "Resolving $domain..."
        IPS=$(dig +short "$domain" @8.8.8.8 | grep -E '^[0-9.]+$')
        for ip in $IPS; do
            echo "  Allowing $domain -> $ip"
            sudo iptables -A OUTPUT -d "$ip" -j ACCEPT
        done
    done < "$ALLOWED_DOMAINS_FILE"
else
    echo "WARNING: $ALLOWED_DOMAINS_FILE not found. No domains will be allowed."
fi

# Remove temporary DNS rule
sudo iptables -D OUTPUT -p udp --dport 53 -j ACCEPT

# Drop all other outbound traffic (IPv4 + IPv6)
sudo iptables -A OUTPUT -j DROP
sudo ip6tables -A OUTPUT -o lo -j ACCEPT
sudo ip6tables -A OUTPUT -j DROP

echo "Firewall rules applied. Only allowlisted domains and Docker host are reachable."

# Execute the command as claude user
exec "$@"
