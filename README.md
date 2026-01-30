# YouTube Music Prayer Player for Raspberry Pi

A Raspberry Pi system that continuously plays music from YouTube playlists and automatically pauses during Islamic prayer times. Features a web dashboard for remote control.

## Features

- 🎵 **Continuous YouTube Playlist Playback** - Uses yt-dlp + ffplay for reliable audio streaming
- 🕌 **Automatic Prayer Time Pauses** - Fetches daily prayer times and pauses for 15 minutes during each prayer
- 🌐 **Web Dashboard** - Control playback, change playlists, and adjust volume from any device
- 📱 **Remote Control** - Pause/resume/stop playback via web interface
- 🔊 **Volume Control** - System-wide volume adjustment
- 📡 **WiFi Manager** - Easy WiFi setup for headless operation
- 💾 **Persistent Settings** - Playlist and configuration survive reboots

## System Components

### Main Player (`prayer_player.py`)
- Fetches YouTube playlist videos using yt-dlp
- Plays audio streams via ffplay
- Loads playlist URL from config.json
- Runs as systemd service

### Prayer Times Manager (`update_prayer_times.py`)
- Fetches daily prayer times from Aladhan API
- Updates crontab with 5 daily prayer schedules
- Automatically pauses player for 15 minutes during prayers

### Volume Control (`volume_control.py`)
- CLI tool for adjusting system volume (0-100%)
- Uses ALSA amixer for hardware volume control

### WiFi Manager (`wifi_manager.py`)
- Interactive WiFi configuration for headless setup
- Uses NetworkManager (nmcli)

### Web Dashboard
Located in separate `/home/ahmed/prayer-player-dashboard/` directory:
- **React Frontend** - Modern UI for player control
- **Flask API** - REST API for player management
- **Docker Container** - Runs on port 8080

## Installation

### Prerequisites
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip ffmpeg alsa-utils network-manager docker.io docker-compose

# Install yt-dlp
sudo pip3 install -U yt-dlp

# Install Python dependencies
sudo pip3 install requests flask flask-cors psutil
```

### Setup

1. **Clone the repository**
```bash
cd ~
git clone <your-github-repo-url>
cd YouTubeMusicPrayerPlayer
```

2. **Configure settings**
Edit `config.json`:
```json
{
  "playlist_url": "https://youtube.com/playlist?list=YOUR_PLAYLIST_ID",
  "city": "Kuwait City",
  "country": "Kuwait",
  "method": 4,
  "prayer_duration_minutes": 15,
  "volume": 90,
  "log_level": "INFO",
  "check_interval_seconds": 30
}
```

3. **Set up systemd service**
```bash
sudo cp /home/ahmed/YouTubeMusicPrayerPlayer/prayer-player.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable prayer-player.service
sudo systemctl start prayer-player.service
```

4. **Configure sudoers for passwordless control**
```bash
echo 'ahmed ALL=(ALL) NOPASSWD: /bin/systemctl stop prayer-player.service, /bin/systemctl start prayer-player.service, /bin/systemctl restart prayer-player.service' | sudo tee /etc/sudoers.d/prayer-player
echo 'ahmed ALL=(ALL) NOPASSWD: /usr/bin/ffplay' | sudo tee -a /etc/sudoers.d/prayer-player
sudo chmod 0440 /etc/sudoers.d/prayer-player
```

5. **Set up prayer time automation**
```bash
# Add to crontab to update prayer times daily at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * cd /home/ahmed/YouTubeMusicPrayerPlayer && python3 update_prayer_times.py >> prayer_times.log 2>&1") | crontab -

# Run once to set up today's prayer times
python3 update_prayer_times.py
```

6. **Set up web dashboard** (optional)
```bash
cd /home/ahmed/prayer-player-dashboard
sudo docker-compose up -d --build
```

Dashboard will be available at `http://<raspberry-pi-ip>:8080`

## Usage

### Command Line

