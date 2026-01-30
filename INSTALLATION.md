# Quick Installation Guide

Follow these steps to set up the Prayer Player on a fresh Raspberry Pi.

## 1. Initial System Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required system packages
sudo apt install -y python3 python3-pip ffmpeg alsa-utils network-manager git

# Install yt-dlp
sudo pip3 install -U yt-dlp

# Install Python dependencies
sudo pip3 install requests flask flask-cors psutil
```

## 2. Clone Repository

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/YouTubeMusicPrayerPlayer.git
cd YouTubeMusicPrayerPlayer
```

## 3. Configure Settings

Edit `config.json` with your preferences:
```bash
nano config.json
```

Change:
- `playlist_url`: Your YouTube playlist URL
- `city` and `country`: Your location for prayer times
- `volume`: Initial volume (0-100)

## 4. Set Up Player Service

```bash
# Copy service file
sudo cp prayer-player.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable prayer-player.service

# Start the service
sudo systemctl start prayer-player.service

# Check status
sudo systemctl status prayer-player.service
```

## 5. Configure Sudoers (for web dashboard control)

```bash
# Create sudoers file
echo 'ahmed ALL=(ALL) NOPASSWD: /bin/systemctl stop prayer-player.service, /bin/systemctl start prayer-player.service, /bin/systemctl restart prayer-player.service' | sudo tee /etc/sudoers.d/prayer-player

echo 'ahmed ALL=(ALL) NOPASSWD: /usr/bin/ffplay' | sudo tee -a /etc/sudoers.d/prayer-player

# Set correct permissions
sudo chmod 0440 /etc/sudoers.d/prayer-player
```

**Important:** Replace `ahmed` with your actual username if different!

## 6. Set Up Prayer Time Automation

```bash
# Run once to set up today's prayer times
python3 update_prayer_times.py

# Add to crontab for daily updates at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * cd ~/YouTubeMusicPrayerPlayer && python3 update_prayer_times.py >> prayer_times.log 2>&1") | crontab -

# Verify crontab entry
crontab -l
```

## 7. Set Up Web Dashboard (Optional)

### Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install docker-compose
sudo apt install -y docker-compose

# Log out and back in for group changes to take effect
```

### Clone and Set Up Dashboard
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/prayer-player-dashboard.git
cd prayer-player-dashboard

# Build and start dashboard
sudo docker-compose up -d --build
```

The dashboard will be available at `http://<raspberry-pi-ip>:8080`

### Set Up Dashboard API Service
```bash
# Install Python dependencies for API
cd ~/prayer-player-dashboard
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors psutil requests

# Create API service file
sudo nano /etc/systemd/system/prayer_api.service
```

Paste this content:
```ini
[Unit]
Description=Prayer Player Flask API
After=network.target

[Service]
Type=simple
User=ahmed
WorkingDirectory=/home/ahmed/prayer-player-dashboard/api
Environment="PATH=/home/ahmed/prayer-player-dashboard/venv/bin"
ExecStart=/home/ahmed/prayer-player-dashboard/venv/bin/python3 /home/ahmed/prayer-player-dashboard/api/prayer_api.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Then:
```bash
# Enable and start API service
sudo systemctl daemon-reload
sudo systemctl enable prayer_api.service
sudo systemctl start prayer_api.service
```

## 8. WiFi Setup (If Needed)

For headless WiFi setup:
```bash
sudo python3 wifi_manager.py
```

## Verification

### Check Player Status
```bash
sudo systemctl status prayer-player.service
```

### Check Logs
```bash
# Player logs
sudo journalctl -u prayer-player.service -f

# API logs
sudo journalctl -u prayer_api.service -f
```

### Test Volume Control
```bash
./volume_control.py
./volume_control.py 75
```

### Access Dashboard
Open browser: `http://<raspberry-pi-ip>:8080`

## Troubleshooting

### Player Not Starting
```bash
# Check for errors
sudo journalctl -u prayer-player.service -n 50

# Update yt-dlp
sudo pip3 install -U yt-dlp

# Restart service
sudo systemctl restart prayer-player.service
```

### No Audio
```bash
# Test audio hardware
speaker-test -t wav -c 2

# Check and set volume
amixer -c 0 sget PCM
amixer -c 0 sset PCM 80%
```

### Dashboard Not Working
```bash
# Check Docker
docker ps

# Check API
curl http://localhost:5000/status

# Restart services
sudo systemctl restart prayer_api.service
cd ~/prayer-player-dashboard && sudo docker-compose restart
```

## Auto-Start on Boot

All services are configured to start automatically:
- `prayer-player.service` - Main player
- `prayer_api.service` - Web API
- Docker containers - Dashboard

To disable auto-start:
```bash
sudo systemctl disable prayer-player.service
```

## Next Steps

1. Test the player is working
2. Access the web dashboard
3. Change the playlist via dashboard to verify persistence
4. Verify prayer times are scheduling correctly: `crontab -l`

You're all set! The player will now start automatically on every boot.
