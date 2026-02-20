#!/bin/bash
#
# Daily Backup Script for OpenClaw Workspace
# Backs up ~/.openclaw/workspace to AWS S3
#

set -euo pipefail

# Configuration
WORKSPACE_DIR="${HOME}/.openclaw/workspace"
BACKUP_BUCKET="${BACKUP_BUCKET:-openclaw-daily-backups}"
AWS_REGION="${AWS_REGION:-us-east-1}"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
BACKUP_NAME="openclaw-backup-${HOSTNAME}-${TIMESTAMP}"

# Temporary directory for archive
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "[$(date)] Starting backup: $BACKUP_NAME"
echo "[$(date)] Workspace: $WORKSPACE_DIR"

# Verify workspace exists
if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "[ERROR] Workspace directory not found: $WORKSPACE_DIR"
    exit 1
fi

# Create compressed archive
echo "[$(date)] Creating archive..."
ARCHIVE_PATH="$TMP_DIR/${BACKUP_NAME}.tar.gz"
tar -czf "$ARCHIVE_PATH" \
    --exclude='.git/objects' \
    --exclude='node_modules' \
    --exclude='*.log' \
    --exclude='.cache' \
    -C "$(dirname "$WORKSPACE_DIR")" \
    "$(basename "$WORKSPACE_DIR")"

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo "[$(date)] Archive created: $ARCHIVE_SIZE"

# Upload to S3 with date prefix for organization
echo "[$(date)] Uploading to S3..."
S3_KEY="backups/${DATE}/${BACKUP_NAME}.tar.gz"

aws s3 cp "$ARCHIVE_PATH" "s3://${BACKUP_BUCKET}/${S3_KEY}" \
    --storage-class STANDARD_IA \
    --metadata BackupDate="$DATE",Host="$HOSTNAME",Size="$ARCHIVE_SIZE"

# Verify upload
aws s3 ls "s3://${BACKUP_BUCKET}/${S3_KEY}" > /dev/null || {
    echo "[ERROR] Upload verification failed"
    exit 1
}

# Cleanup old backups (keep last 30 days)
echo "[$(date)] Cleaning up old backups..."
CUTOFF_DATE=$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)

aws s3 ls "s3://${BACKUP_BUCKET}/backups/" | awk '{print $2}' | sed 's:/$::' | while read -r backup_date; do
    if [[ "$backup_date" < "$CUTOFF_DATE" ]]; then
        echo "[$(date)] Removing old backup: $backup_date"
        aws s3 rm --recursive "s3://${BACKUP_BUCKET}/backups/${backup_date}/"
    fi
done

echo "[$(date)] Backup completed successfully: s3://${BACKUP_BUCKET}/${S3_KEY}"
echo "[$(date)] Archive size: $ARCHIVE_SIZE"
