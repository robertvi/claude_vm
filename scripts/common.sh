#!/bin/bash
# Common functions for claude-sandbox scripts

# Base names
BASE_NAME="claude-sandbox"
BASE_TEST_NAME="claude-sandbox-test"

# Output helpers
die() {
    echo "Error: $1" >&2
    exit 1
}

info() {
    echo "$1"
}

# Get image name based on test mode
# Usage: get_image_name <is_test>
get_image_name() {
    local is_test="$1"
    if [[ "$is_test" == "true" ]]; then
        echo "${BASE_TEST_NAME}"
    else
        echo "${BASE_NAME}"
    fi
}

# Build full container name
# Usage: build_container_name <is_test> <suffix>
build_container_name() {
    local is_test="$1"
    local suffix="${2:-default}"

    if [[ "$is_test" == "true" ]]; then
        echo "${BASE_TEST_NAME}-${suffix}"
    else
        echo "${BASE_NAME}-${suffix}"
    fi
}

# Check if container exists (running or stopped)
# Usage: container_exists <name>
container_exists() {
    local name="$1"
    podman ps -a --format "{{.Names}}" | grep -q "^${name}$"
}

# Check if container is running
# Usage: container_running <name>
container_running() {
    local name="$1"
    podman ps --format "{{.Names}}" | grep -q "^${name}$"
}

# Check if image exists
# Usage: image_exists <name>
image_exists() {
    local name="$1"
    podman image exists "$name" 2>/dev/null
}

# Parse common arguments: --test, --name <value>, --force, --nosudo
# Sets global variables: TEST_MODE, INSTANCE_NAME, FORCE_MODE, NOSUDO_MODE, REMAINING_ARGS
# Usage: parse_common_args "$@"
parse_common_args() {
    TEST_MODE=false
    INSTANCE_NAME=""
    FORCE_MODE=false
    NOSUDO_MODE=false
    REMAINING_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --test)
                TEST_MODE=true
                shift
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    die "--name requires a value"
                fi
                INSTANCE_NAME="$2"
                shift 2
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --nosudo)
                NOSUDO_MODE=true
                shift
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# List all claude-sandbox containers (returns names)
# Usage: list_sandbox_containers [test_only]
list_sandbox_containers() {
    local test_only="$1"
    if [[ "$test_only" == "true" ]]; then
        podman ps -a --format "{{.Names}}" | grep "^${BASE_TEST_NAME}-" || true
    else
        podman ps -a --format "{{.Names}}" | grep "^${BASE_NAME}" || true
    fi
}

# List running claude-sandbox containers (returns names)
# Usage: list_running_containers [test_only]
list_running_containers() {
    local test_only="$1"
    if [[ "$test_only" == "true" ]]; then
        podman ps --format "{{.Names}}" | grep "^${BASE_TEST_NAME}-" || true
    else
        podman ps --format "{{.Names}}" | grep "^${BASE_NAME}" || true
    fi
}

# Count running containers matching pattern
# Usage: count_running_containers [test_only]
count_running_containers() {
    local test_only="$1"
    list_running_containers "$test_only" | wc -l
}
