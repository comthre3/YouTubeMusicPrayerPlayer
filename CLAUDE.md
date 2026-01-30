# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

YouTube Music Prayer Player is a Raspberry Pi system that continuously plays music from a YouTube playlist and automatically pauses during Islamic prayer times. The system consists of:

1. **Prayer Player** - Core Python service that plays YouTube playlists using yt-dlp and ffplay
2. **Prayer Times Manager** - Fetches daily prayer times and schedules automatic pauses via cron
3. **Web Dashboard** - React/TypeScript dashboard with Flask API for remote control
4. **WiFi Manager** - Interactive WiFi configuration tool for headless setup

## System Architecture

### Main Components

**prayer_player.py** - The primary music player
- Fetches YouTube playlist videos using yt-dlp's `--flat-playlist` mode
- Plays audio streams by piping yt-dlp output directly to ffplay
- Runs as systemd service `prayer_player.service`
- Stream URLs expire quickly, so fetch and play must happen in single pipeline
- Uses `sudo bash -c` to run the yt-dlp | ffplay pipeline with proper permissions

**update_prayer_times.py** - Prayer time scheduler
- Fetches daily prayer times from Aladhan API (http://api.aladhan.com)
- Updates crontab with 5 daily prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha)
- Each prayer triggers `pause_for_prayer.sh` which stops the service for 15 minutes
- Should be run daily via cron (typically at 3 AM)

**pause_for_prayer.sh** - Prayer pause handler
- Stops `prayer-player.service` systemd service
- Waits 900 seconds (15 minutes)
- Restarts the service
- Logs all activity to `prayer_pause.log`

**volume_control.py** - System volume control
- Uses `amixer` to control ALSA PCM volume (0-100%)
- Supports direct volume setting, increment/decrement operations
- Works with Raspberry Pi audio hardware

**wifi_manager.py** - Network configuration
- Interactive WiFi setup using NetworkManager (nmcli)
- Saves network credentials to JSON for auto-reconnect
- Must run with sudo/root permissions

### Web Dashboard (prayer-player-dashboard/)

Located in separate directory at `/home/ahmed/prayer-player-dashboard/`

**Flask API** (prayer_api.service)
- REST API on port 5000
- Endpoints: /status, /control/pause, /control/resume, /control/stop, /volume, /prayer-times
- Uses psutil to detect running processes (VLC, player)
- Volume control via amixer subprocess calls

**React Dashboard**
- TypeScript + Vite + React
- Components: StatusDisplay, ControlPanel, VolumeControl, PrayerTimesDisplay, PlaylistManager
- Runs in Docker container with nginx proxy
- API requests proxied through nginx at /api

### Systemd Services

Active services:
- `prayer-player.service` - Main player service running prayer_player.py from this directory
- `prayer_api.service` - Flask API backend for web dashboard (port 5000)
- `prayer-dashboard.service` - Docker container orchestration for React frontend

Legacy services (now disabled):
- `prayer_player.service` (underscore) - Duplicate pointing to prayer-player-dashboard/player/
- `prayer.service` - Duplicate FastAPI+VLC implementation from prayer-player-unified/

**Note:** Multiple prayer player implementations existed on this system using different approaches:
1. yt-dlp + ffplay (this codebase) - **ACTIVE**
2. VLC-based player (prayer-player-dashboard)
3. FastAPI + VLC (prayer-player-unified)

The duplicates have been disabled to prevent conflicts. The `pause_for_prayer.sh` script correctly targets `prayer-player.service`.

### Cron Jobs

Prayer time pauses are scheduled via crontab:
- Daily prayer time update at 3 AM
- Pause/resume pairs for each of 5 daily prayers
- Duration: 15 minutes per prayer

### Configuration Files

**config.json** - Player configuration
```json
{
  "playlist_url": "https://youtube.com/playlist?list=...",
  "city": "Kuwait City",
  "country": "Kuwait",
  "method": 4,
  "prayer_duration_minutes": 15,
  "volume": 90,
  "log_level": "INFO",
  "check_interval_seconds": 30
}
```

**playlist_cache.json** - Cached playlist data (auto-generated)

## Common Development Tasks

### Testing the Prayer Player

```bash
# Run player directly (not as service)
cd /home/ahmed/YouTubeMusicPrayerPlayer
sudo python3 prayer_player.py

# Check service status
sudo systemctl status prayer_player.service

# View service logs
sudo journalctl -u prayer_player.service -f

# View prayer pause logs
tail -f /home/ahmed/YouTubeMusicPrayerPlayer/prayer_pause.log
```

