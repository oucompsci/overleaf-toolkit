STOP_BIN="../bin/stop"
START_BIN="../bin/start"
BACKUP_SOURCE="../data"

echo "=== Overleaf Data Directory Backup ==="
echo ""

# Create backups directory if it doesn't exist
mkdir -p backups

# Prompt for backup filename
echo "Backup configuration:"
read -p "Enter base filename [data.tar.gz]: " BACKUP_FILE
BACKUP_FILE=${BACKUP_FILE:-data.tar.gz}

# Always append epoch timestamp to filename
# so that we can prevent overwriting existing backups
FILENAME="${BACKUP_FILE%.*.*}"
EXTENSION="${BACKUP_FILE#$FILENAME}"
EPOCH_TIME=$(date +%s)
BACKUP_FILE="backups/${FILENAME}-${EPOCH_TIME}${EXTENSION}"
echo "Output file: $BACKUP_FILE"

# Check if file already exists
if [[ -f "$BACKUP_FILE" ]]; then
    echo ""
    echo "WARNING: File '$BACKUP_FILE' already exists"
    read -p "Overwrite existing file? (y/n): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "Backup cancelled."
        exit 1
    fi
fi

echo ""
echo "WARNING: Server will be temporarily unavailable during backup"
echo "    Estimated downtime: 2-5 minutes"
echo ""
read -p "Continue with backup? (y/n): " PROCEED

if [[ "$PROCEED" =~ ^[Yy]$ ]]; then
    read -p "Automatically restart server after backup? (y/n): " RESTART
else
    echo "Backup cancelled."
    exit 1
fi

echo ""
echo "Shutting down Overleaf server..."
$STOP_BIN # graceful shutdown, prevent writes to the database

echo "Creating compressed archive..."
# assumes this script is ran as root
# much of data is owned by root. 
sudo tar -czf "$BACKUP_FILE" "../data" # backup data directory 
echo "Backup complete: $(pwd)/$BACKUP_FILE"

if [[ "$RESTART" =~ ^[Yy]$ ]]; then
    echo "Restarting server..."
    $START_BIN
    echo "Server is back online."
else
    echo ""
    echo "Server remains stopped. To restart manually, run:"
    echo "  $START_BIN"
fi
