#!/bin/bash
#
# Setup script for OpenClaw Daily Backup
# Run this once to configure AWS credentials and verify the setup
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OpenClaw Daily Backup Setup ==="
echo

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI not found. Install it first:"
    echo "  sudo apt-get update && sudo apt-get install -y awscli"
    exit 1
fi
echo "[OK] AWS CLI found"

# Check AWS credentials
echo
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "[WARN] AWS credentials not configured"
    echo
    echo "To configure AWS credentials, run:"
    echo "  aws configure"
    echo
    echo "You'll need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (e.g., us-east-1, eu-west-1)"
    exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
echo "[OK] AWS credentials configured (Account: $ACCOUNT)"

# Get or create bucket
DEFAULT_BUCKET="openclaw-backups-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)"
echo
echo "Enter S3 bucket name for backups (or press Enter for: $DEFAULT_BUCKET):"
read -r BACKUP_BUCKET
BACKUP_BUCKET="${BACKUP_BUCKET:-$DEFAULT_BUCKET}"

# Create bucket if it doesn't exist
if ! aws s3 ls "s3://$BACKUP_BUCKET" &> /dev/null; then
    echo "Creating bucket: $BACKUP_BUCKET"
    if [[ "$(aws configure get region)" == "us-east-1" ]]; then
        aws s3 mb "s3://$BACKUP_BUCKET"
    else
        aws s3 mb "s3://$BACKUP_BUCKET" --region "$(aws configure get region)"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BACKUP_BUCKET" \
        --versioning-configuration Status=Enabled
    
    echo "[OK] Bucket created and versioning enabled"
else
    echo "[OK] Using existing bucket: $BACKUP_BUCKET"
fi

# Create cron job
echo
echo "Setting up cron job for daily backups at 3:00 AM..."
CRON_ENTRY="0 3 * * * cd $SCRIPT_DIR && AWS_BACKUP_BUCKET=$BACKUP_BUCKET bash backup.sh >> $SCRIPT_DIR/backup.log 2>&1"

# Remove old entry if exists
(crontab -l 2>/dev/null | grep -v "openclaw-backup" | grep -v "$SCRIPT_DIR") | crontab -

# Add new entry
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo "[OK] Cron job installed"
echo "   Entry: $CRON_ENTRY"
echo

# Test backup
echo "Run a test backup now? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo
    export BACKUP_BUCKET
    bash "$SCRIPT_DIR/backup.sh"
fi

echo
echo "=== Setup Complete ==="
echo
echo "Configuration saved:"
echo "  Bucket: $BACKUP_BUCKET"
echo "  Schedule: Daily at 3:00 AM"
echo "  Log: $SCRIPT_DIR/backup.log"
echo
echo "To check backup status:"
echo "  tail -f $SCRIPT_DIR/backup.log"
