#!/bin/bash
#
# Backup Monitor - Checks for failures and sends alerts
# Run this after backup via cron, or manually
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

BACKUP_DIR="${HOME}/.openclaw/workspace/backup"
MARKER_FILE="$BACKUP_DIR/.backup-failed-marker"
LOG_FILE="$BACKUP_DIR/backup.log"
REPORT_FILE="$BACKUP_DIR/weekly-report.txt"

# Skip if no marker
[[ ! -f "$MARKER_FILE" ]] && exit 0

# Extract failure info
FAILURE_INFO=$(cat "$MARKER_FILE")
TIMESTAMP=$(echo "$FAILURE_INFO" | cut -d'|' -f2)
HOSTNAME=$(echo "$FAILURE_INFO" | cut -d'|' -f3)

# Get last 10 lines of log for context
LOG_CONTEXT=$(tail -10 "$LOG_FILE" 2>/dev/null || echo "No log found")

# Build message
MESSAGE="⚠️ OpenClaw Backup FAILED

Host: $HOSTNAME
Time: $TIMESTAMP

Recent log entries:
$LOG_CONTEXT

Check: $LOG_FILE"

echo "$MESSAGE"

# Keep marker timestamped
mv "$MARKER_FILE" "${MARKER_FILE}.$(date +%s)"
