#!/bin/bash

BACKUP_DIR="/srv/backups/vaultwarden"
ROOT_DIR="/srv/storage/vaultwarden"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$BACKUP_DIR"

# Zip from the parent so the archive contains a vaultwarden/ top-level folder
tar -czf "$BACKUP_DIR/vaultwarden_$DATE.tar.gz" -C "$(dirname "$ROOT_DIR")" "$(basename "$ROOT_DIR")"

# Keep the 7 most recent archives
ls -1t "$BACKUP_DIR"/vaultwarden_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm --

echo "Backup completed at $DATE"
