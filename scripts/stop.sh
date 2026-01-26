#!/bin/bash
set -e

# Check for --test flag
if [[ "$1" == "--test" ]]; then
    CONTAINER_NAME="claude-sandbox-test"
else
    CONTAINER_NAME="claude-sandbox"
fi

if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '${CONTAINER_NAME}' does not exist."
    exit 1
fi

echo "Stopping container: ${CONTAINER_NAME}"
podman stop "$CONTAINER_NAME"
podman rm "$CONTAINER_NAME"
echo "Container stopped and removed."
