#!/bin/bash
##
## Firewall Setup Script for Claude Container Network Hardening
## This script enforces that all container traffic must go through the proxy
## Run on the HOST machine with sudo
##
## Usage: sudo ./scripts/setup-firewall.sh [start|stop|status]
##

set -e

# Configuration
PROXY_PORT=8888
CHAIN_NAME="CONTAINER_OUTBOUND"

# Detect container network interface and gateway
detect_container_network() {
    # Try common podman network interfaces
    for iface in "cni-podman0" "podman0" "cni0" "docker0"; do
        if ip link show "$iface" &>/dev/null; then
            CONTAINER_IFACE="$iface"
            break
        fi
    done

    if [ -z "$CONTAINER_IFACE" ]; then
        echo "WARNING: Could not auto-detect container network interface"
        echo "Trying to detect from podman network..."
        # Try to get from podman network inspect
        CONTAINER_IFACE=$(podman network inspect podman 2>/dev/null | grep -o '"interface": "[^"]*"' | head -1 | cut -d'"' -f4) || true
    fi

    if [ -z "$CONTAINER_IFACE" ]; then
        echo "ERROR: Could not detect container network interface"
        echo "Please set CONTAINER_IFACE environment variable manually"
        exit 1
    fi

    # Detect gateway IP (typically the host IP on the container network)
    HOST_IP=$(ip -4 addr show "$CONTAINER_IFACE" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1) || true

    if [ -z "$HOST_IP" ]; then
        # Fallback to common podman gateway
        HOST_IP="10.88.0.1"
        echo "WARNING: Could not detect host IP, using default: $HOST_IP"
    fi

    # Detect container network CIDR
    CONTAINER_CIDR=$(ip -4 addr show "$CONTAINER_IFACE" 2>/dev/null | grep -oP 'inet \K[\d./]+' | head -1) || true

    if [ -z "$CONTAINER_CIDR" ]; then
        # Fallback to common podman network
        CONTAINER_CIDR="10.88.0.0/16"
        echo "WARNING: Could not detect container CIDR, using default: $CONTAINER_CIDR"
    fi

    echo "Detected container interface: $CONTAINER_IFACE"
    echo "Detected host IP on container network: $HOST_IP"
    echo "Detected container CIDR: $CONTAINER_CIDR"
}

setup_firewall() {
    echo "=== Setting up container network firewall ==="
    echo ""

    detect_container_network

    echo ""
    echo "Creating iptables rules..."

    # Create the custom chain if it doesn't exist
    iptables -N "$CHAIN_NAME" 2>/dev/null || iptables -F "$CHAIN_NAME"

    # Remove existing jump rule if present (to avoid duplicates)
    iptables -D FORWARD -i "$CONTAINER_IFACE" -j "$CHAIN_NAME" 2>/dev/null || true

    # Rule 1: Allow traffic to the proxy on the host
    iptables -A "$CHAIN_NAME" -p tcp -d "$HOST_IP" --dport "$PROXY_PORT" -j ACCEPT \
        -m comment --comment "Allow container to proxy"

    # Rule 2: Allow established/related connections (for proxy responses)
    iptables -A "$CHAIN_NAME" -m state --state ESTABLISHED,RELATED -j ACCEPT \
        -m comment --comment "Allow established connections"

    # Rule 3: Allow localhost
    iptables -A "$CHAIN_NAME" -d 127.0.0.0/8 -j ACCEPT \
        -m comment --comment "Allow localhost"

    # Rule 4: Allow container-to-container communication on the same network
    # Extract just the network portion for the rule
    NETWORK_ONLY=$(echo "$CONTAINER_CIDR" | cut -d'/' -f1 | sed 's/\.[0-9]*$/\.0/')/16
    iptables -A "$CHAIN_NAME" -d "$NETWORK_ONLY" -j ACCEPT \
        -m comment --comment "Allow container-to-container"

    # Rule 5: Block direct DNS (UDP/TCP port 53) - force DNS through proxy
    iptables -A "$CHAIN_NAME" -p udp --dport 53 -j REJECT --reject-with icmp-port-unreachable \
        -m comment --comment "Block direct DNS UDP"
    iptables -A "$CHAIN_NAME" -p tcp --dport 53 -j REJECT --reject-with icmp-port-unreachable \
        -m comment --comment "Block direct DNS TCP"

    # Rule 6: Block all other outbound traffic from containers
    iptables -A "$CHAIN_NAME" -j REJECT --reject-with icmp-port-unreachable \
        -m comment --comment "Block all other container outbound"

    # Apply to FORWARD chain for container traffic
    iptables -I FORWARD -i "$CONTAINER_IFACE" -j "$CHAIN_NAME" \
        -m comment --comment "Jump to container outbound rules"

    echo ""
    echo "Firewall rules applied successfully!"
    echo ""
    echo "Rules in $CHAIN_NAME chain:"
    iptables -L "$CHAIN_NAME" -v -n --line-numbers
}

remove_firewall() {
    echo "=== Removing container network firewall rules ==="
    echo ""

    detect_container_network

    # Remove jump rule from FORWARD chain
    iptables -D FORWARD -i "$CONTAINER_IFACE" -j "$CHAIN_NAME" 2>/dev/null || true

    # Flush and delete the custom chain
    iptables -F "$CHAIN_NAME" 2>/dev/null || true
    iptables -X "$CHAIN_NAME" 2>/dev/null || true

    echo "Firewall rules removed successfully!"
}

show_status() {
    echo "=== Container Network Firewall Status ==="
    echo ""

    if iptables -L "$CHAIN_NAME" -n &>/dev/null; then
        echo "Firewall chain '$CHAIN_NAME' is ACTIVE"
        echo ""
        echo "Current rules:"
        iptables -L "$CHAIN_NAME" -v -n --line-numbers
        echo ""
        echo "FORWARD chain (showing container rules):"
        iptables -L FORWARD -v -n --line-numbers | grep -E "(Chain|$CHAIN_NAME|pkts)" || true
    else
        echo "Firewall chain '$CHAIN_NAME' does NOT exist (firewall not active)"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if iptables is available
if ! command -v iptables &>/dev/null; then
    echo "ERROR: iptables is not installed"
    echo "Please install iptables: sudo apt-get install iptables"
    exit 1
fi

# Parse command
case "${1:-start}" in
    start|setup)
        setup_firewall
        ;;
    stop|remove)
        remove_firewall
        ;;
    status)
        show_status
        ;;
    restart)
        remove_firewall
        echo ""
        setup_firewall
        ;;
    *)
        echo "Usage: $0 [start|stop|status|restart]"
        echo ""
        echo "Commands:"
        echo "  start   - Set up firewall rules (default)"
        echo "  stop    - Remove firewall rules"
        echo "  status  - Show current firewall status"
        echo "  restart - Remove and re-apply firewall rules"
        exit 1
        ;;
esac
