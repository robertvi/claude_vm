#!/bin/bash
##
## Container Entrypoint Script
## Sets up the environment and starts SSH server
##

set -e

echo "=== Claude Code Container Starting ==="

# Detect host IP for proxy configuration
# In Podman, the host is accessible via host.containers.internal
# or we can detect it from the default gateway
if [ -z "$HOST_IP" ]; then
    # Try to use host.containers.internal first (Podman/Docker Desktop)
    if getent hosts host.containers.internal > /dev/null 2>&1; then
        HOST_IP="host.containers.internal"
    else
        # Fallback: detect gateway IP (works in most bridge networks)
        HOST_IP=$(ip route | grep default | awk '{print $3}')
    fi
fi

echo "Detected host IP: $HOST_IP"

# Set proxy environment variables for this session
export HTTP_PROXY="http://${HOST_IP}:8888"
export HTTPS_PROXY="http://${HOST_IP}:8888"
export http_proxy="http://${HOST_IP}:8888"
export https_proxy="http://${HOST_IP}:8888"
export NO_PROXY="localhost,127.0.0.1"
export no_proxy="localhost,127.0.0.1"

# Update proxy settings in claude user's bashrc (dynamic)
sed -i "s|host.containers.internal|${HOST_IP}|g" /home/claude/.bashrc || true

echo "Proxy configured: $HTTP_PROXY"

# Generate host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Start SSH server
echo "Starting SSH server..."
/usr/sbin/sshd -D &

# Store SSH PID
SSH_PID=$!

# Display connection info
echo ""
echo "=== Container Ready ==="
echo "SSH server is running on port 22"
echo "Connect from host with: ssh -p 2222 claude@localhost"
echo "Default password: claude"
echo ""
echo "Workspace: /workspace"
echo "Proxy: $HTTP_PROXY"
echo ""

# Handle shutdown gracefully
trap "echo 'Shutting down...'; kill $SSH_PID; exit 0" SIGTERM SIGINT

# Wait for SSH server
wait $SSH_PID
