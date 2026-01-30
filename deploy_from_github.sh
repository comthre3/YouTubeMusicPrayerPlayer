#!/bin/bash

# Deployment script for YouTube Music Prayer Player
# Stops services, backs up current installation, and deploys from GitHub

set -e  # Exit on any error

GITHUB_REPO="https://github.com/comthre3/YouTubeMusicPrayerPlayer.git"
INSTALL_DIR="/home/ahmed/YouTubeMusicPrayerPlayer"
BACKUP_DIR="/home/ahmed/YouTubeMusicPrayerPlayer_backup_$(date +%Y%m%d_%H%M%S)"
CONFIG_BACKUP="/tmp/config.json.backup"

echo "========================================="
echo "YouTube Music Prayer Player Deployment"
echo "========================================="
echo ""

# Check if running as sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo"
    echo "Usage: sudo bash deploy_from_github.sh"
    exit 1
fi

# List of services to manage
SERVICES=(
    "prayer-player.service"
    "prayer_player.service"
    "prayer.service"
    "prayer_api.service"
    "prayer-dashboard.service"
)

echo "Step 1: Checking and stopping services..."
echo "-----------------------------------------"
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "  Stopping $service..."
        systemctl stop "$service"
        echo "  ✓ $service stopped"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "  $service exists but not running (will disable)"
        systemctl disable "$service" 2>/dev/null || true
    else
        echo "  $service not found (skipping)"
    fi
done
echo ""

# Check for Docker containers (dashboard)
echo "Step 2: Checking for Docker containers..."
echo "-----------------------------------------"
if command -v docker &> /dev/null; then
    DASHBOARD_CONTAINERS=$(docker ps -a --filter "name=prayer" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$DASHBOARD_CONTAINERS" ]; then
        echo "  Found prayer-related containers:"
        echo "$DASHBOARD_CONTAINERS" | while read container; do
            echo "    - $container"
            docker stop "$container" 2>/dev/null || true
        done
        echo "  ✓ Docker containers stopped"
    else
        echo "  No prayer-related Docker containers found"
    fi
else
    echo "  Docker not installed (skipping)"
fi
echo ""

# Backup config.json if it exists
echo "Step 3: Backing up configuration..."
echo "-----------------------------------------"
if [ -f "$INSTALL_DIR/config.json" ]; then
    cp "$INSTALL_DIR/config.json" "$CONFIG_BACKUP"
    echo "  ✓ config.json backed up to $CONFIG_BACKUP"
else
    echo "  No config.json found (will use default)"
fi
echo ""

# Backup current installation
echo "Step 4: Backing up current installation..."
echo "-----------------------------------------"
if [ -d "$INSTALL_DIR" ]; then
    echo "  Moving $INSTALL_DIR to $BACKUP_DIR..."
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    echo "  ✓ Backup saved to: $BACKUP_DIR"
else
    echo "  No existing installation found"
fi
echo ""

# Clone fresh from GitHub
echo "Step 5: Cloning from GitHub..."
echo "-----------------------------------------"
echo "  Repository: $GITHUB_REPO"
git clone "$GITHUB_REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo "  ✓ Repository cloned successfully"
echo ""

# Restore config.json
echo "Step 6: Restoring configuration..."
echo "-----------------------------------------"
if [ -f "$CONFIG_BACKUP" ]; then
    cp "$CONFIG_BACKUP" "$INSTALL_DIR/config.json"
    echo "  ✓ config.json restored"
    rm "$CONFIG_BACKUP"
else
    echo "  Using default config.json from repository"
fi
echo ""

# Set proper permissions
echo "Step 7: Setting permissions..."
echo "-----------------------------------------"
chown -R ahmed:ahmed "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.py
chmod +x "$INSTALL_DIR"/*.sh
echo "  ✓ Permissions set"
echo ""

# Install Python dependencies
echo "Step 8: Installing dependencies..."
echo "-----------------------------------------"
if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    echo "  Installing Python packages..."
    pip3 install -r "$INSTALL_DIR/requirements.txt" --upgrade
    echo "  ✓ Python dependencies installed"
else
    echo "  No requirements.txt found"
    echo "  Installing essential packages..."
    pip3 install requests --upgrade
fi

echo "  Updating yt-dlp..."
pip3 install -U yt-dlp
echo "  ✓ yt-dlp updated"
echo ""

# Setup systemd service
echo "Step 9: Setting up systemd service..."
echo "-----------------------------------------"
if [ ! -f "/etc/systemd/system/prayer-player.service" ]; then
    echo "  Creating prayer-player.service..."
    cat > /etc/systemd/system/prayer-player.service << 'EOF'
[Unit]
Description=YouTube Music Prayer Player
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ahmed/YouTubeMusicPrayerPlayer
ExecStart=/usr/bin/python3 /home/ahmed/YouTubeMusicPrayerPlayer/prayer_player.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo "  ✓ Service file created"
else
    echo "  Service file already exists"
    systemctl daemon-reload
fi
echo ""

# Start the service
echo "Step 10: Starting prayer-player service..."
echo "-----------------------------------------"
systemctl enable prayer-player.service
systemctl start prayer-player.service
sleep 2
if systemctl is-active --quiet prayer-player.service; then
    echo "  ✓ prayer-player.service is running"
else
    echo "  ⚠ WARNING: prayer-player.service may not have started properly"
    echo "  Check logs: sudo journalctl -u prayer-player.service -n 50"
fi
echo ""

# Update prayer times
echo "Step 11: Updating prayer times..."
echo "-----------------------------------------"
if [ -f "$INSTALL_DIR/update_prayer_times.py" ]; then
    cd "$INSTALL_DIR"
    python3 update_prayer_times.py
    echo "  ✓ Prayer times updated"
else
    echo "  ⚠ update_prayer_times.py not found"
fi
echo ""

# Summary
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Old installation backed up to: $BACKUP_DIR"
echo "  - New installation from GitHub: $GITHUB_REPO"
echo "  - Service status: $(systemctl is-active prayer-player.service)"
echo ""
echo "Useful commands:"
echo "  Check status:  sudo systemctl status prayer-player.service"
echo "  View logs:     sudo journalctl -u prayer-player.service -f"
echo "  Stop service:  sudo systemctl stop prayer-player.service"
echo "  Start service: sudo systemctl start prayer-player.service"
echo ""
echo "If you need to rollback:"
echo "  sudo systemctl stop prayer-player.service"
echo "  sudo rm -rf $INSTALL_DIR"
echo "  sudo mv $BACKUP_DIR $INSTALL_DIR"
echo "  sudo systemctl start prayer-player.service"
echo ""
