#!/bin/bash
##
## Container Script for Claude Code Metadata Backup
## Backs up ~/.claude metadata to GitHub cc-backup repo
## Called by the host backup-claude.sh script
##
## Required environment variables (passed from host):
##   GITHUB_PAT  - Fine-grained GitHub PAT
##   GITHUB_USER - GitHub username
##

set -e

CLAUDE_DIR="$HOME/.claude"
BACKUP_REPO_DIR="/workspace/cc-backup"
REPO_NAME="cc-backup"
BRANCH_NAME="backup/$(date +%Y-%m-%d-%H%M%S)"

# Check required environment variables
if [ -z "$GITHUB_PAT" ]; then
    echo "ERROR: GITHUB_PAT not set"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo "ERROR: GITHUB_USER not set"
    exit 1
fi

# Check if ~/.claude exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "ERROR: Claude metadata directory not found: $CLAUDE_DIR"
    exit 1
fi

# Git URL with embedded token (never written to disk in plaintext config)
GIT_URL="https://oauth2:${GITHUB_PAT}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo "Backup branch: $BRANCH_NAME"
echo ""

# Clone or update the backup repository
if [ -d "$BACKUP_REPO_DIR" ]; then
    echo "Updating existing backup repository..."
    cd "$BACKUP_REPO_DIR"

    # Reset any local changes and update from remote
    git fetch origin
    git checkout main 2>/dev/null || git checkout master
    git reset --hard origin/$(git branch --show-current)
else
    echo "Cloning backup repository..."
    git clone "$GIT_URL" "$BACKUP_REPO_DIR"
    cd "$BACKUP_REPO_DIR"
fi

# Create new backup branch
echo "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Define items to backup (relative to ~/.claude)
BACKUP_ITEMS=(
    "projects"
    "file-history"
    "history.jsonl"
    "plans"
    "todos"
    "session-env"
    "shell-snapshots"
)

# Clear existing backup content (except .git)
echo "Clearing previous backup content..."
find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' -exec rm -rf {} +

# Copy backup items
echo "Copying backup items..."
for item in "${BACKUP_ITEMS[@]}"; do
    src="$CLAUDE_DIR/$item"
    if [ -e "$src" ]; then
        echo "  + $item"
        cp -r "$src" .
    else
        echo "  - $item (not found, skipping)"
    fi
done

# Create a manifest file with backup metadata
echo ""
echo "Creating backup manifest..."
cat > BACKUP_MANIFEST.md << EOF
# Claude Code Backup

**Backup Date:** $(date -Iseconds)
**Branch:** $BRANCH_NAME
**Host:** $(hostname)

## Included Items

$(for item in "${BACKUP_ITEMS[@]}"; do
    if [ -e "$CLAUDE_DIR/$item" ]; then
        echo "- [x] $item"
    else
        echo "- [ ] $item (not present)"
    fi
done)

## Excluded Items (security/privacy)

- .credentials.json (OAuth tokens)
- ~/.claude.json (account metadata)
- statsig/ (telemetry state)
- telemetry/ (telemetry data)
- cache/ (temporary cache)
- debug/ (debug logs)
- plugins/ (plugin data)
EOF

# Stage all changes
echo ""
echo "Staging changes..."
git add -A

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "No changes to commit"
    exit 0
fi

# Commit changes
echo "Committing backup..."
git commit -m "Backup $(date +%Y-%m-%d-%H%M%S)

Automated backup of Claude Code metadata.
Branch: $BRANCH_NAME"

# Push to remote
echo ""
echo "Pushing to GitHub..."
git push -u origin "$BRANCH_NAME"

# Output PR creation URL
echo ""
echo "========================================"
echo "Backup pushed successfully!"
echo ""
echo "Create a PR to review and merge:"
echo "https://github.com/${GITHUB_USER}/${REPO_NAME}/compare/main...${BRANCH_NAME}?expand=1"
echo "========================================"
