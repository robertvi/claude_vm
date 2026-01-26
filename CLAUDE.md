# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project creates scripts to set up a rootless Podman container running Claude Code CLI in sandbox mode (using bubblewrap). The goal is to simplify the previous complex network filtering approach by leveraging Claude's built-in sandboxing capabilities.

## Project Requirements (from README)

Create three main scripts:
1. **Image creation script** - Build Ubuntu-based container with Claude Code installed
2. **Container run script** - Start container with shared folder mounting (default: current directory, or specified path)
3. **Interactive exec script** - Open terminal session inside running container

Key requirements:
- **Rootless Podman** (no sudo for container operations)
- **Ubuntu base image**
- **Claude Code installed as limited user** (not root) to enable auto-updates
- **Sandbox mode enabled** (requires bubblewrap in container)
- **Passwordless sudo** option inside container
- **Shared folder mounting** with proper UID mapping

## Architecture Approach

```
Host Machine
└── Rootless Podman Container
    ├── Ubuntu base
    ├── bubblewrap (for Claude sandbox mode)
    ├── Claude Code CLI installed as non-root user (UID 1000)
    ├── Passwordless sudo configured
    ├── /workspace → host shared folder (:Z for SELinux)
    └── UID mapping via --userns=keep-id
```

## Implementation Guidelines

### Container Image (Containerfile/Dockerfile)

- Base: Ubuntu (latest LTS recommended)
- Create non-root user `claude` with UID 1000
- Install dependencies:
  - `bubblewrap` (required for Claude sandbox mode)
  - `curl` or `wget` (for Claude installation)
  - `sudo` (for passwordless sudo option)
  - `git`, `build-essential` (common development tools)
- Install Claude Code as the `claude` user:
  - Follow Claude Code installation instructions for Linux
  - Install to user's home directory (typically `~/.local/bin/claude`)
  - Do NOT install as root to ensure auto-updates work correctly
- Configure passwordless sudo for `claude` user
- Set container to run indefinitely (e.g., `sleep infinity` or similar)

### Build Script

Basic concept (actual script in `scripts/build.sh` has more features):
```bash
#!/bin/bash
# Build the container image using Podman
podman build -t claude-sandbox -f Containerfile .
```

### Run Script

Basic concept (actual script in `scripts/run.sh` supports `--test`, `--name`, etc.):
```bash
#!/bin/bash
# Start container with shared folder
SHARED_FOLDER="${1:-$(pwd)}"
CONTAINER_NAME="claude-sandbox-default"

podman run -d \
  --name "$CONTAINER_NAME" \
  --userns=keep-id \
  -v "$SHARED_FOLDER:/workspace:Z" \
  claude-sandbox \
  sleep infinity
```

Key flags:
- `--userns=keep-id`: Maps host UID to container UID for seamless file permissions
- `-v "$FOLDER:/workspace:Z"`: Mount shared folder with SELinux relabeling
- `-d`: Detached mode (run in background)

### Exec Script

Basic concept (actual script in `scripts/exec.sh` supports auto-detection):
```bash
#!/bin/bash
# Open interactive shell in running container
CONTAINER_NAME="claude-sandbox-default"
podman exec -it "$CONTAINER_NAME" /bin/bash
```

### Claude Sandbox Mode

Claude Code has built-in sandbox mode that uses bubblewrap:
- Enabled with `--sandbox` flag or via settings
- Requires `bubblewrap` package installed in container
- Provides process isolation for bash commands
- No additional network filtering setup needed

## File Structure

Repository layout:
```
claude_container/
├── Containerfile          # Production container image definition
├── Containerfile.test     # Test container image definition
├── README.md              # Project description
├── CLAUDE.md              # This file
└── scripts/
    ├── common.sh          # Shared library (argument parsing, helpers)
    ├── build.sh           # Build container image
    ├── run.sh             # Create and start a new container
    ├── exec.sh            # Access container shell
    ├── stop.sh            # Stop a running container (preserves state)
    ├── start.sh           # Start a stopped container
    ├── rm.sh              # Remove a container
    ├── rmi.sh             # Remove an image
    ├── list.sh            # List all claude-sandbox containers
    └── nuke.sh            # Targeted cleanup of claude-sandbox resources
```

## Multi-Container Support

The scripts support running multiple containers simultaneously with named instances.

### Naming Convention

**Container names:**
- With `--name foo`: `claude-sandbox-foo` (prod) or `claude-sandbox-test-foo` (test)
- Without `--name`: `claude-sandbox-default` or `claude-sandbox-test-default`

**Images:** `claude-sandbox` (prod) and `claude-sandbox-test` (test)

### Common Flags

