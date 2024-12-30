#!/bin/bash

# Script to stop Nextcloud server

# Arguments
ENCRYPTED_DRIVE="$1"

if [ -z "$ENCRYPTED_DRIVE" ] ; then
    echo "Usage: $0 <encrypted-drive>"
    exit 1
fi

# Stop Apache server
echo "Stopping Apache server"
sudo systemctl apache2

# Unmount encrypted drive
echo "Unmounting encrypted drive"
sudo umount /mnt/data-drive
sudo cryptsetup luksClose data-drive

