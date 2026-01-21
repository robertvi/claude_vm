#!/bin/bash
##
## Stop Container Script
## Stops the claude-sandbox container
## Usage: ./stop-container.sh
##

set -e

CONTAINER_NAME="claude-sandbox"

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

echo "=== Stopping Claude Code Container ==="
echo ""

# Check if container exists
if ! podman container exists "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' does not exist"
    exit 0
fi

# Check if container is running
if ! podman ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "Container '$CONTAINER_NAME' is not running"
    exit 0
fi

# Stop the container
echo "Stopping container '$CONTAINER_NAME'..."
podman stop "$CONTAINER_NAME"

echo ""
echo "✓ Container stopped successfully"
echo ""
echo "To start again: ./scripts/run.sh <shared_folder_path>"
echo "To remove container: podman rm $CONTAINER_NAME"
echo ""
