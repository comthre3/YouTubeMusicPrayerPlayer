#!/bin/bash
# Pauses the prayer player for 15 minutes

echo "[$(date)] Prayer time - pausing music for 15 minutes" >> /home/ahmed/YouTubeMusicPrayerPlayer/prayer_pause.log

# Stop the prayer player service
sudo systemctl stop prayer-player.service

# Wait 15 minutes
sleep 900

# Restart the prayer player service
sudo systemctl start prayer-player.service

echo "[$(date)] Prayer pause complete - music resumed" >> /home/ahmed/YouTubeMusicPrayerPlayer/prayer_pause.log
