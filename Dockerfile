FROM node:20-bookworm

# Install iptables and claude-code
RUN apt-get update && \
    apt-get install -y iptables dnsutils sudo && \
    npm install -g @anthropic-ai/claude-code@2.0.60 && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash claude && \
    echo "claude ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create entrypoint script to setup firewall rules
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

WORKDIR /workspace
RUN chown claude:claude /workspace

USER claude

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["/bin/bash"]
