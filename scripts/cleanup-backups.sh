#!/bin/bash
# backup-shared.sh: CloudByte Solutions /shared backup automation
# Author: Christopher Galloway
# Created: 2026-11-27
# Purpose: delete backup archives older than 7 days
# Usage: sudo bash cleanup-backups.sh           Delete archives older than 7 days
# Usage: sudo bash cleanup-backups.sh --preview List what would be deleted, do not delete

set -eo pipefail

cleanup() {
    if [ -f "$ARCHIVE" ]; then
        rm -f "$ARCHIVE"
        echo "Cleanup: removed partial archive $ARCHIVE" >&2
    fi 
}

# --- Sudo guard -----------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Error: backup-shared.sh must be run as root."
    echo "Hint: sudo bash $0"
    exit 1
fi

# --- Config ---------------------------------------------------------------
BACKUP_DIR=/shared/backups
RETENTION_DAYS=7    # edit lines
PREVIEW=false

# --- Argument parsing ----------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --preview)
            PREVIEW=true
            shift
            ;;
        -h|--help)
            grep '^# Purpose:' "$0" | sed 's/# Purpose: //'
            grep '^# Usage:' "$0" | sed 's/# Usage: //'
            exit 0
            ;;
        *)
            echo "Error: unknown argument '$1'"
            echo "Hint: sudo bash cleanup-backups.sh --help"
            exit 2
            ;;
    esac
done

# --- Run the cleanup -----------------------------------------------------
if [ "$PREVIEW" = true ]; then
    echo "Preview: archives older than $RETENTION_DAYS days that would be removed:"
    find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$RETENTION_DAYS" -print
    count=$(find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$RETENTION_DAYS" | wc -l)
    echo "Preview: would remove $count archive(s)."
else
    count=$(find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$RETENTION_DAYS" | wc -l)
    find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$RETENTION_DAYS" -delete
    echo "Cleanup: removed $count archive(s) older than $RETENTION_DAYS days."
fi