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

DB_NAME=$(grep "'dbname'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_HOST=$(grep "'dbhost'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_USER=$(grep "'dbuser'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_PASSWORD=$(grep "'dbpassword'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

# Enable maintenance mode
echo "Enabling maintenance mode..."
sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --on
if [ $? -ne 0 ]; then
    echo "Failed to enable maintenance mode!" >&2
    exit 1
fi

# Take database snapshot
CREDENTIALS_FILE="/tmp/.my.cnf"
NEXTCLOUD_SQL_BKP="/tmp/nextcloud-sqlbkp.bak"

echo "[client]
user=$DB_USER
password=$DB_PASSWORD
host=$DB_HOST" > "$CREDENTIALS_FILE"

echo "Taking database backup..."
sudo mysqldump --defaults-file="$CREDENTIALS_FILE" --single-transaction --default-character-set=utf8mb4 "$DB_NAME" > "$NEXTCLOUD_SQL_BKP"
rm -f "$CREDENTIALS_FILE"
if [ $? -ne 0 ]; then
    echo "Database backup failed!" >&2
    sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
    exit 1
fi

# Sync data directory to S3
echo "Syncing data directory to S3..."
aws s3 sync "$DATA_DIR/" "s3://$S3_BUCKET/data/"
if [ $? -ne 0 ]; then
    echo "Data directory sync to S3 failed!" >&2
    sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
    exit 1
fi

# Sync config directory to S3
echo "Syncing config directory to S3..."
aws s3 sync "$NEXTCLOUD_DIR/config/" "s3://$S3_BUCKET/config/"
if [ $? -ne 0 ]; then
    echo "Config directory sync to S3 failed!" >&2
    sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
    exit 1
fi

# Sync database snapshot to S3
echo "Syncing database backup to S3..."
aws s3 cp "$NEXTCLOUD_SQL_BKP" "s3://$S3_BUCKET/nextcloud-sqlbkp.bak"
rm -f "$NEXTCLOUD_SQL_BKP"
if [ $? -ne 0 ]; then
    echo "Database backup sync to S3 failed!" >&2
    sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off
    exit 1
fi

# Disable maintenance mode
echo "Disabling maintenance mode..."
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

