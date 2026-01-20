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
export ANTHROPIC_API_KEY="your-api-key-here"
./scripts/run.sh /path/to/your/projects
```

Replace `/path/to/your/projects` with the folder you want to share with the container.

### 5. Connect to Container

```bash
./scripts/connect.sh
```

**Default credentials:**
- Username: `claude`
- Password: `claude`

### 6. Use Claude Code

Inside the container:

```bash
cd /workspace/your-project
claude --resume
```

## Daily Usage

**Start container:**
```bash
./scripts/run.sh /path/to/your/projects
```

**Connect:**
```bash
./scripts/connect.sh
```

**Stop container:**
```bash
podman stop claude-sandbox
```

## Updating Container OS

When you need to update packages inside the container:

```bash
sudo ./scripts/update-container-os.sh
```

This temporarily allows all network access, updates the OS, then restores restrictions.

## Security Notes

- Tinyproxy runs on the HOST (not in container) - Claude cannot disable it
- Only whitelisted domains are accessible: Claude API, npm, PyPI, GitHub, Ubuntu repos
- Claude has auto-approval for bash commands - only use with trusted projects
- Shared folder has read-write access - Claude can modify files

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
└── Podman Container
    ├── SSH (port 2222 on host)
    ├── Claude Code CLI
    └── /workspace → Your shared folder
```

For complete documentation, see [README.md](README.md).
