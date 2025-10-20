#!/bin/bash

# Script to create a compressed backup of the Overleaf data directory
# Uses tar with zstandard compression for efficient storage
# Note: This script requires sudo to backup files owned by other users (mongo, redis)
#
# Usage:
#   ./backup-data-directory.sh         - Run interactive/manual backup
#   ./backup-data-directory.sh --auto  - Run automated backup (no prompts, auto cleanup)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
MAX_BACKUPS=10

# Check for --auto flag
AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Determine backup directory based on mode
if [ "$AUTO_MODE" = true ]; then
    BACKUP_DIR="$SCRIPT_DIR/backups/automated"
    echo "Running in automated backup mode..."
else
    BACKUP_DIR="$SCRIPT_DIR/backups/manual"
fi

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# In manual mode, prompt for confirmation
if [ "$AUTO_MODE" = false ]; then
    echo "WARNING: The server will be shut down to perform the backup."
    read -p "Do you want to continue? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Backup canceled by user."
        exit 1
    fi
else
    echo "Automated backup: Server will be shut down temporarily."
fi

echo "Stopping Overleaf server..."
"$SCRIPT_DIR/../bin/stop"
echo "Server stopped."

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

# Manage backup retention - keep only the last MAX_BACKUPS backups
# This is to avoid filling up the disk with too many backups / manage disk space.
echo ""

if [ "$AUTO_MODE" = true ]; then
    # In automated mode, only manage automated backups
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/data-backup-*.tar.zst 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        echo "Note: Only the last $MAX_BACKUPS automated backups are kept."
        echo "Currently there are $BACKUP_COUNT automated backups."
        
        # Automatically delete oldest backups from automated directory
        while [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; do
            OLDEST_BACKUP=$(ls -1t "$BACKUP_DIR"/data-backup-*.tar.zst | tail -1)
            OLDEST_SIZE=$(du -h "$OLDEST_BACKUP" | cut -f1)
            echo "Removing oldest backup: $(basename "$OLDEST_BACKUP") (Size: $OLDEST_SIZE)"
            rm -f "$OLDEST_BACKUP"
            BACKUP_COUNT=$((BACKUP_COUNT - 1))
        done
        echo "Old backups removed automatically."
    fi
else
    # In manual mode, check both manual and automated directories for cleanup
    MANUAL_DIR="$SCRIPT_DIR/backups/manual"
    AUTO_DIR="$SCRIPT_DIR/backups/automated"
    
    # Check manual backups
    MANUAL_COUNT=$(ls -1 "$MANUAL_DIR"/data-backup-*.tar.zst 2>/dev/null | wc -l)
    if [ "$MANUAL_COUNT" -gt "$MAX_BACKUPS" ]; then
        echo "Note: There are $MANUAL_COUNT manual backups (limit: $MAX_BACKUPS)."
        
        while [ "$MANUAL_COUNT" -gt "$MAX_BACKUPS" ]; do
            OLDEST_BACKUP=$(ls -1t "$MANUAL_DIR"/data-backup-*.tar.zst | tail -1)
            OLDEST_SIZE=$(du -h "$OLDEST_BACKUP" | cut -f1)
            echo ""
            echo "Oldest manual backup: $(basename "$OLDEST_BACKUP") (Size: $OLDEST_SIZE)"
            read -p "Remove this backup to keep only the last $MAX_BACKUPS? (y/n): " REMOVE_CONFIRM
            
            if [[ "$REMOVE_CONFIRM" == "y" || "$REMOVE_CONFIRM" == "Y" ]]; then
                rm -f "$OLDEST_BACKUP"
                echo "Removed: $(basename "$OLDEST_BACKUP")"
                MANUAL_COUNT=$((MANUAL_COUNT - 1))
            else
                echo "Backup not removed. You may need to manage disk space manually."
                break
            fi
        done
    fi
    
    # Check automated backups
    AUTO_COUNT=$(ls -1 "$AUTO_DIR"/data-backup-*.tar.zst 2>/dev/null | wc -l)
    if [ "$AUTO_COUNT" -gt "$MAX_BACKUPS" ]; then
        echo ""
        echo "Note: There are $AUTO_COUNT automated backups (limit: $MAX_BACKUPS)."
        
        while [ "$AUTO_COUNT" -gt "$MAX_BACKUPS" ]; do
            OLDEST_BACKUP=$(ls -1t "$AUTO_DIR"/data-backup-*.tar.zst | tail -1)
            OLDEST_SIZE=$(du -h "$OLDEST_BACKUP" | cut -f1)
            echo ""
            echo "Oldest automated backup: $(basename "$OLDEST_BACKUP") (Size: $OLDEST_SIZE)"
            read -p "Remove this backup to keep only the last $MAX_BACKUPS? (y/n): " REMOVE_CONFIRM
            
            if [[ "$REMOVE_CONFIRM" == "y" || "$REMOVE_CONFIRM" == "Y" ]]; then
                rm -f "$OLDEST_BACKUP"
                echo "Removed: $(basename "$OLDEST_BACKUP")"
                AUTO_COUNT=$((AUTO_COUNT - 1))
            else
                echo "Backup not removed. You may need to manage disk space manually."
                break
            fi
        done
    fi
fi

echo ""
if [ "$AUTO_MODE" = true ]; then
    # In automated mode, always restart the server
    echo "Starting Overleaf server..."
    "$SCRIPT_DIR/../bin/up" -d # run in detached mode to avoid blocking the terminal
    echo "Server started."
    echo "Automated backup completed successfully."
else
    # In manual mode, prompt for restart
    read -p "Do you want to restart the Overleaf server now? (y/n): " RESTART_CONFIRM
    if [[ "$RESTART_CONFIRM" == "y" || "$RESTART_CONFIRM" == "Y" ]]; then
        echo "Starting Overleaf server..."
        "$SCRIPT_DIR/../bin/up" -d # run in detached mode to avoid blocking the terminal
        echo "Server started."
    else
        echo "Server was not restarted. Please remember to start it manually when ready."
    fi
fi

