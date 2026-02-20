# Daily Backup for OpenClaw Workspace

Automated daily backups of the OpenClaw workspace to AWS S3.

## What's Backed Up

- Full workspace directory: `~/.openclaw/workspace`
- Includes: code, configs, memory files, documentation
- Excludes: `.git/objects`, `node_modules`, logs, cache files

## Prerequisites

- AWS CLI installed
- AWS credentials configured (`aws configure`)
- S3 bucket (created automatically by setup script)

## Installation

```bash
# Clone and enter the repo
git clone https://github.com/openclawpedro-coder/Daily-Backup.git
cd Daily-Backup

# Run setup
./setup.sh
```

The setup script will:
1. Check AWS credentials
2. Create an S3 bucket (or use existing)
3. Install the cron job for 3:00 AM daily
4. Optionally run a test backup

## Manual Backup

```bash
./backup.sh
```

## Restore

To restore from a backup:

```bash
# List available backups
aws s3 ls s3://YOUR-BUCKET/backups/ --recursive

# Download specific backup
aws s3 cp s3://YOUR-BUCKET/backups/2024-01-15/openclaw-backup-HOST-20240115_030000.tar.gz ./

# Extract to restore
tar -xzf openclaw-backup-*.tar.gz -C ~/.openclaw
```

## Retention

Backups older than 30 days are automatically removed. S3 versioning provides additional protection against accidental deletion.
