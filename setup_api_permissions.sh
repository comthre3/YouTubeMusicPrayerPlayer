#!/bin/bash
# Setup sudo permissions for prayer-player API control

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo bash setup_api_permissions.sh"
    exit 1
fi

echo "Setting up API permissions..."

# Remove old file if exists
rm -f /etc/sudoers.d/prayer-api

# Create sudoers file with proper permissions
cat > /etc/sudoers.d/prayer-api << 'SUDOERS_EOF'
ahmed ALL=(ALL) NOPASSWD: /bin/systemctl start prayer-player.service, /bin/systemctl stop prayer-player.service, /bin/systemctl restart prayer-player.service, /bin/systemctl is-active prayer-player.service, /bin/systemctl status prayer-player.service
SUDOERS_EOF

# Set correct permissions
chmod 0440 /etc/sudoers.d/prayer-api

# Verify syntax
if visudo -c -f /etc/sudoers.d/prayer-api; then
    echo "✓ Sudoers file created successfully"

    # Restart API service
    echo "Restarting prayer_api.service..."
    systemctl restart prayer_api.service

    echo "✓ Setup complete!"
    echo ""
    echo "The API can now control the prayer-player service."
    echo "Refresh your web dashboard to see the changes."
else
    echo "✗ Error in sudoers file syntax"
    rm -f /etc/sudoers.d/prayer-api
    exit 1
fi
