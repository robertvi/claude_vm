#!/bin/bash
##
## Run Script for Claude Code Container
## Creates and starts the container with shared folder mount
## Usage: ./run.sh [shared_folder_path]
## If no shared_folder_path is provided, current directory is used
##

set -e

IMAGE_NAME="claude-sandbox"
IMAGE_TAG="latest"
CONTAINER_NAME="claude-sandbox"

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

# Parse arguments
if [ "$#" -eq 0 ]; then
    # Use current working directory as default
    SHARED_FOLDER="$(pwd)"
    echo "No shared folder specified, using current directory: $SHARED_FOLDER"
    echo ""
else
    SHARED_FOLDER="$1"
fi

# Validate shared folder
if [ ! -d "$SHARED_FOLDER" ]; then
    echo "ERROR: Shared folder does not exist: $SHARED_FOLDER"
    echo "Please create it first or provide a valid path"
    exit 1
fi

# Convert to absolute path
SHARED_FOLDER="$(cd "$SHARED_FOLDER" && pwd)"

# Determine which SSH key is being used (for display purposes)
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_KEY_TYPE="ed25519"
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    SSH_KEY_PATH="$HOME/.ssh/id_rsa"
    SSH_KEY_TYPE="rsa"
else
    echo "ERROR: No SSH key found"
    echo "Please run ./scripts/build.sh first to generate and embed an SSH key"
    exit 1
fi

echo "=== Starting Claude Code Container ==="
echo ""
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo "Container name: $CONTAINER_NAME"
echo "Shared folder: $SHARED_FOLDER"
echo ""

# Stop and remove existing container if it exists
if podman container exists "$CONTAINER_NAME"; then
    echo "Removing existing container..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Check if image exists
if ! podman image exists "$IMAGE_NAME:$IMAGE_TAG"; then
    echo "ERROR: Image $IMAGE_NAME:$IMAGE_TAG does not exist"
    echo "Please build it first: ./scripts/build.sh"
    exit 1
fi

# Note about authentication
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Note: ANTHROPIC_API_KEY is not set"
    echo "      You'll need to authenticate when you first run Claude Code inside the container"
    echo "      (API key users: set ANTHROPIC_API_KEY before running this script)"
    echo "      (Subscription users: authenticate interactively with 'claude' command)"
    echo ""
fi

# Run the container
echo "Starting container..."
echo ""

podman run -d \
    --name "$CONTAINER_NAME" \
    --hostname claude-sandbox \
    -p 2222:22 \
    -v "$SHARED_FOLDER:/workspace:rw" \
    -e HOST_UID=$(id -u) \
    -e HOST_GID=$(id -g) \
    ${ANTHROPIC_API_KEY:+-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
    --add-host=host.containers.internal:host-gateway \
    "$IMAGE_NAME:$IMAGE_TAG"

# Wait for container to start
sleep 2

# Check if container is running
if podman ps | grep -q "$CONTAINER_NAME"; then
    echo "✓ Container started successfully"
    echo ""
    echo "=== Container Information ==="
    podman ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "=== Connection Details ==="
    echo "SSH: ssh -p 2222 -i $SSH_KEY_PATH claude@localhost"
    echo "Authentication: Key-based ($SSH_KEY_TYPE)"
    echo ""
    echo "Workspace in container: /workspace"
    echo "Workspace on host: $SHARED_FOLDER"
    echo ""
    echo "To connect: ./scripts/connect.sh"
    echo "To view logs: podman logs $CONTAINER_NAME"
    echo "To stop: podman stop $CONTAINER_NAME"
    echo ""
else
    echo "✗ ERROR: Container failed to start"
    echo ""
    echo "Logs:"
    podman logs "$CONTAINER_NAME"
    exit 1
fi
