# Hybrid Backup for OpenClaw Workspace

Daily backups combining **local compressed archives** + **GitHub commits**.

## How It Works

| Method | Backups Up | Storage |
|--------|-----------|---------|
| **Local Archive** | Full workspace (code, configs, memory files) | `archives/` folder |
| **GitHub** | Changes to backup scripts, logs, key configs | GitHub repo |

## What's Included

### Local Archives (.tar.gz)
- Full workspace: `~/.openclaw/workspace`
- Excludes: `node_modules`, logs, cache
- Location: `backup/archives/`
- Retention: 30 days (auto-cleanup)

### GitHub Commits
- Backup scripts & configuration
- Log files
- Archive manifests

## Setup

```bash
cd ~/.openclaw/workspace/backup

# Run setup (installs cron, configures git)
./setup.sh

# Push to GitHub
git push -u origin main
```

## Manual Backup

```bash
cd ~/.openclaw/workspace/backup
./backup.sh
```

## Restore

### From Local Archive

```bash
# List available archives
ls -lah ~/.openclaw/workspace/backup/archives/

# Extract latest backup
cd ~/
tar -xzf ~/.openclaw/workspace/backup/archives/openclaw-backup-*.tar.gz
```

### From GitHub

```bash
git clone https://github.com/openclawpedro-coder/Daily-Backup.git
cd Daily-Backup
```

## Architecture

```
Daily Backup Repo
├── backup.sh       # Main backup script
├── setup.sh        # Configuration script
├── archives/       # Local tar.gz backups (gitignored)
│   ├── openclaw-backup-HOST-20240220_030001.tar.gz
│   ├── openclaw-backup-HOST-20240221_030002.tar.gz
│   └── ...
└── backup.log      # Execution log
```

## Schedule

- **Frequency:** Daily at 3:00 AM (Africa/Johannesburg timezone)
- **Cron job:** Check with `crontab -l`

## Troubleshooting

**Git push fails:**
```bash
cd ~/.openclaw/workspace/backup
git push origin main
# (Enter credentials if prompted)
```

**Check backup log:**
```bash
tail -f ~/.openclaw/workspace/backup/backup.log
```

**List local archives:**
```bash
ls -lah ~/.openclaw/workspace/backup/archives/
```
