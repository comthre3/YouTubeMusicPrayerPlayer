#!/usr/bin/env python3
"""
Fetches daily prayer times for Kuwait and updates crontab to pause music during prayers
"""

import requests
import subprocess
import sys
from datetime import datetime

# Configuration
CITY = "Kuwait City"
COUNTRY = "Kuwait"
METHOD = 2  # Islamic Society of North America (ISNA)
PAUSE_SCRIPT = "/home/ahmed/YouTubeMusicPrayerPlayer/pause_for_prayer.sh"

def fetch_prayer_times():
    """Fetch today's prayer times from Aladhan API"""
    try:
        # Get current date
        now = datetime.now()
        
        # Aladhan API endpoint
        url = f"http://api.aladhan.com/v1/timingsByCity/{now.day}-{now.month}-{now.year}"
        params = {
            "city": CITY,
            "country": COUNTRY,
            "method": METHOD
        }
        
        print(f"Fetching prayer times for {CITY}, {COUNTRY}...")
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        if data['code'] != 200:
            print(f"API Error: {data}")
            return None
        
        timings = data['data']['timings']
        
        # Extract the 5 daily prayers
        prayer_times = {
            'Fajr': timings['Fajr'],
            'Dhuhr': timings['Dhuhr'],
            'Asr': timings['Asr'],
            'Maghrib': timings['Maghrib'],
            'Isha': timings['Isha']
        }
        
        print(f"✓ Prayer times for {now.strftime('%Y-%m-%d')}:")
        for prayer, time in prayer_times.items():
            print(f"  {prayer}: {time}")
        
        return prayer_times
        
    except Exception as e:
        print(f"Error fetching prayer times: {e}")
        return None

def update_crontab(prayer_times):
    """Update crontab with prayer time pause jobs"""
    try:
        # Get existing crontab (filter out old prayer time entries)
        result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
        
        if result.returncode == 0:
            existing_lines = result.stdout.strip().split('\n')
            # Remove old prayer pause entries
            filtered_lines = [line for line in existing_lines 
                            if 'pause_for_prayer.sh' not in line and line.strip()]
        else:
            filtered_lines = []
        
        # Add header comment
        new_cron_lines = filtered_lines + [
            "",
            "# Prayer time music pauses (auto-updated daily)",
            f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        ]
        
        # Add cron job for each prayer
        for prayer, time_str in prayer_times.items():
            # Parse time (format: "HH:MM")
            hour, minute = time_str.split(':')
            
            # Create cron entry (runs at prayer time every day)
            cron_line = f"{minute} {hour} * * * {PAUSE_SCRIPT} # {prayer}"
            new_cron_lines.append(cron_line)
            print(f"  Added: {prayer} at {time_str}")
        
        # Write new crontab
        new_crontab = '\n'.join(new_cron_lines) + '\n'
        
        result = subprocess.run(
            ['crontab', '-'],
            input=new_crontab,
            text=True,
            capture_output=True
        )
        
        if result.returncode == 0:
            print("\n✓ Crontab updated successfully")
            return True
        else:
            print(f"Error updating crontab: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"Error updating crontab: {e}")
        return False

def main():
    print("=== Prayer Times Updater ===\n")
    
    # Fetch today's prayer times
    prayer_times = fetch_prayer_times()
    
    if not prayer_times:
        print("\n✗ Failed to fetch prayer times")
        sys.exit(1)
    
    # Update crontab
    print("\nUpdating crontab...")
    if update_crontab(prayer_times):
        print("\n✓ Setup complete - music will pause for 15 minutes at each prayer time")
    else:
        print("\n✗ Failed to update crontab")
        sys.exit(1)

if __name__ == "__main__":
    main()
