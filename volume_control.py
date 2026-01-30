#!/usr/bin/env python3
"""
Simple Volume Control Script for Raspberry Pi
"""

import sys
import subprocess
import re

def get_current_volume():
    """Get current volume percentage"""
    try:
        result = subprocess.run(
            ['amixer', '-c', '0', 'sget', 'PCM'],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Extract volume percentage from output
        match = re.search(r'\[(\d+)%\]', result.stdout)
        if match:
            return int(match.group(1))
        return None
    except Exception as e:
        print(f"Error getting volume: {e}")
        return None

def set_volume(volume):
    """Set volume to specific percentage (0-100)"""
    try:
        volume = max(0, min(100, int(volume)))  # Clamp between 0-100
        subprocess.run(
            ['amixer', '-c', '0', 'sset', 'PCM', f'{volume}%'],
            capture_output=True,
            check=True
        )
        print(f"Volume set to {volume}%")
        return True
    except Exception as e:
        print(f"Error setting volume: {e}")
        return False

def increase_volume(amount=5):
    """Increase volume by specified amount"""
    current = get_current_volume()
    if current is not None:
        new_volume = min(100, current + amount)
        set_volume(new_volume)

def decrease_volume(amount=5):
    """Decrease volume by specified amount"""
    current = get_current_volume()
    if current is not None:
        new_volume = max(0, current - amount)
        set_volume(new_volume)

def show_usage():
    """Show usage information"""
    print("""
Volume Control Script
====================

Usage:
    ./volume_control.py                 - Show current volume
    ./volume_control.py <0-100>         - Set volume to specific percentage
    ./volume_control.py +               - Increase volume by 5%
    ./volume_control.py ++              - Increase volume by 10%
    ./volume_control.py -               - Decrease volume by 5%
    ./volume_control.py --              - Decrease volume by 10%

Examples:
    ./volume_control.py 80              - Set volume to 80%
    ./volume_control.py +               - Increase by 5%
    ./volume_control.py --              - Decrease by 10%
""")

def main():
    if len(sys.argv) == 1:
        # No arguments - show current volume
        current = get_current_volume()
        if current is not None:
            print(f"Current volume: {current}%")
        else:
            print("Could not get current volume")
        return
    
    arg = sys.argv[1]
    
    if arg in ['-h', '--help', 'help']:
        show_usage()
    elif arg == '+':
        increase_volume(5)
    elif arg == '++':
        increase_volume(10)
    elif arg == '-':
        decrease_volume(5)
    elif arg == '--':
        decrease_volume(10)
    else:
        # Try to parse as number
        try:
            volume = int(arg)
            set_volume(volume)
        except ValueError:
            print(f"Invalid argument: {arg}")
            show_usage()

if __name__ == "__main__":
    main()
