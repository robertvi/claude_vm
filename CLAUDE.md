This repo creates a rootless Podman container to run Claude Code CLI in an isolated environment.
It provides CLI-only access with no graphical output.
GPU passthrough is a potential future enhancement.

## Implementation Status: ✅ Complete

**Key Features Implemented:**
- ✅ **Auto-approval**: Claude runs without bash command verification (uses `--dangerously-skip-permissions` flag via wrapper script)
- ✅ **Network filtering**: Tinyproxy on host limits connections to Claude API and essential package registries
- ✅ **OS updates**: Container OS can be updated by temporarily enabling permissive proxy mode
- ✅ **Access method**: Direct shell access via `podman exec` (no SSH for security and simplicity)
- ✅ **Shared folder**: Uses `--userns=keep-id` and `:Z` volume mount for proper UID mapping and SELinux compatibility
- ✅ **Rootless Podman**: Runs without sudo privileges for better security
- ✅ **File editing**: Edit files on host with any editor (VSCode, etc.), changes immediately visible in container

**Architecture:**
- Rootless Podman container (no SSH server)
- Tinyproxy runs on HOST (cannot be disabled by Claude)
- Wrapper script at `/usr/bin/claude` automatically adds `--dangerously-skip-permissions`
- UID 1000 mapping ensures file permissions work seamlessly between host and container
