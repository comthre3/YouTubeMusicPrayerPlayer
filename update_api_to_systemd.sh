#!/bin/bash
# Update API from VLC-based to systemd-based version

set -e

API_DIR="/home/ahmed/prayer-player-dashboard/api"
API_FILE="$API_DIR/prayer_api.py"

if [ ! -d "$API_DIR" ]; then
    echo "Creating API directory..."
    mkdir -p "$API_DIR"
fi

echo "Backing up old API..."
if [ -f "$API_FILE" ]; then
    cp "$API_FILE" "$API_FILE.old-vlc-version"
fi

echo "Downloading new systemd-based API..."
cat > "$API_FILE" << 'APIEOF'
#!/usr/bin/env python3
"""
Flask API for Prayer Player Control
Lightweight REST API to control yt-dlp + ffplay based prayer player
"""

import json
import os
import subprocess
import re
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS
import psutil
import requests

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# Configuration - Use actual config from main project
CONFIG_FILE = os.path.expanduser("~/YouTubeMusicPrayerPlayer/config.json")
SERVICE_NAME = "prayer-player.service"

# Default configuration
DEFAULT_CONFIG = {
    "playlist_url": "",
    "city": "Kuwait City",
    "country": "Kuwait",
    "method": 4,
    "prayer_duration_minutes": 15,
    "volume": 90,
    "log_level": "INFO",
    "check_interval_seconds": 30
}


def load_config():
    """Load configuration from file"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                for key, value in DEFAULT_CONFIG.items():
                    if key not in config:
                        config[key] = value
                return config
    except Exception as e:
        print(f"Error loading config: {e}")
    return DEFAULT_CONFIG.copy()


def save_config(config):
    """Save configuration to file"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except Exception as e:
        print(f"Error saving config: {e}")
        return False


def get_service_status():
    """Check if prayer-player systemd service is running"""
    try:
        result = subprocess.run(
            ['sudo', 'systemctl', 'is-active', SERVICE_NAME],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() == 'active'
    except Exception as e:
        print(f"Error checking service status: {e}")
        return False


def get_ffplay_pid():
    """Find ffplay process PID"""
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            if proc.info['name'] == 'ffplay':
                # Verify it's part of our player
                cmdline = proc.info.get('cmdline', [])
                if any('googlevideo.com' in arg or '-nodisp' in arg for arg in cmdline):
                    return proc.info['pid']
    except Exception:
        pass
    return None


def get_player_python_pid():
    """Find the main prayer_player.py process"""
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            if proc.info['name'] == 'python3':
                cmdline = proc.info.get('cmdline', [])
                if any('prayer_player.py' in arg for arg in cmdline):
                    return proc.info['pid']
    except Exception:
        pass
    return None


def get_prayer_times():
    """Fetch prayer times from Aladhan API"""
    config = load_config()
    try:
        today = datetime.now().strftime('%d-%m-%Y')
        url = f"http://api.aladhan.com/v1/timingsByCity/{today}"
        params = {
            'city': config['city'],
            'country': config['country'],
            'method': config['method']
        }

        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()

        if data['code'] == 200:
            timings = data['data']['timings']
            return {
                'Fajr': timings['Fajr'],
                'Dhuhr': timings['Dhuhr'],
                'Asr': timings['Asr'],
                'Maghrib': timings['Maghrib'],
                'Isha': timings['Isha']
            }
    except Exception as e:
        print(f"Error fetching prayer times: {e}")
    return None


@app.route('/status', methods=['GET'])
def get_status():
    """Get current player status"""
    config = load_config()
    service_running = get_service_status()
    ffplay_pid = get_ffplay_pid()
    player_pid = get_player_python_pid()

    # Service running + ffplay present = playing
    # Service running + no ffplay = paused/between tracks
    playing = service_running and ffplay_pid is not None

    return jsonify({
        "player_running": service_running,
        "playing": playing,
        "paused": service_running and not playing,
        "current_track": 0,  # Basic player doesn't track this
        "total_tracks": 0,   # Basic player doesn't track this
        "playlist_url": config.get('playlist_url', ''),
        "last_update": datetime.now().isoformat()
    })


@app.route('/control/pause', methods=['POST'])
def pause_playback():
    """Pause playback by stopping the service"""
    if get_service_status():
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'stop', SERVICE_NAME],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                return jsonify({"success": True, "message": "Playback paused"})
            else:
                return jsonify({"success": False, "error": "Failed to stop service"}), 500
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500
    return jsonify({"success": False, "message": "Player not running"}), 404


