#!/bin/bash
#
# Simple Restore Helper
# Usage: ./restore.sh --date 2025-02-22 --destination ~/restore-test/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.openclaw/workspace/backup"
ARCHIVE_DIR="$BACKUP_DIR/archives"

# Defaults
RESTORE_DATE=""
DEST_DIR=""
DRY_RUN=false
INTERACTIVE=true

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Restore OpenClaw workspace from backup.

Options:
    -d, --date DATE          Restore backup from specific date (YYYY-MM-DD)
    -o, --destination PATH   Restore to this directory (default: temp)
    --dry-run                Show what would be restored without doing it
    --no-interactive         Skip confirmation prompts
    -h, --help               Show this help

Examples:
    $0 --date 2025-02-22 --destination ~/restore-test
    $0 --date 2025-02-22 --dry-run
    $0 --no-interactive

Without --destination, files are restored to a temporary location.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--date)
                RESTORE_DATE="$2"
                shift 2
                ;;
            -o|--destination)
                DEST_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-interactive)
                INTERACTIVE=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Find backup by date
find_backup_by_date() {
    local target_date="${1//-/}"
    local found

    # Search in all subdirectories
    found=$(find "$ARCHIVE_DIR" -name "*${target_date}*.tar.gz" -type f 2>/dev/null | head -1)

    echo "$found"
}

# List available backups
list_backups() {
    log "Available backups:"
    log ""

    local has_backups=false

    for dir in daily weekly monthly; do
        local subdir="$ARCHIVE_DIR/$dir"
        if [[ -d "$subdir" ]]; then
            local count
            count=$(find "$subdir" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
            if [[ $count -gt 0 ]]; then
                has_backups=true
                log "  $dir/ ($count archives):"
                find "$subdir" -name "*.tar.gz" -type f -printf '    %f\n' 2>/dev/null | sort | tail -5
                log ""
            fi
        fi
    done

    if [[ "$has_backups" == false ]]; then
        log "  No backups found in $ARCHIVE_DIR"
    fi
}

# Restore from archive
restore_backup() {
    local archive_path="$1"
    local dest="$2"

    log "=========================================="
    log "Restore Configuration"
    log "=========================================="
    log "Archive:    $archive_path"
    log "Extract to: $dest"
    log ""

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN - Would extract archive contents to:"
        log "  $dest"
        log ""
        log "Archive contents preview:"
        tar -tzf "$archive_path" | head -20
        log "... ($(tar -tzf "$archive_path" | wc -l) total entries)"
        return 0
    fi

    # Create destination if needed
    if [[ ! -d "$dest" ]]; then
        log "Creating destination directory..."
        mkdir -p "$dest"
    fi

    # Verify checksum if available
    local checksum_file
    checksum_file=$(find "$ARCHIVE_DIR" -name "$(basename "$archive_path").sha256" 2>/dev/null | head -1)

    if [[ -n "$checksum_file" ]]; then
        log "Verifying archive integrity..."
        cd "$(dirname "$checksum_file")"
        if sha256sum -c "$(basename "$checksum_file")" > /dev/null 2>&1; then
            log "  Checksum verified"
        else
            error_exit "Checksum verification failed - archive may be corrupt"
        fi
    fi

    # Extract
    log "Extracting archive..."
    if tar -xzf "$archive_path" -C "$dest"; then
        log ""
        log "=========================================="
        log "✓ Restore completed successfully!"
        log "=========================================="
        log ""
        log "Restored to: $dest"

        # Find the workspace directory
        local restored_workspace
        restored_workspace=$(find "$dest" -name "AGENTS.md" -o -name "SOUL.md" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)

        if [[ -n "$restored_workspace" ]]; then
            log "Workspace location: $restored_workspace"
            log ""
            log "To use this restore:"
            log "  cd $restored_workspace"
        fi

        return 0
    else
        error_exit "Failed to extract archive"
    fi
}

# Main
main() {
    parse_args "$@"

    log "=========================================="
    log "OpenClaw Restore Helper"
    log "=========================================="

    # List backups if no date specified or interactive mode
    if [[ -z "$RESTORE_DATE" && "$INTERACTIVE" == true ]]; then
        list_backups

        echo ""
        read -rp "Enter date to restore (YYYY-MM-DD), or 'latest': " RESTORE_DATE
    fi

    # Find the backup
    local archive
    if [[ "$RESTORE_DATE" == "latest" || -z "$RESTORE_DATE" ]]; then
        archive=$(find "$ARCHIVE_DIR" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -z "$archive" ]]; then
            error_exit "No backups found"
        fi
        log "Using latest backup: $(basename "$archive")"
    else
        archive=$(find_backup_by_date "$RESTORE_DATE")
        if [[ -z "$archive" ]]; then
            error_exit "No backup found for date: $RESTORE_DATE"
        fi
        log "Found backup: $(basename "$archive")"
    fi

    # Set default destination
    if [[ -z "$DEST_DIR" ]]; then
        DEST_DIR=$(mktemp -d)
        log "Using temp destination: $DEST_DIR"
    fi

    # Confirm if interactive
    if [[ "$INTERACTIVE" == true && "$DRY_RUN" == false ]]; then
        echo ""
        read -rp "Proceed with restore? [y/N]: " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || error_exit "Restore cancelled"
    fi

    # Perform restore
    restore_backup "$archive" "$DEST_DIR"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi