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

### Verification
```bash
podman logs claude-sandbox                              # View container logs
curl -v --proxy $HTTP_PROXY https://api.anthropic.com  # Test allowed domain
curl -v --proxy $HTTP_PROXY https://example.com        # Test blocked domain (should fail)
```

## Architecture

```
Host Machine
├── Tinyproxy (port 8888) - network filter, runs on HOST not container
│   ├── Restrictive: host/tinyproxy.conf + host/filter (whitelist)
│   └── Permissive: host/tinyproxy-permissive.conf (allows all)
└── Rootless Podman Container (claude-sandbox)
    ├── ~/bin/claude → wrapper adding --dangerously-skip-permissions
    ├── ~/.local/bin/claude → native binary (auto-updates here)
    ├── UID 1000 mapping via --userns=keep-id
    └── /workspace → host shared folder (:Z for SELinux)
```

## Key Implementation Details

- **Auto-approval wrapper**: `Containerfile` installs a wrapper at `~/bin/claude` that calls the native binary at `~/.local/bin/claude` with `--dangerously-skip-permissions` flag. The wrapper is separate from the binary so auto-updates don't overwrite it.
- **Passwordless sudo**: The `claude` user has full passwordless sudo access in the container
- **Network whitelist**: Edit `host/filter` with POSIX regex patterns, then `sudo systemctl restart tinyproxy`
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

Tinyproxy runs on the host specifically so Claude cannot disable it from within the container. The shared folder at `/workspace` has full read-write access from the container.
