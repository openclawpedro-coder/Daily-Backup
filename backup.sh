#!/bin/bash
#
# Hybrid Backup Script for OpenClaw Workspace
# - Creates local compressed archives
# - Commits important files to GitHub
#

set -euo pipefail

# Configuration
WORKSPACE_DIR="${HOME}/.openclaw/workspace"
BACKUP_DIR="${WORKSPACE_DIR}/backup"
LOCAL_ARCHIVE_DIR="${BACKUP_DIR}/archives"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
BACKUP_NAME="openclaw-backup-${HOSTNAME}-${TIMESTAMP}"

# Ensure directories exist
mkdir -p "$LOCAL_ARCHIVE_DIR"

echo "[$(date)] Starting hybrid backup: $BACKUP_NAME"
echo "[$(date)] Workspace: $WORKSPACE_DIR"

# ====================
# PART 1: Local Archive
# ====================
echo "[$(date)] Creating local archive..."
ARCHIVE_PATH="$LOCAL_ARCHIVE_DIR/${BACKUP_NAME}.tar.gz"

tar -czf "$ARCHIVE_PATH" \
    --exclude='node_modules' \
    --exclude='*.log' \
    --exclude='.cache' \
    --exclude="${BACKUP_DIR#$WORKSPACE_DIR/}/archives" \
    -C "$(dirname "$WORKSPACE_DIR")" \
    "$(basename "$WORKSPACE_DIR")"

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo "[$(date)] Archive created: $ARCHIVE_SIZE at $ARCHIVE_PATH"

# Cleanup old local archives (keep last 30 days)
echo "[$(date)] Cleaning up old local archives..."
find "$LOCAL_ARCHIVE_DIR" -name "*.tar.gz" -mtime +30 -delete || true

# ======================
# PART 2: GitHub Backup
# ======================
echo "[$(date)] Committing files to GitHub..."

cd "$BACKUP_DIR"

# Configure git if not already set
git config user.email "backup@openclaw.local" 2>/dev/null || true
git config user.name "OpenClaw Backup" 2>/dev/null || true

# Add all changes
git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "[$(date)] No changes to commit to GitHub"
else
    # Commit with timestamp
    git commit -m "Backup $TIMESTAMP - Archive size: $ARCHIVE_SIZE"
    
    # Push to GitHub
    if git push origin main 2>/dev/null; then
        echo "[$(date)] Successfully pushed to GitHub"
    else
        echo "[WARN] Could not push to GitHub - may need authentication"
        echo "       Run: cd $BACKUP_DIR && git push origin main"
    fi
fi

# ======================
# Summary
# ======================
echo "[$(date)] Backup completed:"
echo "  - Local archive: $ARCHIVE_PATH ($ARCHIVE_SIZE)"
echo "  - GitHub repo: https://github.com/openclawpedro-coder/Daily-Backup.git"
echo "  - Archive retention: 30 days"
echo "  - Next backup: Tomorrow at 3:00 AM"
