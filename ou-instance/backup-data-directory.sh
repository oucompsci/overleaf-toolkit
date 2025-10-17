#!/bin/bash

# Script to create a compressed backup of the Overleaf data directory
# Uses tar with zstandard compression for efficient storage
# Note: This script requires sudo to backup files owned by other users (mongo, redis)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATA_DIR="$SCRIPT_DIR/../data"

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp with milliseconds (YYYY-MM-DD_HH-MM-SS-mmm)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S-%3N")
BACKUP_FILE="$BACKUP_DIR/data-backup-${TIMESTAMP}.tar.zst"

SECONDS=0

echo "Creating backup of Overleaf data directory..."
echo "Source: $DATA_DIR"
echo "Target: $BACKUP_FILE"
echo ""

# Create the backup with sudo to access all files
sudo tar -caf "$BACKUP_FILE" -C "$SCRIPT_DIR/.." data/

# Change ownership of backup file to current user
sudo chown "$USER:$USER" "$BACKUP_FILE"

# Format elapsed time
ELAPSED_SECONDS=$SECONDS
HOURS=$((ELAPSED_SECONDS / 3600))
MINUTES=$(((ELAPSED_SECONDS % 3600) / 60))
SECS=$((ELAPSED_SECONDS % 60))

echo ""
echo "Backup complete!"
echo "File created: $BACKUP_FILE"
printf "Elapsed: %02d::%02d::%02d\n" "$HOURS" "$MINUTES" "$SECS"

# Show backup file size
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup size: $SIZE"
fi

