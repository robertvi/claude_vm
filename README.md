# Claude Code Sandbox Container

A Podman container environment for running Claude Code CLI in a sandboxed environment with network restrictions and auto-approval for bash commands.

**Use at your own risk.** This is an experimental setup for running Claude Code in an isolated environment.

## Overview

This project creates a Podman container running Ubuntu with:
- **Claude Code CLI** with auto-approval for bash commands
- **Network restrictions** via tinyproxy on the host (only allows Claude API + essential package registries)
- **SSH access** for connecting to the container
- **Shared folder** for accessing projects from the host
- **Security isolation** - tinyproxy runs on the host, preventing tampering from within the container

## Architecture

```
Host Machine
├── Tinyproxy (runs on host - port 8888)
│   ├── Restrictive mode: Only whitelisted domains
│   └── Permissive mode: All domains (for OS updates)
├── Shared folder: /your/projects (mounted read-write)
└── Podman container: claude-sandbox
    ├── Ubuntu base + SSH server
    ├── Claude Code CLI
    ├── Auto-approval enabled for bash commands
    ├── Network: Uses host's tinyproxy
    └── Mount: /workspace → host's shared folder
```

**Security Note**: Tinyproxy runs on the HOST, not in the container. This prevents Claude from disabling or reconfiguring the network filter, even if compromised.

## Prerequisites

- **Linux host** with Podman installed
- **Podman**: Container runtime (lighter than Docker)
- **Tinyproxy**: HTTP proxy for network filtering
- **Anthropic API key**: For Claude Code

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

You'll be prompted for your Anthropic API key if not set in the environment.

### 4. Connect via SSH

Connect to the container:

```bash
./scripts/connect.sh
```

Default credentials:
- Username: `claude`
- Password: `claude`

### 5. Use Claude Code

Inside the container:

```bash
# Navigate to your project in the shared workspace
cd /workspace/your-project

# Start Claude Code (will resume previous session)
claude --resume

# Or start a new session
claude
```

## Usage

### Starting and Stopping the Container

**Start container:**
```bash
./scripts/run.sh /path/to/your/projects
```

**Connect to running container:**
```bash
./scripts/connect.sh
```

**Stop container:**
```bash
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

### Claude Code Settings

Auto-approval for bash commands is configured in `config/claude-settings.json`:

```json
{
  "hooks": {
    "bash": {
      "autoApprove": true
    }
  },
  "autoApprove": {
    "bash": true
  }
}
```

This means Claude can execute bash commands without prompting for confirmation. Only use with trusted workspaces.

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

### SSH Configuration

Default SSH settings (`config/sshd_config`):
- Port: 22 (mapped to 2222 on host)
- Root login: Disabled
- Password authentication: Enabled
- Only `claude` user can login

**For production**: Consider using SSH key-based authentication instead of passwords.

### Shared Folder

The shared folder is mounted at `/workspace` inside the container with read-write access. The `claude` user has full access to files in this folder.

**Security warning**: Claude can read, modify, and delete any files in the shared folder. Only mount trusted directories.

## Security Considerations

### Defense in Depth

1. **Network Isolation**:
   - Tinyproxy runs on HOST, not in container
   - Container cannot disable or reconfigure the proxy
   - Whitelist-based approach: only specified domains are accessible
   - Even if Claude is compromised, network filtering remains intact

2. **Container Isolation**:
   - Podman provides namespace isolation from host
   - Non-root user inside container
   - Limited capabilities

3. **Shared Folder Risk**:
   - Claude has read-write access to the shared folder
   - Can read, modify, or delete files
   - **Do not mount sensitive system directories**
   - Only mount trusted project directories

4. **Auto-Approval Risk**:
   - Claude can execute arbitrary bash commands without confirmation
   - Commands are limited by container isolation and network restrictions
   - Commands can affect container state and shared folder contents
   - **Only use with trusted workspaces and non-sensitive data**

5. **SSH Security**:
   - Default password is `claude` (change in production)
   - Consider using SSH key-based authentication
   - SSH is only exposed on localhost port 2222 by default

6. **Proxy Security**:
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
- Port 2222 already in use: Stop other services or change port in `scripts/run.sh`
- Shared folder doesn't exist: Ensure the path is correct

### Cannot connect via SSH

**Verify container is running:**
```bash
podman ps | grep claude-sandbox
```

**Test SSH manually:**
```bash
ssh -p 2222 claude@localhost
```

**Check if port is listening:**
```bash
ss -tuln | grep 2222
```

### Claude cannot access the internet

**Verify proxy is running on host:**
```bash
sudo systemctl status tinyproxy
netstat -tuln | grep 8888
```

**Test proxy from inside container:**
```bash
# SSH into container
./scripts/connect.sh

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
│   ├── claude-settings.json   # Claude Code config (auto-approve)
│   └── sshd_config            # SSH server config
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
│   ├── connect.sh             # SSH into container
│   └── update-container-os.sh # Update container OS packages
└── setup/
    └── entrypoint.sh          # Container startup script
```

## Environment Variables

**ANTHROPIC_API_KEY**: Your Claude API key (required for Claude Code)

Set it before running the container:
```bash
export ANTHROPIC_API_KEY="your-key-here"
./scripts/run.sh /path/to/projects
```

Or the script will prompt you for it.

## Advanced Usage

### Using SSH Keys Instead of Password

1. Generate SSH key pair (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/claude_sandbox
   ```

2. Add your public key to the container (after starting it):
   ```bash
   cat ~/.ssh/claude_sandbox.pub | ssh -p 2222 claude@localhost 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
   ```

3. Connect with key:
   ```bash
   ssh -p 2222 -i ~/.ssh/claude_sandbox claude@localhost
   ```

4. Disable password authentication by editing `config/sshd_config`:
   ```
   PasswordAuthentication no
   ```
   Then rebuild the container.

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

To run multiple isolated instances, modify `scripts/run.sh`:
- Change `CONTAINER_NAME`
- Change SSH port mapping (e.g., `-p 2223:22`)
- Use different shared folders

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
