#!/bin/bash
##
## Exec Script for Claude Code Container
## Opens an interactive bash shell in the container
## Usage: ./exec.sh
##

CONTAINER_NAME="claude-sandbox"

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

echo "=== Connecting to Claude Code Container ==="
echo ""
echo "Opening interactive bash shell in /workspace"
echo "Type 'exit' to leave the container"
echo ""

# Execute bash in the container, starting in /workspace
podman exec -it -w /workspace "$CONTAINER_NAME" /bin/bash
