create scripts to setup a podman rootless container, based on ubuntu, that runs claude code in sandbox mode (required bubblewrap) with one script to create the image, one to start it running defaulting to sharing the current working folder with option to specify an arbitrary folder and another to start an interactive exec session giving a terminal inside the container. inside the container claude should be installed as the limited user not as root to enable auto updates to function. have an option to configure password less sudo inside the container

# rootless podman container with claude code inside
Allows you to sift-tab into skipped permissions mode, allows activation of claude's /sandbox mode. Only mounts one requested shared folder, default to cwd.

Prerequisites on host:
```
podman
```

Usage:
```
#build image
./scripts/build.sh

#launch container with directory mount (defaults to current folder)
./scripts/run.sh [path/to/shared/folder]

#open an interactive shell session
./scripts/exec.sh

#nuke *all* podman containers and images on your system
./scripts/clean.sh
```
