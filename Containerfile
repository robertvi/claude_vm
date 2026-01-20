##
## Containerfile for Claude Code Sandbox Environment
## Based on Ubuntu with SSH server, Claude Code CLI, and development tools
##

FROM ubuntu:latest

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # SSH server
    openssh-server \
    # Basic utilities
    curl \
    wget \
    git \
    vim \
    nano \
    ca-certificates \
    gnupg \
    lsb-release \
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

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user 'claude'
# Remove ubuntu user if it exists (conflicts with UID 1000), then create claude user
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    useradd -m -s /bin/bash -u 1000 claude && \
    echo 'claude:claude' | chpasswd && \
    usermod -aG sudo claude

# Configure SSH
RUN mkdir /var/run/sshd && \
    # Allow password authentication for initial setup
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # Allow the claude user to login
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Create workspace directory
RUN mkdir -p /workspace && \
    chown claude:claude /workspace

# Create Claude Code config directory
RUN mkdir -p /home/claude/.config/claude-code && \
    chown -R claude:claude /home/claude/.config

# Copy Claude Code configuration
COPY --chown=claude:claude config/claude-settings.json /home/claude/.config/claude-code/settings.json

# Copy SSH configuration
COPY config/sshd_config /etc/ssh/sshd_config

# Copy entrypoint script
COPY setup/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set up shell environment for claude user
RUN echo 'export HTTP_PROXY="http://host.containers.internal:8888"' >> /home/claude/.bashrc && \
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
    echo '    echo ""' >> /home/claude/.bashrc && \
    echo 'fi' >> /home/claude/.bashrc

# Expose SSH port
EXPOSE 22

# Set working directory
WORKDIR /home/claude

# Run entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