@app.route('/control/resume', methods=['POST'])
def resume_playback():
    """Resume playback by starting the service"""
    if not get_service_status():
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'start', SERVICE_NAME],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                return jsonify({"success": True, "message": "Playback resumed"})
            else:
                return jsonify({"success": False, "error": "Failed to start service"}), 500
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500
    return jsonify({"success": True, "message": "Already playing"})


@app.route('/control/stop', methods=['POST'])
def stop_playback():
    """Stop playback completely"""
    if get_service_status():
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'stop', SERVICE_NAME],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                return jsonify({"success": True, "message": "Playback stopped"})
            else:
                return jsonify({"success": False, "error": "Failed to stop service"}), 500
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500
    return jsonify({"success": False, "message": "Player not running"}), 404


@app.route('/playlist/change', methods=['POST'])
def change_playlist():
    """Change to a new YouTube playlist URL"""
    data = request.get_json()
    new_url = data.get('url')

    if not new_url:
        return jsonify({"success": False, "error": "No URL provided"}), 400

    # Validate URL format
    if 'youtube.com/playlist' not in new_url and 'youtu.be' not in new_url:
        return jsonify({"success": False, "error": "Invalid YouTube URL"}), 400

    # Update config file
    config = load_config()
    config['playlist_url'] = new_url

    if not save_config(config):
        return jsonify({"success": False, "error": "Failed to save configuration"}), 500

    # Restart service to apply changes
    try:
        subprocess.run(
            ['sudo', 'systemctl', 'restart', SERVICE_NAME],
            capture_output=True,
            text=True,
            timeout=10
        )
        return jsonify({
            "success": True,
            "message": "Playlist updated and player restarted",
            "url": new_url
        })
    except Exception as e:
        return jsonify({
            "success": True,
            "message": f"Playlist updated but restart failed: {str(e)}. Please restart manually.",
            "url": new_url
        })


@app.route('/prayer-times', methods=['GET'])
def get_prayer_times_route():
    """Get today's prayer times"""
    config = load_config()
    prayer_times = get_prayer_times()

    if prayer_times:
        return jsonify({
            "success": True,
            "prayer_times": prayer_times,
            "location": {
                "city": config['city'],
                "country": config['country']
            },
            "pause_duration": config.get('prayer_duration_minutes', config.get('pause_duration_minutes', 15))
        })

    return jsonify({
        "success": False,
        "error": "Could not fetch prayer times"
    }), 500


@app.route('/config', methods=['GET'])
def get_config():
    """Get current configuration"""
    config = load_config()
    return jsonify(config)


@app.route('/config', methods=['POST'])
def update_config():
    """Update configuration"""
    data = request.get_json()
    config = load_config()

    # Update allowed fields
    allowed_fields = ['city', 'country', 'method', 'pause_duration_minutes']
    for field in allowed_fields:
        if field in data:
            config[field] = data[field]

    if save_config(config):
        return jsonify({"success": True, "message": "Configuration updated"})

    return jsonify({"success": False, "error": "Failed to save configuration"}), 500


@app.route('/volume', methods=['GET'])
def get_volume():
    """Get current system volume (0-100)"""
    try:
        result = subprocess.run(
            ['amixer', '-c', '0', 'sget', 'PCM'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            # Extract volume percentage from output like [77%]
            match = re.search(r'\[(\d+)%\]', result.stdout)
            if match:
                percentage = int(match.group(1))
                return jsonify({"success": True, "volume": percentage})

        return jsonify({"success": False, "error": "Could not read volume"}), 500
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/volume', methods=['POST'])
def set_volume():
    """Set system volume (0-100)"""
    try:
        data = request.get_json()
        volume = int(data.get('volume', 50))
        volume = max(0, min(100, volume))

        # Use simple percentage setting like volume_control.py
        result = subprocess.run(
            ['amixer', '-c', '0', 'sset', 'PCM', f'{volume}%'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            return jsonify({"success": True, "volume": volume})

        return jsonify({"success": False, "error": "Failed to set volume"}), 500
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})


if __name__ == '__main__':
    print("Starting Prayer Player API...")
    print("API will be available at http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
APIEOF

chmod +x "$API_FILE"
echo "✓ New API file created"

echo "Restarting prayer_api.service..."
sudo systemctl restart prayer_api.service

echo ""
echo "✓ API updated to systemd-based version!"
echo "Refresh your web dashboard to see the changes."
