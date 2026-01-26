# Claude Code Sandbox Container

A rootless Podman container setup for running [Claude Code CLI](https://claude.com/product/claude-code) in a secure, isolated Ubuntu environment with built-in sandbox mode support.

## Features

- **Rootless Podman**: No sudo required for container operations
- **Ubuntu 24.04 LTS**: Latest long-term support release
- **Multi-container support**: Run multiple named containers simultaneously
- **Sandbox Mode**: Built-in support for Claude Code's `/sandbox` mode using bubblewrap
- **Auto-updates**: Claude Code installed as non-root user to enable automatic updates
- **Passwordless sudo**: Convenient sudo access inside the container
- **Dynamic UID/GID mapping**: Automatically matches your host user for seamless file permissions
- **Shared folder mounting**: Mount any directory with proper SELinux compatibility
- **Permission skip alias**: Pre-configured alias for `--allow-dangerously-skip-permissions` flag
- **Test mode**: Separate test containers/images for safe development

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
# Use current directory with default name
./scripts/run.sh

# Specify a custom directory
./scripts/run.sh /path/to/your/project

# Use a named instance for multiple containers
./scripts/run.sh --name myproject /path/to/your/project
```

This creates and starts a container with:
- Container name: `claude-sandbox-default` (or `claude-sandbox-<name>` with `--name`)
- Shared folder mounted at `/workspace` inside the container
- SELinux compatibility (`:Z` flag)
- UID/GID mapping for seamless file permissions

### 3. Access the Container

Open an interactive shell inside the running container:

```bash
# Auto-detect (works if only one container running)
./scripts/exec.sh

# Or specify by name
./scripts/exec.sh --name myproject
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

All scripts support common flags (in any order):
- `--test` - Use test image/containers instead of production
- `--name <name>` - Specify instance name (default: `default`)
- `--force` - Force operation where applicable
- `--nosudo` - (build.sh only) Disable sudo access for claude user

### `./scripts/build.sh [--test] [--nosudo]`

Builds the container image with your current user's UID/GID.

- **Output:** Container image tagged as `claude-sandbox` (or `claude-sandbox-test` with `--test`)
- **Log file:** `/tmp/claude-sandbox-build.log`
- **Build args:** Automatically passes `USER_UID` and `USER_GID`
- **Cache:** Uses `--no-cache` to ensure UID/GID are correctly applied
- **--nosudo:** Disable sudo access for claude user (more restrictive container)

### `./scripts/run.sh [--test] [--name <name>] [path]`

Creates and starts a new container with optional shared folder path.

- **Arguments:**
  - `--name <name>` (optional): Instance name (default: `default`)
  - `path` (optional): Directory to share (defaults to current directory)
- **Container name:** `claude-sandbox-<name>` (or `claude-sandbox-test-<name>` with `--test`)
- **Mount point:** `/workspace` inside container
- **Note:** Will fail if container already exists (use `./scripts/rm.sh` first)

### `./scripts/exec.sh [--test] [--name <name>]`

Opens an interactive bash shell inside the running container.

- **Auto-detect:** If only one container is running and no `--name` specified, auto-selects it
- **Multiple containers:** Lists running containers and asks you to specify `--name`
- **User:** `claude`
- **Working directory:** `/workspace`

### `./scripts/stop.sh [--test] [--name <name>]`

Stops a running container (preserves container filesystem for restart).

- **Default name:** `default`
- **Note:** Use `start.sh` to restart, or `rm.sh` to remove

### `./scripts/start.sh [--test] [--name <name>]`

Restarts a stopped container.

- **Default name:** `default`
- **Note:** Container must exist (created with `run.sh`)

### `./scripts/rm.sh [--test] [--name <name>] [--force]`

Removes a container.

- **Default name:** `default`
- **--force:** Stop and remove even if running

### `./scripts/rmi.sh [--test] [--force]`

Removes an image.

- **Warns:** If containers using the image still exist
- **--force:** Remove despite existing containers

### `./scripts/list.sh`

Lists all claude-sandbox containers with status and shared folder path.

- **Shows:** Container name, running/stopped status, mounted folder

### `./scripts/nuke.sh [--test] [--force]`

Targeted cleanup of claude-sandbox resources only.

- **--test:** Only removes test containers and test image (safe while running in production container)
- **Without --test:** Removes ALL claude-sandbox containers and both images
- **--force:** Skip confirmation prompt

**Note:** Unlike the old `clean.sh`, this only affects claude-sandbox resources, not your entire Podman environment.

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
└── Rootless Podman
    ├── Image: claude-sandbox (prod) / claude-sandbox-test (test)
    └── Containers: claude-sandbox-<name> / claude-sandbox-test-<name>
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
Error: Container 'claude-sandbox-default' already exists.
```

**Solution:** Remove the existing container first:
```bash
./scripts/rm.sh
# Or force remove if running:
./scripts/rm.sh --force
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

3. Try rebuilding:
   ```bash
   ./scripts/rm.sh --force
   ./scripts/rmi.sh --force
   ./scripts/build.sh
   ./scripts/run.sh
   ```

### File Permission Issues

If files have wrong ownership:

1. Verify your host UID/GID:
   ```bash
   id
   ```

2. Check container user UID/GID:
   ```bash
   podman exec claude-sandbox-default id claude
   ```

3. Rebuild if they don't match:
   ```bash
   ./scripts/nuke.sh --force
   ./scripts/build.sh
   ./scripts/run.sh
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

### List All Containers
```bash
./scripts/list.sh
```

### Stop a Container
```bash
./scripts/stop.sh --name myproject
# Or for default container:
./scripts/stop.sh
```

### Restart a Stopped Container
```bash
./scripts/start.sh --name myproject
```

### Remove a Container
```bash
./scripts/rm.sh --name myproject
# Force remove (even if running):
./scripts/rm.sh --name myproject --force
```

### View Container Logs
```bash
podman logs claude-sandbox-myproject
```

### Clean Up All Claude Containers
```bash
# Remove all claude-sandbox containers and images (with confirmation):
./scripts/nuke.sh

# Remove only test resources:
./scripts/nuke.sh --test
```

## Advanced Usage

### Multiple Projects

Run separate containers for different projects:

```bash
# Start containers for different projects
./scripts/run.sh --name webapp ~/projects/webapp
./scripts/run.sh --name api ~/projects/api
./scripts/run.sh --name docs ~/projects/docs

# List all running containers
./scripts/list.sh

# Access specific container
./scripts/exec.sh --name webapp

# Stop one while keeping others running
./scripts/stop.sh --name api
```

### Test Mode

Use `--test` flag to work with separate test containers/images:

```bash
# Build test image
./scripts/build.sh --test

# Run test container
./scripts/run.sh --test --name experiment /tmp/test

# Clean up only test resources (safe while in production)
./scripts/nuke.sh --test --force
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
- **Passwordless sudo:** Enabled by default inside container for convenience (container is already isolated)
  - Use `./scripts/build.sh --nosudo` to disable sudo entirely for maximum restriction
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
