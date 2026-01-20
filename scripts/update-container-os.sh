#!/bin/bash
##
## Container OS Update Script
## Orchestrates switching tinyproxy to permissive mode, updating container OS, then switching back
## Usage: sudo ./update-container-os.sh
##

set -e

CONTAINER_NAME="claude-sandbox"

echo "=== Container OS Update Process ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if container is running
if ! podman ps | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running"
    echo "Start it with: ./scripts/run.sh /path/to/shared/folder"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/4] Switching tinyproxy to permissive mode..."
"$SCRIPT_DIR/toggle-proxy.sh" permissive

echo ""
echo "[2/4] Waiting for proxy to restart..."
sleep 2

echo ""
echo "[3/4] Updating container OS..."
echo ""

# Run apt update and upgrade in the container
podman exec -it "$CONTAINER_NAME" bash -c '
    echo "=== Running apt update ==="
    apt-get update
    echo ""
    echo "=== Running apt upgrade ==="
    apt-get upgrade -y
    echo ""
    echo "=== Cleaning up ==="
    apt-get autoremove -y
    apt-get clean
    echo ""
    echo "✓ Container OS updated successfully"
'

UPDATE_EXIT_CODE=$?

echo ""
echo "[4/4] Switching tinyproxy back to restrictive mode..."
"$SCRIPT_DIR/toggle-proxy.sh" restrictive

echo ""
if [ $UPDATE_EXIT_CODE -eq 0 ]; then
    echo "=== Container OS update complete! ==="
else
    echo "=== Container OS update failed ==="
    echo "Proxy has been switched back to restrictive mode"
    exit $UPDATE_EXIT_CODE
fi

echo ""
echo "Note: The updated packages will be lost if you rebuild the container"
echo "To make updates permanent, rebuild the container image after updating"
echo "the Containerfile to use a newer base image."
echo ""
