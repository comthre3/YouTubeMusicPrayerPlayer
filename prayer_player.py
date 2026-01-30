#!/usr/bin/env python3

import subprocess
import time
import signal
import sys
import random
import json
import os

# Configuration file path
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

def load_config():
    """Load configuration from config.json"""
    try:
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
            return config
    except Exception as e:
        print(f"Error loading config: {e}")
        # Fallback to default
        return {
            "playlist_url": "https://youtube.com/playlist?list=PLdngPVXnULzG9yhOaIpMwkAn_35OfEPyM"
        }

class PrayerPlayer:
    def __init__(self):
        self.video_urls = []
        self.running = True

        # Load playlist URL from config
        config = load_config()
        self.playlist_url = config.get('playlist_url', 'https://youtube.com/playlist?list=PLdngPVXnULzG9yhOaIpMwkAn_35OfEPyM')
        print(f"Loaded playlist URL: {self.playlist_url}")

        # Set up signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        print("\nShutting down gracefully...")
        self.running = False
        sys.exit(0)
    
    def get_video_urls_from_playlist(self):
        """Get list of individual video URLs from the playlist (these don't expire)"""
        print("Fetching playlist videos...")

        try:
            command = [
                'yt-dlp',
                '--flat-playlist',
                '--get-url',
                '--no-warnings',
                self.playlist_url
            ]
            
            result = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0 and result.stdout.strip():
                urls = [url.strip() for url in result.stdout.strip().split('\n') if url.strip()]
                print(f"Found {len(urls)} videos in playlist")
                return urls
            else:
                print(f"Error fetching playlist: {result.stderr}")
                return []
                
        except Exception as e:
            print(f"Error: {e}")
            return []
    
    def play_video(self, video_url, track_num, total):
        """Fetch stream URL and play immediately (URLs expire in seconds)"""
        print(f"\nPlaying track {track_num}/{total}")
        
        try:
            # This is the working command: run yt-dlp and ffplay together as root
            # Stream URLs expire quickly, so we must fetch and play in one pipeline
            bash_command = f"yt-dlp --get-url --format bestaudio '{video_url}' | xargs -I {{}} ffplay -nodisp -autoexit -loglevel error {{}}"
            
            command = ['sudo', 'bash', '-c', bash_command]
            
            result = subprocess.run(command)
            
            if result.returncode == 0:
                print("✓ Track completed")
            else:
                print(f"Track ended with code: {result.returncode}")
                
        except Exception as e:
            print(f"Error playing track: {e}")
    
    def run(self):
        """Main loop to play the playlist continuously"""
        print("=== Prayer Player Starting ===\n")
        
        # Get list of video URLs (these are stable and don't expire)
        self.video_urls = self.get_video_urls_from_playlist()
        
        if not self.video_urls:
            print("\nFailed to load playlist")
            print("Possible fixes:")
            print("1. Check your internet connection")
            print("2. Update yt-dlp: pip install -U yt-dlp")
            print("3. Verify the playlist URL is correct")
            return
        
        print(f"\nStarting playback of {len(self.video_urls)} tracks")
        print("Press Ctrl+C to stop\n")
        
        try:
            while self.running:
                # Shuffle for each playthrough
                random.shuffle(self.video_urls)
                print(f"\n--- Starting playlist ({len(self.video_urls)} tracks, shuffled) ---")
                
                # Play each video
                for i, video_url in enumerate(self.video_urls, 1):
                    if not self.running:
                        break
                    
                    self.play_video(video_url, i, len(self.video_urls))
                
                if self.running:
                    print(f"\n--- Playlist complete, restarting... ---")
                    time.sleep(2)
                    
        except KeyboardInterrupt:
            print("\nPlayback stopped by user")
        except Exception as e:
            print(f"Unexpected error: {e}")

if __name__ == "__main__":
    player = PrayerPlayer()
    player.run()