All scripts support these flags (in any order):
- `--test` - Use test image/containers instead of production
- `--name <name>` - Specify instance name (default: `default`)
- `--force` - Force operation (where applicable)

### Script Usage

**build.sh** - Build container image
```bash
./scripts/build.sh [--test] [--nosudo]
# --nosudo: Disable sudo access for claude user (more restrictive)
```

**run.sh** - Create and start a new container
```bash
./scripts/run.sh [--test] [--name <name>] [/path/to/folder]
# Arguments can be in any order
# Default folder: current directory
# Default name: default
```

**exec.sh** - Access container shell
```bash
./scripts/exec.sh [--test] [--name <name>]
# If no --name and only one container running: auto-detects
# If multiple running: errors and lists them
```

**stop.sh** - Stop a container (preserves filesystem for restart)
```bash
./scripts/stop.sh [--test] [--name <name>]
```

**start.sh** - Restart a stopped container
```bash
./scripts/start.sh [--test] [--name <name>]
```

**rm.sh** - Remove a container
```bash
./scripts/rm.sh [--test] [--name <name>] [--force]
# --force: stop and remove even if running
```

**rmi.sh** - Remove an image
```bash
./scripts/rmi.sh [--test] [--force]
# Warns if containers still exist
```

**list.sh** - List all claude-sandbox containers
```bash
./scripts/list.sh
# Shows: container name, status, shared folder path
```

**nuke.sh** - Targeted cleanup (replaces old clean.sh)
```bash
./scripts/nuke.sh [--test] [--force]
# --test: ONLY removes test containers and test image (safe while in prod)
# Without --test: removes ALL claude-sandbox containers and both images
# --force: skip confirmation prompt
```

### Example: Multiple Projects

```bash
# Build image
./scripts/build.sh

# Run containers for different projects
./scripts/run.sh --name webapp ~/projects/webapp
./scripts/run.sh --name api ~/projects/api

# List running containers
./scripts/list.sh

# Access specific container
./scripts/exec.sh --name webapp

# Stop one, keep the other
./scripts/stop.sh --name api

# Later, restart it
./scripts/start.sh --name api

# Remove when done
./scripts/rm.sh --name webapp
./scripts/rm.sh --name api
```

### Testing Safely

When running inside a production container, always use `--test` flag:
```bash
./scripts/build.sh --test
./scripts/run.sh --test --name mytest /tmp/test
./scripts/exec.sh --test --name mytest
./scripts/nuke.sh --test --force  # Safe: only removes test resources
```

**WARNING:** Never run `./scripts/nuke.sh` (without `--test`) while inside a production container!

## Development Notes

### UID Mapping
- Container user `claude` should be UID 1000
- Host user should also be UID 1000 for seamless file permissions
- Use `--userns=keep-id` flag with `podman run`

### Shared Folder Mounting
- Mount point: `/workspace` inside container
- Use `:Z` suffix for SELinux compatibility (auto-relabeling)
- Files created in container appear with host user ownership

### Claude Installation
- **Critical**: Install Claude Code as the non-root user, not as root
- Installation typically goes to `~/.local/bin/claude`
- Auto-updates will only work if installed as regular user
- First run requires authentication: `claude auth login`

### Container Lifecycle
- Container runs `sleep infinity` to stay alive
- Access via `./scripts/exec.sh` (or `podman exec`)
- Stop with: `./scripts/stop.sh` (preserves container for restart)
- Start again with: `./scripts/start.sh`
- Remove with: `./scripts/rm.sh`
- List all: `./scripts/list.sh`
- Logs via: `podman logs <container-name>`

## Differences from Previous Implementation

This simplified approach:
- **Removes**: Tinyproxy, iptables firewall, network filtering, seccomp profiles
- **Relies on**: Claude's built-in sandbox mode (bubblewrap) for process isolation
- **Simpler**: No host-side proxy or firewall setup required
- **Trusts**: Claude Code's sandbox implementation for security

## Testing the Setup

After creating the scripts, test:
1. Build image: `./scripts/build.sh`
2. Start container: `./scripts/run.sh --name test /path/to/test/project`
3. Verify container running: `./scripts/list.sh`
4. Access container: `./scripts/exec.sh --name test`
5. Inside container:
   - Check user: `whoami` (should be `claude`)
   - Check sudo: `sudo -v` (should not require password)
   - Check bubblewrap: `which bwrap`
   - Check Claude: `which claude`
   - Test Claude: `claude --version`
   - Navigate to workspace: `cd /workspace`
   - Verify file access: `ls -la`
6. Test lifecycle:
   - Stop: `./scripts/stop.sh --name test`
   - Start: `./scripts/start.sh --name test`
   - Remove: `./scripts/rm.sh --name test`
