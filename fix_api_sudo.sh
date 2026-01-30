#!/bin/bash
# Fix API to use sudo for systemctl commands

set -e

API_FILE="/home/ahmed/prayer-player-dashboard/api/prayer_api.py"

if [ ! -f "$API_FILE" ]; then
    echo "Error: $API_FILE not found"
    exit 1
fi

echo "Fixing API to use sudo for systemctl commands..."

# Backup original file
cp "$API_FILE" "$API_FILE.backup"

# Fix the get_service_status function
sed -i "s/\['systemctl', 'is-active', SERVICE_NAME\]/\['sudo', 'systemctl', 'is-active', SERVICE_NAME\]/" "$API_FILE"

echo "✓ API file updated"
echo "✓ Backup saved to $API_FILE.backup"

# Restart API service
echo "Restarting prayer_api.service..."
sudo systemctl restart prayer_api.service

echo "✓ Done! Refresh your web dashboard."
