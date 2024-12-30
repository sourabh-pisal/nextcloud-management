#!/bin/bash

# Script to start Nextcloud server

# Arguments
ENCRYPTED_DRIVE="$1"

if [ -z "$ENCRYPTED_DRIVE" ] ; then
    echo "Usage: $0 <encrypted-drive>"
    exit 1
fi

# Mount encrypted drive
echo "Mounting encrypted drive"
sudo cryptsetup luksOpen "$ENCRYPTED_DRIVE" data-drive
sudo mount -m /dev/mapper/data-drive /mnt/data-drive

# Start Apache server
echo "Starting Apache server"
sudo systemctl start apache2

