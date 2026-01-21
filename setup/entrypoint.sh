#!/bin/bash
##
## Container Entrypoint Script
## Sets up the environment and keeps container running
##

set -e

echo "=== Claude Code Container Starting ==="

# Detect host IP for proxy configuration
if [ -z "$HOST_IP" ]; then
    if getent hosts host.containers.internal > /dev/null 2>&1; then
        HOST_IP="host.containers.internal"
    else
        HOST_IP=$(ip route | grep default | awk '{print $3}')
    fi
fi

echo "Detected host IP: $HOST_IP"

# Set proxy environment variables
export HTTP_PROXY="http://${HOST_IP}:8888"
export HTTPS_PROXY="http://${HOST_IP}:8888"
export http_proxy="http://${HOST_IP}:8888"
export https_proxy="http://${HOST_IP}:8888"
export NO_PROXY="localhost,127.0.0.1"
export no_proxy="localhost,127.0.0.1"

# Update proxy settings in claude user's bashrc (dynamic)
sed -i "s|host.containers.internal|${HOST_IP}|g" /home/claude/.bashrc || true

echo "Proxy configured: $HTTP_PROXY"

# Display connection info
echo ""
echo "=== Container Ready ==="
echo "Connect with: podman exec -it claude-sandbox /bin/bash"
echo ""
echo "Workspace: /workspace"
echo "Proxy: $HTTP_PROXY"
echo ""

# Keep container running indefinitely
exec sleep infinity
