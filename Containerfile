FROM ubuntu:24.04

# Build arguments for user UID/GID and sudo configuration
ARG USER_UID=1000
ARG USER_GID=1000
ARG NOSUDO=false

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bubblewrap \
    socat \
    curl \
    sudo \
    git \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user 'claude' with dynamic UID/GID
# Always remove default ubuntu user to avoid conflicts
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    (groupdel ubuntu 2>/dev/null || true) && \
    groupadd -g ${USER_GID} claude && \
    useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/bash claude

# Configure sudo for claude user (conditional based on NOSUDO build arg)
ARG NOSUDO
RUN if [ "$NOSUDO" = "true" ]; then \
        echo "Sudo disabled for claude user"; \
    else \
        echo 'claude ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/claude && \
        chmod 0440 /etc/sudoers.d/claude; \
    fi

# Switch to claude user for Claude Code installation
USER claude
WORKDIR /home/claude

# Install Claude Code CLI as the claude user (required for auto-updates)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add Claude Code to PATH
ENV PATH="/home/claude/.local/bin:${PATH}"

# Setup bash alias to launch claude with --allow-dangerously-skip-permissions
RUN echo 'alias claude="claude --allow-dangerously-skip-permissions"' >> /home/claude/.bashrc

# Set working directory to the shared workspace
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
