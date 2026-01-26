#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for --test flag
if [[ "$1" == "--test" ]]; then
    IMAGE_NAME="claude-sandbox-test"
    CONTAINERFILE="Containerfile.test"
    LOG_FILE="/tmp/claude-sandbox-test-build.log"
    echo "Building TEST image..."
else
    IMAGE_NAME="claude-sandbox"
    CONTAINERFILE="Containerfile"
    LOG_FILE="/tmp/claude-sandbox-build.log"
fi

USER_UID=$(id -u)
USER_GID=$(id -g)

> "$LOG_FILE"

echo "Building container image for UID:GID ${USER_UID}:${USER_GID}... (logging to ${LOG_FILE})"
podman build \
  --no-cache \
  --build-arg USER_UID="${USER_UID}" \
  --build-arg USER_GID="${USER_GID}" \
  -t "$IMAGE_NAME" \
  -f "$PROJECT_DIR/$CONTAINERFILE" "$PROJECT_DIR" 2>&1 | tee "$LOG_FILE"

echo "Build complete. Image tagged as: ${IMAGE_NAME}"
