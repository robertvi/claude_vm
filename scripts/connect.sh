#!/bin/bash
##
## Connect Script for Claude Code Container
## Connects to the container via SSH
##

CONTAINER_NAME="claude-sandbox"

echo "=== Connecting to Claude Code Container ==="
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

# Check if container is running
if ! podman ps | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running"
    echo ""
    echo "Start it with: ./scripts/run.sh /path/to/shared/folder"
    exit 1
fi

echo "Connecting via SSH..."
echo "Default password: claude"
echo ""

# Connect via SSH
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null claude@localhost
