#!/bin/bash
#
# Setup script for Hybrid Backup (GitHub + Local Archives)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_DIR="$SCRIPT_DIR/archives"

echo "=== Hybrid Backup Setup ==="
echo

# Create archive directory
mkdir -p "$ARCHIVE_DIR"
echo "[OK] Archive directory: $ARCHIVE_DIR"

# Check git config
echo
echo "Checking Git configuration..."
cd "$SCRIPT_DIR"

if ! git config user.email &>/dev/null; then
    echo "Enter email for backup commits (e.g., backup@openclaw.local):"
    read -r email
    git config user.email "${email:-backup@openclaw.local}"
fi

if ! git config user.name &>/dev/null; then
    echo "Enter name for backup commits (e.g., OpenClaw Backup):"
    read -r name
    git config user.name "${name:-OpenClaw Backup}"
fi

echo "[OK] Git configured: $(git config user.name) <$(git config user.email)>"

# Setup cron job
echo
echo "Setting up cron job for daily backups at 3:00 AM..."

# Remove old entries
(crontab -l 2>/dev/null | grep -v "openclaw-backup" | grep -v "$SCRIPT_DIR") | crontab - 2>/dev/null || true

# Add new entry
CRON_ENTRY="0 3 * * * cd $SCRIPT_DIR && bash backup.sh >> $SCRIPT_DIR/backup.log 2>&1"
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo "[OK] Cron job installed"

# Initial commit
echo
echo "Performing initial commit..."
git add -A
git commit -m "Initial backup setup" || echo "(nothing to commit)"

echo
echo "=== Setup Complete ==="
echo
echo "Configuration:"
echo "  - Archive location: $ARCHIVE_DIR"
echo "  - GitHub repo: https://github.com/openclawpedro-coder/Daily-Backup.git"
echo "  - Schedule: Daily at 3:00 AM"
echo "  - Log: $SCRIPT_DIR/backup.log"
echo
echo "To push to GitHub (run manually once):"
echo "  cd $SCRIPT_DIR"
echo "  git push -u origin main"
echo
echo "To verify cron job:"
echo "  crontab -l"
echo

# Run test backup?
echo "Run a test backup now? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo
    bash "$SCRIPT_DIR/backup.sh"
fi
