#!/bin/bash

# This script installs and activates the automatic user monitoring service for the Overleaf instance.
# It copies the systemd service and timer unit files for scheduled Overleaf user monitoring
# to /etc/systemd/system/, reloads the systemd daemon, enables, and starts the timer.
# After running this script, automatic scheduled monitoring will run in the background.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SERVICE_PATH="/etc/systemd/system/overleaf-monitor.service" # target path to the systemd service 
MONITOR_TIMER_PATH="/etc/systemd/system/overleaf-monitor.timer" # target path to the systemd timer

# Verify source files exist
if [ ! -f "$SCRIPT_DIR/overleaf-monitor.service" ]; then
    echo "Error: Source file not found: $SCRIPT_DIR/overleaf-monitor.service"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/overleaf-monitor.timer" ]; then
    echo "Error: Source file not found: $SCRIPT_DIR/overleaf-monitor.timer"
    exit 1
fi

# Check if service or timer file exists at target location and prompt user before overwriting
for TARGET in "$MONITOR_SERVICE_PATH" "$MONITOR_TIMER_PATH"; do
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
sudo cp "$SCRIPT_DIR/overleaf-monitor.service" "$MONITOR_SERVICE_PATH"
sudo cp "$SCRIPT_DIR/overleaf-monitor.timer" "$MONITOR_TIMER_PATH"

# Reload systemd daemon to recognize the new services
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable and start the monitor timer
echo "Enabling and starting monitor timer..."
sudo systemctl enable overleaf-monitor.timer
sudo systemctl start overleaf-monitor.timer

echo "Monitor services initialized successfully!"
echo "Check status with: sudo systemctl status overleaf-monitor.timer"

