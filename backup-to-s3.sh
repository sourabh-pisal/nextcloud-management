#!/bin/bash

# Script to backup Nextcloud data, database, and config files to S3

# Measure script execution time
START_TIME=$(date +%s)

# Arguments
NEXTCLOUD_DIR="$1"
S3_BUCKET="$2"

if [ -z "$NEXTCLOUD_DIR" ] || [ -z "$S3_BUCKET" ]; then
    echo "Usage: $0 <nextcloud_directory> <s3_bucket>"
    exit 1
fi

CONFIG_FILE="$NEXTCLOUD_DIR/config/config.php"
DATA_DIR=$(grep "'datadirectory'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

# Sync directory to S3
echo "Syncing directory to S3"
aws s3 sync "$DATA_DIR/sourabh/files/" "s3://$S3_BUCKET/"
if [ $? -ne 0 ]; then
    echo "Directory sync to S3 failed!" >&2
    sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
    exit 1
fi

# Disable maintenance mode
echo "Disabling maintenance mode"
sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
if [ $? -ne 0 ]; then
    echo "Failed to disable maintenance mode!" >&2
    exit 1
fi

# Measure end time and calculate total duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print total time taken
echo "Backup completed in $DURATION seconds."

