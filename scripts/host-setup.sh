#!/bin/bash
##
## Host Setup Script for Claude Code Container Environment
## This script installs and configures tinyproxy on the host machine
##

set -e

echo "=== Claude Code Container - Host Setup ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
else
    echo "ERROR: No supported package manager found (apt, dnf, or yum required)"
    exit 1
fi

# Install tinyproxy
echo "[1/5] Installing tinyproxy..."
if [ "$PKG_MANAGER" = "apt" ]; then
    apt-get update
    apt-get install -y tinyproxy
elif [ "$PKG_MANAGER" = "dnf" ]; then
    dnf install -y tinyproxy
elif [ "$PKG_MANAGER" = "yum" ]; then
    yum install -y tinyproxy
fi

# Create backup of original config if exists
echo "[2/5] Backing up original tinyproxy configuration..."
if [ -f /etc/tinyproxy/tinyproxy.conf ]; then
    cp /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Copy restrictive configuration
echo "[3/5] Installing restrictive tinyproxy configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cp "$PROJECT_ROOT/host/tinyproxy.conf" /etc/tinyproxy/tinyproxy.conf
cp "$PROJECT_ROOT/host/filter" /etc/tinyproxy/filter

# Copy permissive configuration for updates
echo "[4/5] Installing permissive tinyproxy configuration..."
cp "$PROJECT_ROOT/host/tinyproxy-permissive.conf" /etc/tinyproxy/tinyproxy-permissive.conf
cp "$PROJECT_ROOT/host/filter-permissive" /etc/tinyproxy/filter-permissive

# Set proper permissions
chmod 644 /etc/tinyproxy/tinyproxy.conf
chmod 644 /etc/tinyproxy/tinyproxy-permissive.conf
chmod 644 /etc/tinyproxy/filter
chmod 644 /etc/tinyproxy/filter-permissive

# Start and enable tinyproxy
echo "[5/5] Starting tinyproxy service..."
if command -v systemctl &> /dev/null; then
    systemctl restart tinyproxy
    systemctl enable tinyproxy

    # Show status
    echo ""
    echo "Tinyproxy service status:"
    systemctl status tinyproxy --no-pager || true
else
    # Non-systemd systems
    service tinyproxy restart || /etc/init.d/tinyproxy restart
fi

# Verify tinyproxy is listening
echo ""
echo "Verifying tinyproxy is listening on port 8888..."
sleep 2
if netstat -tuln 2>/dev/null | grep -q ':8888 ' || ss -tuln 2>/dev/null | grep -q ':8888 '; then
    echo "✓ Tinyproxy is listening on port 8888"
else
    echo "⚠ WARNING: Could not verify tinyproxy is listening on port 8888"
    echo "  Please check the service status manually"
fi

echo ""
echo "=== Host setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Build the container: ./scripts/build.sh"
echo "  2. Run the container: ./scripts/run.sh /path/to/shared/folder"
echo "  3. Connect via SSH: ./scripts/connect.sh"
echo ""
echo "To toggle proxy modes (for updates):"
echo "  sudo ./scripts/toggle-proxy.sh permissive"
echo "  sudo ./scripts/toggle-proxy.sh restrictive"
echo ""
