#!/bin/bash
##
## List Containers Script
## Shows all running podman containers
## Usage: ./list-containers.sh
##

set -e

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

echo "=== Running Containers ==="
echo ""

# List all running containers
if podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" | tail -n +2 | grep -q .; then
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
else
    echo "No running containers found"
fi

echo ""
echo "=== All Containers (including stopped) ==="
echo ""

# List all containers including stopped ones
if podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" | tail -n +2 | grep -q .; then
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
else
    echo "No containers found"
fi

echo ""
