#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

parse_common_args "$@"

IMAGE_NAME=$(get_image_name "$TEST_MODE")

if [[ "$TEST_MODE" == "true" ]]; then
    CONTAINERFILE="Containerfile.test"
    LOG_FILE="/tmp/claude-sandbox-test-build.log"
    info "Building TEST image..."
else
    CONTAINERFILE="Containerfile"
    LOG_FILE="/tmp/claude-sandbox-build.log"
fi

USER_UID=$(id -u)
USER_GID=$(id -g)

# Determine NOSUDO value for build arg
if [[ "$NOSUDO_MODE" == "true" ]]; then
    NOSUDO_ARG="true"
    info "Building with sudo DISABLED for claude user"
else
    NOSUDO_ARG="false"
fi

> "$LOG_FILE"

info "Building container image for UID:GID ${USER_UID}:${USER_GID}... (logging to ${LOG_FILE})"
podman build \
  --no-cache \
  --build-arg USER_UID="${USER_UID}" \
  --build-arg USER_GID="${USER_GID}" \
  --build-arg NOSUDO="${NOSUDO_ARG}" \
  -t "$IMAGE_NAME" \
  -f "$PROJECT_DIR/$CONTAINERFILE" "$PROJECT_DIR" 2>&1 | tee "$LOG_FILE"

info "Build complete. Image tagged as: ${IMAGE_NAME}"
