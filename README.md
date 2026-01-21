# Claude Code Sandbox Container

A rootless Podman container environment for running Claude Code CLI in a sandboxed environment with network restrictions and auto-approval for bash commands.

**Use at your own risk.** This is an experimental setup for running Claude Code in an isolated environment.

## Overview

This project creates a rootless Podman container running Ubuntu with:
- **Claude Code CLI** with auto-approval for bash commands
- **Network restrictions** via tinyproxy on the host (only allows Claude API + essential package registries)
- **Direct file access** - edit files on host with VSCode, changes immediately visible in container
- **Shared folder** with proper UID mapping for seamless file permissions
- **Security isolation** - tinyproxy runs on the host, preventing tampering from within the container
- **Rootless Podman** - runs without sudo privileges for better security

## Architecture

```
Host Machine
├── Tinyproxy (runs on host - port 8888)
│   ├── Restrictive mode: Only whitelisted domains
│   └── Permissive mode: All domains (for OS updates)
├── Shared folder: /your/projects (mounted with :Z for SELinux)
└── Rootless Podman container: claude-sandbox
    ├── Ubuntu base (no SSH server)
    ├── Claude Code CLI
    ├── Auto-approval enabled for bash commands
    ├── Network: Uses host's tinyproxy
    ├── Mount: /workspace → host's shared folder
    └── Access: podman exec (direct shell access)
```

**Security Note**:
- Tinyproxy runs on the HOST, not in the container. This prevents Claude from disabling or reconfiguring the network filter, even if compromised.
- Rootless Podman with `--userns=keep-id` ensures your host UID matches the container UID for seamless file permissions.
- No SSH server reduces attack surface and complexity.

## Prerequisites

- **Linux host** with Podman installed (rootless mode supported)
- **Podman**: Container runtime (lighter than Docker)
- **Tinyproxy**: HTTP proxy for network filtering
- **Claude Code subscription** or API key for authentication

### Install Podman

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install podman
```

**Fedora:**
```bash
sudo dnf install podman
```

**RHEL/CentOS:**
```bash
sudo yum install podman
```

## Quick Start

### 1. Host Setup (Run Once)

Install and configure tinyproxy on the host:

```bash
sudo ./scripts/host-setup.sh
```

This installs tinyproxy with a restrictive configuration that only allows:
- Claude API (api.anthropic.com)
- NPM registries (registry.npmjs.org, registry.yarnpkg.com)
- Python package index (pypi.org, files.pythonhosted.org)
- Git repositories (github.com, gitlab.com)
- Ubuntu package repositories

### 2. Build Container

Build the container image:

```bash
./scripts/build.sh
```

### 3. Run Container

Start the container with a shared folder:

```bash
./scripts/run.sh /path/to/your/projects
```

### 4. Access Container

Connect to the container using `podman exec`:

```bash
./scripts/exec.sh
```

Or manually:
```bash
podman exec -it claude-sandbox /bin/bash
```

### 5. Use Claude Code

Inside the container:

```bash
# Navigate to your project in the shared workspace
cd /workspace/your-project

# Authenticate on first use (subscription-based)
claude auth login

# Start Claude Code (will resume previous session)
claude --resume

