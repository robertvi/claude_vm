##
## Containerfile for Claude Code Sandbox Environment
## Based on Ubuntu with Claude Code CLI and development tools
##

FROM ubuntu:latest

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Basic utilities
    curl \
    wget \
    git \
    vim \
    nano \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    iproute2 \
    # Build tools
    build-essential \
    # Python and pip
    python3 \
    python3-pip \
    python3-venv \
    # Node.js dependencies (will install Node.js from NodeSource)
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (LTS) from NodeSource
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user 'claude' before installing Claude Code
# Remove ubuntu user if it exists (conflicts with UID 1000), then create claude user
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    useradd -m -s /bin/bash -u 1000 claude && \
    usermod -aG sudo claude && \
    # Configure passwordless sudo for claude user
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/claude && \
    chmod 0440 /etc/sudoers.d/claude

# Create ~/bin directory for wrapper script (separate from native binary location)
RUN mkdir -p /home/claude/bin && chown claude:claude /home/claude/bin

# Switch to claude user for native Claude Code installation
USER claude
WORKDIR /home/claude

# Install Claude Code using native installer (installs to ~/.local/bin/claude)
# This allows auto-updates without sudo since the binary is user-owned
RUN curl -fsSL https://claude.ai/install.sh | bash -s latest

# Create wrapper script at ~/bin/claude (separate from native binary)
# This allows auto-updates to work on ~/.local/bin/claude without breaking wrapper
# PATH order ensures wrapper is called: $HOME/bin:$HOME/.local/bin:$PATH
RUN echo '#!/bin/bash' > /home/claude/bin/claude && \
    echo '/home/claude/.local/bin/claude --dangerously-skip-permissions "$@"' >> /home/claude/bin/claude && \
    chmod +x /home/claude/bin/claude

# Switch back to root for remaining setup
USER root

# Create workspace directory
RUN mkdir -p /workspace && \
    chown claude:claude /workspace

# Create Claude Code config directory
RUN mkdir -p /home/claude/.config/claude-code && \
    chown -R claude:claude /home/claude/.config

# Copy Claude Code configuration
COPY --chown=claude:claude config/claude-settings.json /home/claude/.config/claude-code/settings.json

# Copy entrypoint script
COPY setup/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy backup script
COPY setup/claude-backup.sh /usr/local/bin/claude-backup.sh
RUN chmod +x /usr/local/bin/claude-backup.sh

# Set up shell environment for claude user
RUN echo '# PATH: wrapper first, then native binary' >> /home/claude/.bashrc && \
    echo 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' >> /home/claude/.bashrc && \
    echo '' >> /home/claude/.bashrc && \
    echo '# Proxy configuration' >> /home/claude/.bashrc && \
    echo 'export HTTP_PROXY="http://host.containers.internal:8888"' >> /home/claude/.bashrc && \
    echo 'export HTTPS_PROXY="http://host.containers.internal:8888"' >> /home/claude/.bashrc && \
    echo 'export http_proxy="http://host.containers.internal:8888"' >> /home/claude/.bashrc && \
    echo 'export https_proxy="http://host.containers.internal:8888"' >> /home/claude/.bashrc && \
    echo 'export NO_PROXY="localhost,127.0.0.1"' >> /home/claude/.bashrc && \
    echo 'export no_proxy="localhost,127.0.0.1"' >> /home/claude/.bashrc && \
    echo '' >> /home/claude/.bashrc && \
    echo '# Welcome message' >> /home/claude/.bashrc && \
    echo 'if [ -t 1 ]; then' >> /home/claude/.bashrc && \
    echo '    echo "=== Claude Code Sandbox ==="' >> /home/claude/.bashrc && \
    echo '    echo "Workspace: /workspace"' >> /home/claude/.bashrc && \
    echo '    echo "To start Claude: cd /workspace/your-project && claude --resume"' >> /home/claude/.bashrc && \
    echo '    echo "Auto-approval enabled (--dangerously-skip-permissions)"' >> /home/claude/.bashrc && \
    echo '    echo ""' >> /home/claude/.bashrc && \
    echo 'fi' >> /home/claude/.bashrc

# Set working directory
WORKDIR /home/claude

# Run entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
