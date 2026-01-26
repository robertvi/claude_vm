#!/bin/bash
set -e

# Check for --test flag and extract shared folder
TEST_MODE=false
SHARED_FOLDER=""

for arg in "$@"; do
    if [[ "$arg" == "--test" ]]; then
        TEST_MODE=true
    else
        SHARED_FOLDER="$arg"
    fi
done

SHARED_FOLDER="${SHARED_FOLDER:-$(pwd)}"

if $TEST_MODE; then
    CONTAINER_NAME="claude-sandbox-test"
    IMAGE_NAME="claude-sandbox-test"
    LOG_FILE="/tmp/claude-sandbox-test-run.log"
else
    CONTAINER_NAME="claude-sandbox"
    IMAGE_NAME="claude-sandbox"
    LOG_FILE="/tmp/claude-sandbox-run.log"
fi

USER_UID=$(id -u)
USER_GID=$(id -g)

> "$LOG_FILE"

if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '${CONTAINER_NAME}' already exists."
    echo "To restart, first run: podman rm -f ${CONTAINER_NAME}"
    exit 1
fi

echo "Starting container with UID:GID ${USER_UID}:${USER_GID}... (logging to ${LOG_FILE})"
podman run -d \
  --name "$CONTAINER_NAME" \
  --hostname "$CONTAINER_NAME" \
  --userns=keep-id:uid=${USER_UID},gid=${USER_GID} \
  -v "$SHARED_FOLDER:/workspace:Z" \
  "$IMAGE_NAME" 2>&1 | tee "$LOG_FILE"

echo "Container started: ${CONTAINER_NAME}"
echo "Shared folder: ${SHARED_FOLDER} -> /workspace"
echo "Access with: ./scripts/exec.sh${TEST_MODE:+ --test}"
