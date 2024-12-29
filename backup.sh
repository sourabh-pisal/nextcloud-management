# Script to backup nextcloud data, database and config files

# Arguments
NEXTCLOUD_DIR="$1"
BACKUP_DIR="$2"
BACKUP_DIR_DATE_SUFFIX=$(date +%Y%m%d)

CONFIG_FILE=$NEXTCLOUD_DIR/config/config.php
DATA_DIR=$(grep "'datadirectory'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

DB_NAME=$(grep "'dbname'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_HOST=$(grep "'dbhost'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_USER=$(grep "'dbuser'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")
DB_PASSWORD=$(grep "'dbpassword'" "$CONFIG_FILE" | awk -F "=> " '{print $2}' | tr -d "', ")

# Enable maintenance mode
sudo -u www-data php --define apc.enable_cli=1 /var/www/nextcloud/occ maintenance:mode --on

# create backup directory
mkdir -p $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX

# Change dir to backup directory
cd $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX

# Copy data directory
rsync -Aax $DATA_DIR/ $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX/data/

# Copy config directory
rsync -Aax --exclude='data' $CONFIG_DIR/ $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX/config/

# Taking snapshot of database
mysqldump --single-transaction -default-character-set=utf8mb4 -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME > nextcloud-sqlbkp.bak

# Change to home directory
cd

# Create zip of backup directory
zip -rq $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX $BACKUP_DIR_DATE_SUFFIX

# Cleanup backup directory
rm -rf $BACKUP_DIR/$BACKUP_DIR_DATE_SUFFIX

# Disable maintenance mode
sudo -u www-data php --define apc.enable_cli=1 /var/www/nextcloud/occ maintenance:mode --off
