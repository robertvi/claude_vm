#!/bin/bash
set -e

# Check for --test flag
if [[ "$1" == "--test" ]]; then
    CONTAINER_NAME="claude-sandbox-test"
    LOG_FILE="/tmp/claude-sandbox-test-exec.log"
else
    CONTAINER_NAME="claude-sandbox"
    LOG_FILE="/tmp/claude-sandbox-exec.log"
fi

> "$LOG_FILE"

if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '${CONTAINER_NAME}' is not running."
    echo "Start it with: ./scripts/run.sh${1:+ $1}"
    exit 1
fi

echo "[$(date)] Accessing container: ${CONTAINER_NAME}" >> "$LOG_FILE"

podman exec -it "$CONTAINER_NAME" /bin/bash