**Check player status:**
```bash
sudo systemctl status prayer-player.service
```

**View player logs:**
```bash
sudo journalctl -u prayer-player.service -f
```

**Control volume:**
```bash
# Get current volume
./volume_control.py

# Set volume to 75%
./volume_control.py 75

# Increase by 5%
./volume_control.py +

# Decrease by 10%
./volume_control.py --
```

**Update prayer times:**
```bash
python3 update_prayer_times.py
```

### Web Dashboard

Access at `http://<raspberry-pi-ip>:8080`

Features:
- Real-time playback status
- Play/Pause/Stop controls
- Playlist URL management (changes persist across reboots)
- Volume slider
- Prayer times display

## Configuration

### Prayer Time Settings

The `config.json` file contains:
- `city` / `country`: Location for prayer times
- `method`: Calculation method (4 = Umm Al-Qura, Makkah)
- `prayer_duration_minutes`: How long to pause (default: 15)

Available calculation methods:
- 1: University of Islamic Sciences, Karachi
- 2: Islamic Society of North America
- 3: Muslim World League
- 4: Umm Al-Qura University, Makkah
- 5: Egyptian General Authority of Survey

### Changing Playlist

**Via Web Dashboard:**
1. Open dashboard at `http://<pi-ip>:8080`
2. Enter new YouTube playlist URL
3. Click "Update Playlist"
4. Player automatically restarts with new playlist

**Via Command Line:**
1. Edit `config.json`
2. Update `playlist_url` field
3. Restart service: `sudo systemctl restart prayer-player.service`

## File Structure

```
YouTubeMusicPrayerPlayer/
├── prayer_player.py          # Main player script
├── config.json                # Configuration file
├── update_prayer_times.py     # Prayer time scheduler
├── pause_for_prayer.sh        # Prayer pause handler script
├── volume_control.py          # Volume control CLI
├── wifi_manager.py            # WiFi setup tool
├── CLAUDE.md                  # Development instructions
├── README.md                  # This file
└── NOT_IMPORTANT/             # Archived old files
```

## Troubleshooting

### Player won't start
```bash
# Update yt-dlp
sudo pip3 install -U yt-dlp

# Check internet connection
ping -c 3 google.com

# Verify playlist URL
yt-dlp --flat-playlist --get-url "YOUR_PLAYLIST_URL"
```

### No audio output
```bash
# Test audio
speaker-test -t wav -c 2

# Check volume
amixer -c 0 sget PCM

# Set volume
amixer -c 0 sset PCM 80%
```

### Prayer times not updating
```bash
# Test API access
curl "http://api.aladhan.com/v1/status"

# Check cron
crontab -l

# Run manually
python3 update_prayer_times.py
```

### Dashboard not accessible
```bash
# Check Docker
docker ps

# Check API
curl http://localhost:5000/status

# Restart dashboard
cd /home/ahmed/prayer-player-dashboard
sudo docker-compose restart
```

## API Endpoints

The Flask API (port 5000) provides:

- `GET /status` - Player status
- `POST /control/pause` - Pause playback
- `POST /control/resume` - Resume playback
- `POST /control/stop` - Stop playback
- `POST /playlist/change` - Update playlist URL
- `GET /prayer-times` - Get today's prayer times
- `GET /volume` - Get current volume
- `POST /volume` - Set volume

## Hardware Requirements

- Raspberry Pi 3 or newer
- MicroSD card (8GB minimum)
- Audio output (3.5mm jack, HDMI, or USB audio)
- Internet connection (WiFi or Ethernet)

## Credits

Built with:
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - YouTube downloader
- [FFmpeg](https://ffmpeg.org/) - Audio playback
- [Flask](https://flask.palletsprojects.com/) - Web API
- [React](https://react.dev/) - Dashboard UI
- [Aladhan API](https://aladhan.com/prayer-times-api) - Prayer times

## License

MIT License - Feel free to use and modify for your own projects.

## Support

For issues and questions, please open an issue on GitHub.
