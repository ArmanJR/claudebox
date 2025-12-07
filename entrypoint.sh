#!/bin/bash

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

# Resolve and allow anthropic.com domains
for domain in anthropic.com claude.ai api.anthropic.com console.anthropic.com; do
    echo "Resolving $domain..."
    IPS=$(dig +short $domain @8.8.8.8 | grep -E '^[0-9.]+$')
    for ip in $IPS; do
        echo "Allowing $domain -> $ip"
        sudo iptables -A OUTPUT -d $ip -j ACCEPT
    done
done

# Drop all other outbound traffic
sudo iptables -A OUTPUT -j DROP

echo "Firewall rules applied. Only Anthropic/Claude domains and Docker host are allowed."

# Execute the command as claude user
exec "$@"
