#!/bin/bash
#
# Restore Test Script - Verifies backup integrity
# Run weekly via cron to ensure backups are restorable
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

BACKUP_DIR="${HOME}/.openclaw/workspace/backup"
ARCHIVE_DIR="$BACKUP_DIR/archives"
TEMP_DIR="$(mktemp -d)"
TEST_REPORT="$BACKUP_DIR/restore-test-report.txt"

trap 'rm -rf "$TEMP_DIR"' EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

# Test a backup archive
test_backup() {
    local archive_path="$1"
    local archive_name
    archive_name=$(basename "$archive_path")

    log "=========================================="
    log "Testing backup: $archive_name"
    log "=========================================="

    # Check archive exists
    if [[ ! -f "$archive_path" ]]; then
        error_exit "Archive not found: $archive_path"
    fi

    # Verify file is readable
    if ! file "$archive_path" > /dev/null 2>&1; then
        error_exit "Archive is not readable: $archive_path"
    fi

    # Get archive size
    local size
    size=$(du -h "$archive_path" | cut -f1)
    log "Archive size: $size"

    # Find and verify checksum
    local checksum_file
    checksum_file=$(find "$ARCHIVE_DIR" "$BACKUP_DIR/checksums" -name "*.sha256" -type f 2>/dev/null | head -1)

    if [[ -n "$checksum_file" ]]; then
        log "Verifying checksum..."
        cd "$(dirname "$checksum_file")"
        if sha256sum -c "$(basename "$checksum_file")" > /dev/null 2>&1; then
            log "Checkum verified"
        else
            error_exit "Checksum verification failed"
        fi
    else
        log "No checksum found, skipping verification"
    fi

    # Extract to temp directory
    log "Extracting to temp directory..."
    if ! tar -xzf "$archive_path" -C "$TEMP_DIR" 2>/tmp/tar-error.log; then
        log "Standard tar failed, trying with warnings suppressed..."
        if ! tar -xzf "$archive_path" -C "$TEMP_DIR" --warning=no-unknown-keyword 2>/tmp/tar-error.log; then
            error_exit "Failed to extract archive"
        fi
    fi
    log "Extraction successful"

    # Verify key files exist and are readable
    log "Verifying key files..."
    local restored_workspace="$TEMP_DIR/workspace"
    [[ ! -d "$restored_workspace" ]] && restored_workspace="$TEMP_DIR/.openclaw"
    [[ ! -d "$restored_workspace" ]] && restored_workspace="$TEMP_DIR/$(ls -1 "$TEMP_DIR" | head -1)"

    local key_files=(
        "SOUL.md"
        "AGENTS.md"
        "MEMORY.md"
        "backup/backup.sh"
    )

    local found_count=0
    for file in "${key_files[@]}"; do
        local filepath="$restored_workspace/$file"
        if [[ -f "$filepath" ]]; then
            # Test readability
            if head -c 1024 "$filepath" > /dev/null 2>&1; then
                log "  ✓ $file (readable)"
                ((found_count++))
            else
                log "  ✗ $file (NOT readable)"
            fi
        else
            log "  ⚠ $file (not found in expected location)"
        fi
    done

    log "Key files verified: $found_count/${#key_files[@]}"

    if [[ $found_count -lt 3 ]]; then
        error_exit "Too many key files missing or unreadable"
    fi

    # Count total files
    local file_count
    file_count=$(find "$restored_workspace" -type f 2>/dev/null | wc -l)
    log "Total files in backup: $file_count"

    if [[ $file_count -lt 10 ]]; then
        error_exit "Backup seems incomplete (only $file_count files)"
    fi

    log "=========================================="
    log "✓ RESTORE TEST PASSED: $archive_name"
    log "=========================================="

    cat > "$TEST_REPORT" <<EOF
Restore Test Report
Generated: $(date)
Archive: $archive_name
Size: $size
Status: PASSED
Key Files: $found_count/${#key_files[@]}
Total Files: $file_count
EOF

    return 0
}

# Main execution
main() {
    log "Starting restore test..."
    log "Temp directory: $TEMP_DIR"

    # Test the most recent backup from any category
    local latest_backup
    latest_backup=$(find "$ARCHIVE_DIR" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_backup" ]]; then
        error_exit "No backup archives found"
    fi

    log "Found latest backup: $(basename "$latest_backup")"

    if test_backup "$latest_backup"; then
        log "Restore test completed successfully"
        exit 0
    else
        exit 1
    fi
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi