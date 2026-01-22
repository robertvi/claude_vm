#!/bin/bash
##
## Host Script for Claude Code Metadata Backup
## Executes the in-container backup script with GitHub credentials
## Usage: ./backup-claude.sh
##
## Required environment variables:
##   GITHUB_PAT  - Fine-grained GitHub PAT with cc-backup repo access
##   GITHUB_USER - GitHub username
##

set -e

CONTAINER_NAME="claude-sandbox"

# Check required environment variables
if [ -z "$GITHUB_PAT" ]; then
    echo "ERROR: GITHUB_PAT environment variable not set"
    echo "Usage: GITHUB_PAT=xxx GITHUB_USER=yyy ./scripts/backup-claude.sh"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo "ERROR: GITHUB_USER environment variable not set"
    echo "Usage: GITHUB_PAT=xxx GITHUB_USER=yyy ./scripts/backup-claude.sh"
    exit 1
fi

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is not installed"
    exit 1
fi

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running"
    echo "Start the container first: ./scripts/run.sh /path/to/projects"
    exit 1
fi

echo "=== Claude Code Metadata Backup ==="
echo ""
echo "Container: $CONTAINER_NAME"
echo "GitHub User: $GITHUB_USER"
echo ""

# Execute backup script inside container, passing credentials via environment
podman exec \
    -e GITHUB_PAT="$GITHUB_PAT" \
    -e GITHUB_USER="$GITHUB_USER" \
    "$CONTAINER_NAME" \
    /usr/local/bin/claude-backup.sh

echo ""
echo "=== Backup Complete ==="