# Or start a new session
claude
```

**Edit Files**: You can edit files directly on your host using VSCode or any editor. Changes are immediately visible in the container thanks to the shared mount and UID mapping.

**Auto-Approval**: Bash commands execute without confirmation prompts. To re-enable confirmations during a session, press `Shift+Tab`.

## Usage

### Starting and Stopping the Container

**Start container:**
```bash
./scripts/run.sh /path/to/your/projects
```

**Connect to running container:**
```bash
./scripts/exec.sh
```

**Stop container:**
```bash
./scripts/stop-container.sh
# or manually:
podman stop claude-sandbox
```

**Remove container:**
```bash
podman rm claude-sandbox
```

**View container logs:**
```bash
podman logs claude-sandbox
```

**List containers:**
```bash
./scripts/list-containers.sh
```

### Updating Container OS

To update packages inside the container (requires temporarily allowing all network access):

```bash
sudo ./scripts/update-container-os.sh
```

This script:
1. Switches tinyproxy to permissive mode (allows all domains)
2. Runs `apt update && apt upgrade` inside the container
3. Switches tinyproxy back to restrictive mode

**Note**: Updates are lost when the container is removed. To make permanent updates, rebuild the container image.

### Manual Proxy Mode Switching

If you need to manually toggle the proxy mode:

**Switch to permissive mode** (allows all domains):
```bash
sudo ./scripts/toggle-proxy.sh permissive
```

**Switch back to restrictive mode**:
```bash
sudo ./scripts/toggle-proxy.sh restrictive
```

**Important**: Always switch back to restrictive mode after updates.

## Configuration

### Claude Code Auto-Approval

Auto-approval for bash commands is enabled via a wrapper script that automatically adds the `--dangerously-skip-permissions` flag to all `claude` commands.

**How it works:**
- The `claude` command in the container is a wrapper script at `/usr/bin/claude`
- It automatically runs Claude Code with `--dangerously-skip-permissions`
- This bypasses all permission prompts for bash commands, file edits, and writes

**Re-enabling confirmations:**
- Inside a Claude Code session, press `Shift+Tab` to toggle permissions back on
- You can also run the original command directly: `/usr/bin/claude-original` (without auto-approval)

**Configuration file** (`config/claude-settings.json`):
The settings file includes auto-approval configuration and telemetry disabled:
```json
{
  "allowedPrompts": [
    {
      "tool": "Bash",
      "prompt": "*"
    }
  ],
  "autoApprove": {
    "bash": true,
    "edit": true,
    "write": true
  },
  "telemetry": {
    "enabled": false
  }
}
```

**Security note:** Only use auto-approval with trusted workspaces, as Claude can execute arbitrary commands without confirmation.

### Network Whitelist

The restrictive tinyproxy configuration (`host/tinyproxy.conf`) allows:

**Claude API:**
- api.anthropic.com

**Package Registries:**
- registry.npmjs.org, registry.yarnpkg.com (NPM)
- pypi.org, files.pythonhosted.org (Python)

**Git Repositories:**
- github.com, gitlab.com
- githubusercontent.com (raw content)

**CDNs:**
- cdn.jsdelivr.net, unpkg.com

**Ubuntu Repositories:**
- archive.ubuntu.com, security.ubuntu.com

To add more domains, edit `host/filter` and add regex patterns.

### Shared Folder

The shared folder is mounted at `/workspace` inside the container with the `:Z` flag for SELinux compatibility. With `--userns=keep-id`, your host UID (typically 1000) maps directly to the container's `claude` user (also UID 1000), ensuring perfect file permission alignment.

**File Permissions**: Files created in the container appear as owned by your host user, and vice versa. This means you can edit files on the host with any editor (VSCode, vim, etc.) and changes are immediately visible in the container.

**Security warning**: Claude can read, modify, and delete any files in the shared folder. Only mount trusted directories.

## Security Considerations

### Defense in Depth

1. **Network Isolation**:
   - Tinyproxy runs on HOST, not in container
   - Container cannot disable or reconfigure the proxy
   - Whitelist-based approach: only specified domains are accessible
   - Even if Claude is compromised, network filtering remains intact

2. **Container Isolation**:
   - Rootless Podman provides namespace isolation without requiring root privileges
   - Non-root user inside container (UID 1000)
   - Limited capabilities
   - No SSH server reduces attack surface

3. **Shared Folder Risk**:
   - Claude has read-write access to the shared folder
   - Can read, modify, or delete files
   - **Do not mount sensitive system directories**
   - Only mount trusted project directories
   - UID mapping ensures files have correct ownership

4. **Auto-Approval Risk**:
   - Claude can execute arbitrary bash commands without confirmation
   - Commands are limited by container isolation and network restrictions
   - Commands can affect container state and shared folder contents
   - **Only use with trusted workspaces and non-sensitive data**

5. **Proxy Security**:
   - Tinyproxy only accepts connections from localhost and container networks
   - Do not expose tinyproxy to public networks
   - Regularly review allowed domain list

### Threat Model

This setup protects against:
- ✅ Unintended network access by Claude (e.g., data exfiltration)
- ✅ Claude disabling network restrictions (proxy runs on host)
- ✅ Claude affecting host system directly (container isolation)

This setup does NOT protect against:
- ❌ Malicious code execution in the shared folder (Claude has full access)
- ❌ Prompt injection attacks that trick Claude into destructive actions
- ❌ Vulnerabilities in Claude Code CLI itself

**Recommendation**: Only use this container with projects and data you trust, and regularly review Claude's actions.

## Troubleshooting

### Container fails to start

**Check logs:**
```bash
podman logs claude-sandbox
```

**Common issues:**
- Tinyproxy not running on host: `sudo systemctl status tinyproxy`
- Shared folder doesn't exist: Ensure the path is correct
- SELinux issues: The `:Z` flag should handle relabeling automatically

### Cannot access container

**Verify container is running:**
```bash
podman ps | grep claude-sandbox
```

**Access manually:**
```bash
podman exec -it claude-sandbox /bin/bash
```

**Check container logs:**
```bash
podman logs claude-sandbox
```

### Claude cannot access the internet

**Verify proxy is running on host:**
```bash
sudo systemctl status tinyproxy
netstat -tuln | grep 8888
```

**Test proxy from inside container:**
```bash
# Access container
./scripts/exec.sh

