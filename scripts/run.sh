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

# Build environment variable arguments for backup credentials (if set)
ENV_ARGS=""
if [ -n "$GITHUB_PAT" ]; then
    ENV_ARGS="$ENV_ARGS -e GITHUB_PAT=$GITHUB_PAT"
fi
if [ -n "$GITHUB_USER" ]; then
    ENV_ARGS="$ENV_ARGS -e GITHUB_USER=$GITHUB_USER"
fi

# Run the container
echo "Starting container..."
echo ""

podman run -d \
    --name "$CONTAINER_NAME" \
    --hostname claude-sandbox \
    --userns=keep-id \
    --user 1000:1000 \
    -v "$SHARED_FOLDER:/workspace:Z" \
    --add-host=host.containers.internal:host-gateway \
    $ENV_ARGS \
    "$IMAGE_NAME:$IMAGE_TAG"

# Wait for container to start
sleep 2

# Check if container is running
if podman ps | grep -q "$CONTAINER_NAME"; then
    echo "✓ Container started successfully"
    echo ""
    echo "=== Container Information ==="
    podman ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}"
    echo ""
    echo "=== Connection Details ==="
    echo "Access container: ./scripts/exec.sh"
    echo "  or: podman exec -it $CONTAINER_NAME /bin/bash"
    echo ""
    echo "Workspace in container: /workspace"
    echo "Workspace on host: $SHARED_FOLDER"
    echo ""
    echo "To connect: ./scripts/exec.sh"
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
