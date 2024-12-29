#!/bin/bash

# Script to backup Nextcloud data, database, and config files
#
# Measure script execution time
START_TIME=$(date +%s)

# Arguments
NEXTCLOUD_DIR="$1"
BACKUP_DIR="$2"
BACKUP_DIR_DATE_SUFFIX=$(date +%Y%m%d)

CONFIG_FILE="$NEXTCLOUD_DIR/config/config.php"
DATA_DIR=$(grep "'datadirectory'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

DB_NAME=$(grep "'dbname'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_HOST=$(grep "'dbhost'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_USER=$(grep "'dbuser'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_PASSWORD=$(grep "'dbpassword'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

# Enable maintenance mode
sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --on

# Create backup directory
sudo mkdir -p "$BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX"

# Copy data directory
sudo rsync -Aax "$DATA_DIR/" "$BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX/data/"

# Copy config directory
sudo rsync -Aax --exclude='data' "$NEXTCLOUD_DIR/config/" "$BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX/config/"

# Take database snapshot
CREDENTIALS_FILE="/tmp/.my.cnf"
echo "[client]
user=$DB_USER
password=$DB_PASSWORD
host=$DB_HOST" > "$CREDENTIALS_FILE"

sudo mysqldump --defaults-file="$CREDENTIALS_FILE" --single-transaction --default-character-set=utf8mb4 "$DB_NAME" > "$BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX/nextcloud-sqlbkp.bak"
rm -f "$CREDENTIALS_FILE"

# Create tarball of backup directory
sudo tar -czf "$BACKUP_DIR/nextcloud_backup_$BACKUP_DIR_DATE_SUFFIX.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DIR_DATE_SUFFIX"

# Cleanup backup directory
if [ $? -eq 0 ]; then
    sudo rm -rf "$BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX"
else
    echo "Compression failed, not cleaning up intermediate files!" >&2
    exit 1
fi

# Disable maintenance mode
sudo -u www-data php --define apc.enable_cli=1 "$NEXTCLOUD_DIR/occ" maintenance:mode --off

# Measure end time and calculate total duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print total time taken
echo "Backup completed in $DURATION seconds."
