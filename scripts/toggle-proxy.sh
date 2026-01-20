#!/bin/bash
##
## Toggle Tinyproxy Between Restrictive and Permissive Modes
## Usage: sudo ./toggle-proxy.sh [restrictive|permissive]
##

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [restrictive|permissive]"
    echo ""
    echo "Modes:"
    echo "  restrictive - Only allow Claude API and essential package registries"
    echo "  permissive  - Allow all connections (for OS updates)"
    exit 1
fi

MODE="$1"

# Validate mode
if [ "$MODE" != "restrictive" ] && [ "$MODE" != "permissive" ]; then
    echo "ERROR: Invalid mode '$MODE'. Must be 'restrictive' or 'permissive'"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Switching Tinyproxy to $MODE mode ==="
echo ""

# Copy appropriate configuration
if [ "$MODE" = "restrictive" ]; then
    echo "[1/3] Installing restrictive configuration..."
    cp "$PROJECT_ROOT/host/tinyproxy.conf" /etc/tinyproxy/tinyproxy.conf
    cp "$PROJECT_ROOT/host/filter" /etc/tinyproxy/filter
    echo "  → Restrictive mode: Only whitelisted domains allowed"
elif [ "$MODE" = "permissive" ]; then
    echo "[1/3] Installing permissive configuration..."
    cp "$PROJECT_ROOT/host/tinyproxy-permissive.conf" /etc/tinyproxy/tinyproxy.conf
    cp "$PROJECT_ROOT/host/filter-permissive" /etc/tinyproxy/filter
    echo "  → Permissive mode: All domains allowed"
fi

# Set proper permissions
chmod 644 /etc/tinyproxy/tinyproxy.conf
chmod 644 /etc/tinyproxy/filter

# Restart tinyproxy
echo "[2/3] Restarting tinyproxy service..."
if command -v systemctl &> /dev/null; then
    systemctl restart tinyproxy

    # Show status
    echo "[3/3] Verifying service status..."
    if systemctl is-active --quiet tinyproxy; then
        echo "  ✓ Tinyproxy is running"
    else
        echo "  ✗ ERROR: Tinyproxy failed to start"
        systemctl status tinyproxy --no-pager
        exit 1
    fi
else
    # Non-systemd systems
    service tinyproxy restart || /etc/init.d/tinyproxy restart
    echo "[3/3] Service restarted"
fi

echo ""
echo "=== Tinyproxy switched to $MODE mode successfully ==="
echo ""

if [ "$MODE" = "permissive" ]; then
    echo "⚠ WARNING: Permissive mode is active!"
    echo "  All network connections are allowed."
    echo "  Remember to switch back to restrictive mode after updates:"
    echo "  sudo $0 restrictive"
fi

echo ""
