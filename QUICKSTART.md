# Quick Start Guide

This is a condensed getting-started guide. See README.md for full documentation.

## Installation Steps

### 1. Install Prerequisites

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install podman
```

### 2. Setup Host (One-Time)

Install and configure tinyproxy on your host machine:

```bash
sudo ./scripts/host-setup.sh
```

This installs tinyproxy with network restrictions that only allow Claude API and essential package registries.

### 3. Build Container

```bash
./scripts/build.sh
```

### 4. Run Container

```bash
./scripts/run.sh /path/to/your/projects
```

Replace `/path/to/your/projects` with the folder you want to share with the container.

### 5. Access Container

```bash
./scripts/exec.sh
```

Or manually:
```bash
podman exec -it claude-sandbox /bin/bash
```

### 6. Use Claude Code

Inside the container:

```bash
cd /workspace/your-project

# Authenticate on first use (subscription-based)
claude auth login

# Start Claude Code
claude --resume
```

**Edit Files**: You can edit files directly on your host with VSCode or any editor. Changes are immediately visible in the container.

**Auto-Approval**: Bash commands run without confirmation. Press `Shift+Tab` inside Claude Code to toggle permissions back on if needed.

## Daily Usage

**Start container:**
```bash
./scripts/run.sh /path/to/your/projects
```

**Access container:**
```bash
./scripts/exec.sh
```

**Stop container:**
```bash
./scripts/stop-container.sh
# or manually:
podman stop claude-sandbox
```

## Updating Container OS

When you need to update packages inside the container:

```bash
sudo ./scripts/update-container-os.sh
```

This temporarily allows all network access, updates the OS, then restores restrictions.

## Security Notes

- **Rootless Podman**: Container runs without root privileges for better security
- **Tinyproxy on HOST**: Runs outside container - Claude cannot disable it
- **Network whitelist**: Only Claude API, npm, PyPI, GitHub, Ubuntu repos accessible
- **Auto-approval**: Claude can execute bash commands without confirmation - only use with trusted projects
- **Shared folder**: Claude can read/write files - only mount trusted directories
- **No SSH**: Direct shell access via `podman exec` reduces attack surface

## Troubleshooting

**Container won't start:**
```bash
podman logs claude-sandbox
sudo systemctl status tinyproxy
```

**Cannot access internet from container:**
```bash
# Inside container:
echo $HTTP_PROXY
curl -v --proxy $HTTP_PROXY https://api.anthropic.com
```

**Need to allow more domains:**
```bash
sudo nano /etc/tinyproxy/filter
# Add regex patterns like: ^example\.com$
sudo systemctl restart tinyproxy
```

## Architecture

```
Host
├── Tinyproxy (port 8888) - Network filtering
└── Rootless Podman Container
    ├── Claude Code CLI
    ├── Access via: podman exec
    └── /workspace → Your shared folder (UID-mapped)
```

For complete documentation, see [README.md](README.md).
