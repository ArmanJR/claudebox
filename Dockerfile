FROM node:20-bookworm

ARG CLAUDE_CODE_VERSION=latest

# Install iptables and claude-code
RUN apt-get update && \
    apt-get install -y iptables iproute2 dnsutils sudo && \
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash claude && \
    echo "claude ALL=(ALL) NOPASSWD: /usr/sbin/iptables, /usr/sbin/ip6tables" >> /etc/sudoers

# Create entrypoint script to setup firewall rules
COPY entrypoint.sh /entrypoint.sh
COPY allowed-domains.txt /etc/allowed-domains.txt
COPY server.js /opt/claudebox/server.js
RUN chmod 755 /entrypoint.sh

WORKDIR /workspace
RUN chown claude:claude /workspace

USER claude

EXPOSE 3000

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["node", "/opt/claudebox/server.js"]
