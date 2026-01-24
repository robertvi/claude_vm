# Claude Code Sandbox Container

A rootless Podman container setup for running [Claude Code CLI](https://claude.com/product/claude-code) in a secure, isolated Ubuntu environment with built-in sandbox mode support.

## Features

- **Rootless Podman**: No sudo required for container operations
- **Ubuntu 24.04 LTS**: Latest long-term support release
- **Sandbox Mode**: Built-in support for Claude Code's `/sandbox` mode using bubblewrap
- **Auto-updates**: Claude Code installed as non-root user to enable automatic updates
- **Passwordless sudo**: Convenient sudo access inside the container
- **Dynamic UID/GID mapping**: Automatically matches your host user for seamless file permissions
- **Shared folder mounting**: Mount any directory with proper SELinux compatibility
- **Permission skip alias**: Pre-configured alias for `--allow-dangerously-skip-permissions` flag

## Prerequisites

### Host System Requirements

- **Podman** (rootless mode configured)
- Linux system (tested on Ubuntu/Fedora/RHEL-based distributions)
- User UID/GID (typically 1000 on most systems)

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

**Arch Linux:**
```bash
sudo pacman -S podman
```

## Quick Start

### 1. Build the Container Image

Build the image with your user's UID/GID automatically detected:

```bash
./scripts/build.sh
```

This will:
- Download Ubuntu 24.04 base image
- Install required dependencies (bubblewrap, socat, git, etc.)
- Create a `claude` user matching your UID/GID
- Install Claude Code CLI as the `claude` user
- Configure passwordless sudo
- Set up the `claude` command alias with `--allow-dangerously-skip-permissions`

**Build time:** ~5-10 minutes (depending on network speed)

### 2. Start the Container

Start the container with a shared folder:

```bash
# Use current directory (default)
./scripts/run.sh

# Or specify a custom directory
./scripts/run.sh /path/to/your/project
```

This creates and starts a container named `claude-sandbox` with:
- Hostname: `claude-sandbox`
- Shared folder mounted at `/workspace` inside the container
- SELinux compatibility (`:Z` flag)
- UID/GID mapping for seamless file permissions

### 3. Access the Container

Open an interactive shell inside the running container:

```bash
./scripts/exec.sh
```

You'll be logged in as the `claude` user at `/workspace` (your shared folder).

### 4. Use Claude Code

Inside the container:

```bash
# The alias automatically adds --allow-dangerously-skip-permissions
claude

# Activate sandbox mode (requires bubblewrap and socat)
/sandbox

# Check version
claude --version

# Authenticate (first time only)
claude auth login

# Run Claude Code on your project
claude "help me refactor this code"
```

## Scripts Overview

### `./scripts/build.sh`

Builds the container image with your current user's UID/GID.

- **Output:** Container image tagged as `claude-sandbox`
- **Log file:** `/tmp/claude-sandbox-build.log`
- **Build args:** Automatically passes `USER_UID` and `USER_GID`
- **Cache:** Uses `--no-cache` to ensure UID/GID are correctly applied

### `./scripts/run.sh [path]`

Starts the container with optional shared folder path.

- **Arguments:**
  - `path` (optional): Directory to share (defaults to current directory)
- **Container name:** `claude-sandbox`
- **Hostname:** `claude-sandbox`
- **Mount point:** `/workspace` inside container
- **Log file:** `/tmp/claude-sandbox-run.log`
- **Note:** Will fail if container already exists (remove with `podman rm -f claude-sandbox` or use `clean.sh` - ⚠️ WARNING: clean.sh removes ALL containers/images)

### `./scripts/exec.sh`

Opens an interactive bash shell inside the running container.

- **User:** `claude`
- **Working directory:** `/workspace`
- **Log file:** `/tmp/claude-sandbox-exec.log`
- **Note:** Requires container to be running

### `./scripts/clean.sh`

**⚠️ CRITICAL WARNING:** This script stops ALL Podman containers and removes ALL Podman images on your entire system, not just Claude-related ones. Use with extreme caution!

- **Actions:**
  - Stops all running containers
  - Removes all containers
  - Removes all images
- **Log file:** `/tmp/claude-sandbox-clean.log`
- **Use with caution:** Only run if you want to clean your entire Podman environment

## File Permissions

The container uses `--userns=keep-id` with dynamic UID/GID mapping to ensure seamless file permissions:

| Location | User | Group | UID | GID |
|----------|------|-------|-----|-----|
| Inside container | `claude` | `claude` | Your UID | Your GID |
| On host | Your username | Your group | Your UID | Your GID |

Files created inside the container will appear on the host with your user ownership, and vice versa.

## Architecture

```
Host Machine (UID 1000, GID 1000)
└── Rootless Podman Container
    ├── Ubuntu 24.04 base
    ├── bubblewrap + socat (for Claude sandbox mode)
    ├── Claude Code CLI (installed as user, not root)
    ├── claude user (UID 1000, GID 1000 - matches host)
    ├── Passwordless sudo configured
    ├── /workspace → host shared folder (:Z for SELinux)
    └── UID mapping via --userns=keep-id:uid=1000,gid=1000
```

## Troubleshooting

### Container Already Exists

```
Error: Container 'claude-sandbox' already exists.
```

**Solution:** Remove the existing container first:
```bash
podman rm -f claude-sandbox
# Or use clean.sh (⚠️ WARNING: Removes ALL Podman containers/images on your system!)
./scripts/clean.sh
```

### Claude Command Not Found

If `claude` command is not found inside the container:

1. Check if Claude Code installed correctly:
   ```bash
   ls -la ~/.local/bin/claude
   ```

2. Verify PATH includes Claude Code:
   ```bash
   echo $PATH | grep ".local/bin"
   ```

3. Try rebuilding without cache (⚠️ WARNING: clean.sh removes ALL Podman containers/images):
   ```bash
   ./scripts/clean.sh
   ./scripts/build.sh
   ```

### File Permission Issues

If files have wrong ownership:

1. Verify your host UID/GID:
   ```bash
   id
   ```

2. Check container user UID/GID:
   ```bash
   podman exec claude-sandbox id claude
   ```

3. Rebuild if they don't match (⚠️ WARNING: clean.sh removes ALL Podman containers/images):
   ```bash
   ./scripts/clean.sh
   ./scripts/build.sh
   ```

### Sandbox Mode Not Working

```
Error: Sandbox requires socat and bubblewrap.
```

**Solution:** The packages are installed during build. If missing:
```bash
# Inside container
sudo apt-get update
sudo apt-get install bubblewrap socat
```

### SELinux Permission Denied

If you get permission denied errors on SELinux-enabled systems (Fedora, RHEL):

- Ensure you're using the `:Z` flag (already included in `run.sh`)
- Check SELinux status: `sestatus`
- Temporarily test with SELinux permissive: `sudo setenforce 0` (not recommended for production)

## Container Lifecycle

### Stop the Container
```bash
podman stop claude-sandbox
```

### Restart the Container
```bash
podman start claude-sandbox
```

### Remove the Container
```bash
podman rm -f claude-sandbox
```

### View Container Logs
```bash
podman logs claude-sandbox
```

### Check Container Status
```bash
podman ps -a | grep claude-sandbox
```

## Advanced Usage

### Custom Container Name

Edit `scripts/run.sh` and change:
```bash
CONTAINER_NAME="your-custom-name"
```

### Mount Multiple Folders

Edit `scripts/run.sh` and add additional `-v` flags:
```bash
-v "/path/to/folder1:/folder1:Z" \
-v "/path/to/folder2:/folder2:Z" \
```

### Run with Different User

The build automatically uses your current UID/GID. To use different values:

```bash
# Edit build.sh and replace id commands:
USER_UID=1001
USER_GID=1001
```

## Security Considerations

- **Sandbox mode:** Uses bubblewrap for process isolation
- **Rootless containers:** Run without root privileges on the host
- **Passwordless sudo:** Enabled inside container for convenience (container is already isolated)
- **Network access:** Container has full network access (no filtering by default)
- **Shared folders:** Only explicitly mounted folders are accessible

## Contributing

Contributions welcome! Please ensure:
- Scripts remain POSIX-compliant where possible
- Documentation is updated for any new features
- UID/GID mapping works for different users

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Related Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Podman Documentation](https://docs.podman.io/)
- [Bubblewrap GitHub](https://github.com/containers/bubblewrap)

## Credits

Created for running Claude Code CLI in an isolated, reproducible environment with proper sandbox support.
