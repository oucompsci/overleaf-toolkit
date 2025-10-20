#!/bin/bash

# This script installs and activates the automatic backup service for the Overleaf instance.
# It copies the systemd service and timer unit files for scheduled Overleaf backups
# to /etc/systemd/system/, reloads the systemd daemon, enables, and starts the timer.
# After running this script, automatic scheduled backups will run in the background.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SERVICE_PATH="/etc/systemd/system/overleaf-backup.service" # target path to the systemd service 
BACKUP_TIMER_PATH="/etc/systemd/system/overleaf-backup.timer" # target path to the systemd timer

# Verify source files exist
if [ ! -f "$SCRIPT_DIR/overleaf-backup.service" ]; then
    echo "Error: Source file not found: $SCRIPT_DIR/overleaf-backup.service"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/overleaf-backup.timer" ]; then
    echo "Error: Source file not found: $SCRIPT_DIR/overleaf-backup.timer"
    exit 1
fi

# Check if service or timer file exists at target location and prompt user before overwriting
for TARGET in "$BACKUP_SERVICE_PATH" "$BACKUP_TIMER_PATH"; do
    if [ -f "$TARGET" ]; then
        echo "Warning: File already exists at $TARGET"
        read -p "Do you want to overwrite it? (y/n): " OVERWRITE_CONFIRM
        if [[ ! "$OVERWRITE_CONFIRM" =~ ^[Yy]$ ]]; then
            echo "Aborting installation to preserve existing file: $TARGET"
            exit 1
        fi
    fi
done

# Clone the systemd service and timer to the correct location on this system.
echo "Installing systemd service and timer..."
sudo cp "$SCRIPT_DIR/overleaf-backup.service" "$BACKUP_SERVICE_PATH"
sudo cp "$SCRIPT_DIR/overleaf-backup.timer" "$BACKUP_TIMER_PATH"

# Reload systemd daemon to recognize the new services
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable and start the backup timer
echo "Enabling and starting backup timer..."
sudo systemctl enable overleaf-backup.timer
sudo systemctl start overleaf-backup.timer

echo "Backup services initialized successfully!"
echo "Check status with: sudo systemctl status overleaf-backup.timer"