# Check environment variables
echo $HTTP_PROXY

# Test connection to Claude API
curl -v --proxy $HTTP_PROXY https://api.anthropic.com

# Test blocked domain (should fail)
curl -v --proxy $HTTP_PROXY https://example.com
```

### Proxy blocks required domains

Edit `host/filter` to add more allowed domains using regex:

```bash
sudo nano /etc/tinyproxy/filter
# Add regex patterns, e.g.:
# ^example\.com$
sudo systemctl restart tinyproxy
```

### Container OS update fails

**Ensure permissive mode is active:**
```bash
sudo ./scripts/toggle-proxy.sh permissive
```

**Manually update inside container:**
```bash
podman exec -it claude-sandbox apt-get update
podman exec -it claude-sandbox apt-get upgrade -y
```

**Switch back to restrictive:**
```bash
sudo ./scripts/toggle-proxy.sh restrictive
```

## File Structure

```
claude_vm/
├── Containerfile              # Container image definition
├── README.md                  # This file
├── CLAUDE.md                  # Project instructions
├── config/
│   └── claude-settings.json   # Claude Code config (auto-approve)
├── host/
│   ├── tinyproxy.conf         # Restrictive proxy config
│   ├── tinyproxy-permissive.conf  # Permissive proxy config
│   ├── filter                 # Restrictive domain whitelist
│   └── filter-permissive      # Permissive domain filter
├── scripts/
│   ├── host-setup.sh          # Install tinyproxy on host
│   ├── toggle-proxy.sh        # Switch proxy modes
│   ├── build.sh               # Build container image
│   ├── run.sh                 # Run container with shared folder
│   ├── exec.sh                # Access container shell
│   ├── start.sh               # Start container and connect
│   ├── stop-container.sh      # Stop container
│   ├── list-containers.sh     # List containers
│   └── update-container-os.sh # Update container OS packages
└── setup/
    └── entrypoint.sh          # Container startup script
```

## Authentication

Claude Code supports two authentication methods:

1. **Subscription-based** (recommended): Authenticate interactively inside the container:
   ```bash
   claude auth login
   ```

2. **API Key**: Set the environment variable before running the container:
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ./scripts/run.sh /path/to/projects
   ```

## Advanced Usage

### Customizing the Whitelist

Edit `host/filter` to add domains using POSIX extended regex:

```bash
# Example: Allow access to npmjs.com
^npmjs\.com$

# Example: Allow all subdomains of example.com
^.*\.example\.com$
```

After editing, restart tinyproxy:
```bash
sudo systemctl restart tinyproxy
```

### Running Multiple Containers

To run multiple isolated instances:
1. Modify `CONTAINER_NAME` in `scripts/run.sh`
2. Use different shared folders
3. Each container can be accessed with `podman exec -it <container-name> /bin/bash`

### Persistent Data

Container state (installed packages, config changes) is lost when the container is removed. To persist data:

1. **Use the shared folder**: Store everything in `/workspace`
2. **Commit changes to image**: After making changes, create a new image:
   ```bash
   podman commit claude-sandbox claude-sandbox:custom
   ```
3. **Use volumes**: Mount additional volumes for persistent data

## Future Enhancements

Potential improvements (not currently implemented):

- GPU passthrough for AI workloads (requires VM instead of container)
- Multiple container profiles for different isolation levels
- Web interface for container management
- Automated backups of Claude conversation history
- Fine-grained command filtering (beyond network restrictions)

## Contributing

This is an experimental project. Feel free to fork and customize for your needs.

## License

Use at your own risk. No warranty provided.

## Acknowledgments

- Claude Code by Anthropic
- Podman container runtime
- Tinyproxy for HTTP filtering
