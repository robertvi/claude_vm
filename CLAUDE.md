# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a rootless Podman container environment for running Claude Code CLI in a sandboxed, network-restricted environment with auto-approval for bash commands. The network filtering runs on the host via tinyproxy, preventing the container from disabling restrictions.

## Common Commands

### Host Setup (one-time)
```bash
sudo ./scripts/host-setup.sh    # Install tinyproxy on host
./scripts/build.sh              # Build container image
```

### Daily Usage
```bash
./scripts/run.sh /path/to/projects   # Start container with shared folder
./scripts/exec.sh                    # Open shell in running container
./scripts/stop-container.sh          # Stop container
```

### Proxy Mode Management
```bash
sudo ./scripts/toggle-proxy.sh permissive   # Allow all domains (for updates)
sudo ./scripts/toggle-proxy.sh restrictive  # Whitelist only (normal operation)
sudo ./scripts/update-container-os.sh       # Updates OS (auto-toggles proxy)
```

### Firewall Management
```bash
sudo ./scripts/setup-firewall.sh status    # Check firewall status
sudo ./scripts/setup-firewall.sh restart   # Restart firewall rules
sudo ./scripts/setup-firewall.sh stop      # Remove firewall rules (not recommended)
```

### Verification
```bash
podman logs claude-sandbox                              # View container logs
curl -v --proxy $HTTP_PROXY https://api.anthropic.com  # Test allowed domain
curl -v --proxy $HTTP_PROXY https://example.com        # Test blocked domain (should fail)
```

## Architecture

```
Host Machine
├── iptables Firewall (CONTAINER_OUTBOUND chain)
│   ├── Blocks ALL direct outbound from container
│   ├── Only allows traffic to proxy port 8888
│   └── Blocks direct DNS queries
├── Tinyproxy (port 8888) - domain filter, runs on HOST
│   ├── Restrictive: host/tinyproxy.conf + host/filter (whitelist)
│   └── Permissive: host/tinyproxy-permissive.conf (allows all)
└── Rootless Podman Container (claude-sandbox)
    ├── --cap-drop=NET_RAW,NET_BIND_SERVICE
    ├── --security-opt seccomp=config/seccomp-network-restricted.json
    ├── ~/bin/claude → wrapper adding --dangerously-skip-permissions
    ├── ~/.local/bin/claude → native binary (auto-updates here)
    ├── UID 1000 mapping via --userns=keep-id
    └── /workspace → host shared folder (:Z for SELinux)
```

## Key Implementation Details

- **Auto-approval wrapper**: `Containerfile` installs a wrapper at `~/bin/claude` that calls the native binary at `~/.local/bin/claude` with `--dangerously-skip-permissions` flag. The wrapper is separate from the binary so auto-updates don't overwrite it.
- **Passwordless sudo**: The `claude` user has full passwordless sudo access in the container
- **Network whitelist**: Edit `host/filter` with POSIX regex patterns, then `sudo systemctl restart tinyproxy`
- **Firewall enforcement**: `scripts/setup-firewall.sh` creates iptables rules that block all direct outbound traffic except to the proxy
- **UID mapping**: Container user `claude` (UID 1000) maps to host UID 1000 for seamless file permissions
- **Proxy discovery**: `setup/entrypoint.sh` detects host IP via `host.containers.internal` or `ip route`

## Known Limitations

- **UID 1000 assumption**: Both host user and container user must be UID 1000 for file permissions to work correctly

## Network Whitelist (host/filter)

Allowed domains include:
- Claude API: api.anthropic.com, claude.ai, statsig.anthropic.com, sentry.io
- Claude Code updates: storage.googleapis.com (native binary distribution)
- GitHub: github.com, *.github.com, *.githubusercontent.com
- Package registries: registry.npmjs.org, pypi.org, archive.ubuntu.com

To add domains, append regex patterns to `host/filter` and restart tinyproxy.

## Security Model

Multi-layer network enforcement:
1. **iptables firewall** (kernel-level): Blocks all direct outbound traffic, only allows proxy
2. **Tinyproxy** (application-level): Domain whitelist filtering
3. **Capability drops**: NET_RAW (no raw sockets), NET_BIND_SERVICE (no privileged ports)
4. **Seccomp profile**: Blocks AF_PACKET and SOCK_RAW syscalls

This prevents bypassing the proxy by unsetting env vars or using direct sockets. The shared folder at `/workspace` has full read-write access from the container.
