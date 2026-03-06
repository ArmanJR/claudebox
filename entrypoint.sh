#!/bin/bash

ALLOWED_DOMAINS_FILE="/etc/allowed-domains.txt"

# Setup firewall rules with sudo (container must have NET_ADMIN capability)
echo "Setting up firewall rules..."

# Allow loopback
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow traffic to Docker host (gateway IP)
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
if [ -n "$GATEWAY_IP" ]; then
    echo "Allowing traffic to Docker host: $GATEWAY_IP"
    sudo iptables -A OUTPUT -d $GATEWAY_IP -j ACCEPT
fi

# Allow DNS temporarily so we can resolve domains
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

# Drop all other outbound traffic
sudo iptables -A OUTPUT -j DROP

echo "Firewall rules applied. Only allowlisted domains and Docker host are reachable."

# Execute the command as claude user
exec "$@"
