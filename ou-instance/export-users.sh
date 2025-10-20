#!/bin/bash

# Script to export user data from Overleaf MongoDB instance
# This script exports user count and full user data from the sharelatex database to this directory.
# The targets are 
# - user-count.txt: the number of users in the database
# - exported-users.json: the full user data in JSON format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# Full paths for target files
USER_COUNT_FILE="$OUTPUT_DIR/user-count.txt"
EXPORTED_USERS_FILE="$OUTPUT_DIR/exported-users.json"

# MongoDB connection string (inside Docker container)
# Note: we need the sharelatex collection, not "test" (default)
MONGO_URI="mongodb://127.0.0.1:27017/sharelatex?directConnection=true&serverSelectionTimeoutMS=2000"
MONGO_CONTAINER="mongo"

SECONDS=0

echo "Exporting user data from Overleaf MongoDB..."
echo "Target export files will be:"
echo "  - User count: $USER_COUNT_FILE"
echo "  - Exported users data: $EXPORTED_USERS_FILE"

# Export user count
echo "Getting user count..."
docker exec "$MONGO_CONTAINER" mongosh "$MONGO_URI" --eval "db.users.countDocuments()" > "$USER_COUNT_FILE"

# Export all users as JSON
echo "Exporting all users..."
docker exec "$MONGO_CONTAINER" mongosh "$MONGO_URI" --eval "db.users.find().toArray()" > "$EXPORTED_USERS_FILE"

# Format elapsed time
ELAPSED_SECONDS=$SECONDS
HOURS=$((ELAPSED_SECONDS / 3600))
MINUTES=$(((ELAPSED_SECONDS % 3600) / 60))
SECS=$((ELAPSED_SECONDS % 60))

echo "Export complete!"
echo "Files created:"
echo "  - $USER_COUNT_FILE"
echo "  - $EXPORTED_USERS_FILE"
printf "Elapsed: %02d::%02d::%02d\n" "$HOURS" "$MINUTES" "$SECS"
