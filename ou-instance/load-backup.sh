#!/bin/bash

# Script to restore an Overleaf data directory from a backup
# Uses tar to extract zstandard compressed backups
# Note: This script requires sudo to restore files with correct ownership

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATA_DIR="$SCRIPT_DIR/../data"

# Check if backups directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backups directory does not exist: $BACKUP_DIR"
    exit 1
fi

# List all available backups
echo "Available backups:"
echo ""

BACKUPS=($(ls -1t "$BACKUP_DIR"/data-backup-*.tar.zst 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "No backups found in $BACKUP_DIR"
    exit 1
fi

# Display backups with index, name, size, and date
for i in "${!BACKUPS[@]}"; do
    BACKUP_FILE="${BACKUPS[$i]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    BACKUP_DATE=$(stat -c %y "$BACKUP_FILE" | cut -d' ' -f1,2 | cut -d'.' -f1)
    printf "%2d) %-45s  Size: %-8s  Date: %s\n" $((i+1)) "$BACKUP_NAME" "$BACKUP_SIZE" "$BACKUP_DATE"
done

echo ""
echo "Enter the name of the backup file to restore (e.g., data-backup-2025-10-20_14-30-45-123.tar.zst)"
read -p "or enter the number from the list above: " SELECTION

# Determine which backup file to use
SELECTED_BACKUP=""

# Check if input is a number
if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    INDEX=$((SELECTION - 1))
    if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#BACKUPS[@]} ]; then
        SELECTED_BACKUP="${BACKUPS[$INDEX]}"
    else
        echo "Error: Invalid selection number."
        exit 1
    fi
else
    # Assume it's a filename
    if [[ "$SELECTION" == */* ]]; then
        # User provided a path
        SELECTED_BACKUP="$SELECTION"
    else
        # Just a filename
        SELECTED_BACKUP="$BACKUP_DIR/$SELECTION"
    fi
fi

# Verify the backup file exists
if [ ! -f "$SELECTED_BACKUP" ]; then
    echo "Error: Backup file not found: $SELECTED_BACKUP"
    exit 1
fi

BACKUP_NAME=$(basename "$SELECTED_BACKUP")
BACKUP_SIZE=$(du -h "$SELECTED_BACKUP" | cut -f1)

echo ""
echo "Selected backup: $BACKUP_NAME"
echo "Backup size: $BACKUP_SIZE"
echo ""
echo "WARNING: This will REPLACE the current data directory with the backup!"
echo "WARNING: All current data will be lost if not backed up!"
echo ""
read -p "Would you like to create a backup of the current data before restoring? (y/n): " BACKUP_CONFIRM
if [[ "$BACKUP_CONFIRM" == "y" || "$BACKUP_CONFIRM" == "Y" ]]; then
    echo ""
    echo "Running backup script..."
    "$SCRIPT_DIR/backup-data-directory.sh"
    BACKUP_EXIT_CODE=$?
    
    if [ $BACKUP_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "Backup was not completed successfully or was canceled."
        read -p "Do you want to continue with the restore anyway? (y/n): " CONTINUE_ANYWAY
        if [[ "$CONTINUE_ANYWAY" != "y" && "$CONTINUE_ANYWAY" != "Y" ]]; then
            echo "Restore canceled by user."
            exit 1
        fi
    fi
    echo ""
fi

echo "WARNING: The server will be shut down to perform the restore."
echo ""
read -p "Do you want to continue with the restore? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Restore canceled by user."
    exit 1
fi

echo ""
echo "Stopping Overleaf server..."
"$SCRIPT_DIR/../bin/stop"
echo "Server stopped."
echo ""

SECONDS=0

echo "Restoring backup to Overleaf data directory..."
echo "Source: $SELECTED_BACKUP"
echo "Target: $DATA_DIR"
echo ""

# Remove existing data directory
if [ -d "$DATA_DIR" ]; then
    echo "Removing existing data directory..."
    sudo rm -rf "$DATA_DIR"
fi

# Extract the backup with sudo to preserve permissions and ownership
echo "Extracting backup..."
sudo tar -xaf "$SELECTED_BACKUP" -C "$SCRIPT_DIR/.."

if [ $? -eq 0 ]; then
    # Format elapsed time
    ELAPSED_SECONDS=$SECONDS
    HOURS=$((ELAPSED_SECONDS / 3600))
    MINUTES=$(((ELAPSED_SECONDS % 3600) / 60))
    SECS=$((ELAPSED_SECONDS % 60))
    
    echo ""
    echo "✓ Restore complete!"
    printf "Elapsed: %02d::%02d::%02d\n" "$HOURS" "$MINUTES" "$SECS"
else
    echo ""
    echo "✗ Error: Restore failed!"
    exit 1
fi

echo ""
read -p "Do you want to restart the Overleaf server now? (y/n): " RESTART_CONFIRM
if [[ "$RESTART_CONFIRM" == "y" || "$RESTART_CONFIRM" == "Y" ]]; then
    echo "Starting Overleaf server..."
    "$SCRIPT_DIR/../bin/up" -d # run in detached mode to avoid blocking the terminal
    echo "Server started."
else
    echo "Server was not restarted. Please remember to start it manually when ready."
fi

