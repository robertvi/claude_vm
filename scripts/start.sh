#!/bin/bash
##
## Start Script for Claude Code Container
## Runs the container and automatically connects via podman exec
## Usage: ./start.sh [shared_folder_path]
## If no shared_folder_path is provided, current directory is used
## If container is already running, reuses it instead of restarting
##

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="claude-sandbox"

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

# Check if container is already running
if podman ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "=== Container Already Running ==="
    echo ""
    echo "Reusing existing container '$CONTAINER_NAME'"

    # Show current container info
    podman ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}"
    echo ""

    # Connect to the container
    "$SCRIPT_DIR/exec.sh"
    exit 0
fi

# Container not running, start it
echo "=== Starting New Container ==="
echo ""

# Parse arguments and pass to run.sh
if [ "$#" -eq 0 ]; then
    echo "Starting container with current directory as shared folder..."
    "$SCRIPT_DIR/run.sh"
else
    echo "Starting container with shared folder: $1"
    "$SCRIPT_DIR/run.sh" "$1"
fi

# Check if run.sh succeeded
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start container"
    exit 1
fi

echo "Waiting for container to be ready..."
sleep 2

# Connect to the container
"$SCRIPT_DIR/exec.sh"