### Managing Services

```bash
# Restart prayer player
sudo systemctl restart prayer_player.service

# Restart API
sudo systemctl restart prayer_api.service

# Restart dashboard (Docker)
cd /home/ahmed/prayer-player-dashboard
sudo docker-compose restart
```

### Volume Control

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

### Prayer Times Management

```bash
# Update prayer times for today
cd /home/ahmed/YouTubeMusicPrayerPlayer
python3 update_prayer_times.py

# Check current crontab
crontab -l

# View prayer times log
tail -f prayer_times.log
```

### Web Dashboard Development

```bash
# Navigate to dashboard frontend
cd /home/ahmed/prayer-player-dashboard/dashboard/prayer-dashboard

# Install dependencies
npm install

# Development mode
npm run dev

# Build for production
npm run build

# Rebuild and restart Docker
cd /home/ahmed/prayer-player-dashboard
sudo docker-compose down
sudo docker-compose up -d --build
```

## Key Technical Details

### Audio Pipeline

The working audio playback command chain:
```bash
sudo bash -c "yt-dlp --get-url --format bestaudio 'VIDEO_URL' | xargs -I {} ffplay -nodisp -autoexit -loglevel error {}"
```

Why this specific approach:
- YouTube stream URLs expire in seconds after generation
- Must fetch and play in single pipeline, cannot pre-fetch
- Video URLs from `--flat-playlist` are stable and cached
- Stream URLs must be fetched fresh for each playback
- sudo required for audio device access on this system

### YouTube Playlist Handling

Two-stage process:
1. Fetch video URLs using `yt-dlp --flat-playlist --get-url` (cached)
2. For each play, fetch fresh stream URL and pipe to ffplay (not cached)

### Prayer Time API

Aladhan API format:
- Endpoint: `http://api.aladhan.com/v1/timingsByCity/DD-MM-YYYY`
- Parameters: city, country, method (calculation method)
- Method 4: Umm Al-Qura University, Makkah
- Returns 5 daily prayer times in HH:MM format

### Volume Control via ALSA

Uses amixer command: `amixer -c 0 sset PCM <volume>%`
- Card 0 is default Raspberry Pi audio
- PCM is the main output control
- Volume range: 0-100%

## Dependencies

### System Packages
- yt-dlp - YouTube video/audio downloader
- ffplay (from ffmpeg) - Audio playback
- vlc - Alternative player (used in some versions)
- amixer (from alsa-utils) - Volume control
- NetworkManager/nmcli - WiFi management
- docker, docker-compose - Dashboard hosting

### Python Packages
- requests - HTTP requests for prayer times API
- flask, flask-cors - REST API server
- psutil - Process management
- subprocess, signal, json, datetime (stdlib)

## File Organization

- `prayer_player.py` - Main entry point (current version)
- `pryaer_pleayer.py` - Alternative version with caching
- `update_prayer_times.py` - Prayer time scheduler
- `pause_for_prayer.sh` - Prayer pause script
- `volume_control.py` - Volume management CLI
- `wifi_manager.py` - WiFi setup tool
- `config.json` - Configuration
- `playlist_cache.json` - Cached playlist data
- `oldversions/` - Backup versions
- `prayer_player_backup_*/` - Timestamped backups
- `*.log` - Log files (prayer_times.log, prayer_pause.log)

## Deployment

Full deployment script: `ALL_IN_ONE_DEPLOY.sh`
- Cleans up old services
- Configures systemd auto-start for all services
- Updates Flask API with volume control
- Rebuilds React dashboard
- Restarts Docker containers

Dashboard accessible at: http://192.168.8.116:8080 (or current Pi IP)

## Troubleshooting

### Player won't start
- Check yt-dlp is updated: `sudo pip3 install -U yt-dlp`
- Verify internet connection
- Check playlist URL is valid
- Ensure sudo permissions for audio device access

### Volume control not working
- Verify amixer installed: `amixer --version`
- Check audio card: `amixer -c 0 sget PCM`
- Test with: `speaker-test -t wav -c 2`

### Prayer times not updating
- Check cron is running: `sudo systemctl status cron`
- Verify crontab entries: `crontab -l`
- Test manually: `python3 update_prayer_times.py`
- Check API access: `curl http://api.aladhan.com/v1/status`

### Dashboard not accessible
- Check Docker: `docker ps`
- Verify API: `curl http://localhost:5000/status`
- Check nginx logs: `docker logs prayer-player-dashboard_nginx_1`
- Rebuild: `cd prayer-player-dashboard && sudo docker-compose up -d --build`
