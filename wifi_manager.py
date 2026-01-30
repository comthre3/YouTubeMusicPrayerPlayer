#!/usr/bin/env python3
"""
Lightweight WiFi Manager for Raspberry Pi 3
Designed for easy network connection and switching with minimal resource usage.
"""

import subprocess
import json
import time
import os
import sys
from typing import List, Dict, Optional

class WiFiManager:
    def __init__(self):
        self.config_file = "/home/pi/wifi_networks.json"
        self.interface = "wlan0"
        self.ensure_config_exists()
    
    def ensure_config_exists(self):
        """Create config file if it doesn't exist"""
        if not os.path.exists(self.config_file):
            default_config = {"networks": [], "last_connected": None}
            self.save_config(default_config)
    
    def load_config(self) -> Dict:
        """Load saved network configurations"""
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except:
            return {"networks": [], "last_connected": None}
    
    def save_config(self, config: Dict):
        """Save network configurations"""
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def scan_networks(self) -> List[Dict]:
        """Scan for available WiFi networks"""
        try:
            # Use nmcli for network scanning (lightweight)
            result = subprocess.run(
                ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL", "dev", "wifi"],
                capture_output=True, text=True, timeout=15
            )
            
            networks = []
            for line in result.stdout.strip().split('\n'):
                if line and ':' in line:
                    parts = line.split(':')
                    if len(parts) >= 3 and parts[0]:
                        networks.append({
                            "ssid": parts[0],
                            "security": parts[1] if parts[1] else "Open",
                            "signal": parts[2] if parts[2] else "0"
                        })
            
            # Remove duplicates and sort by signal strength
            unique_networks = {}
            for net in networks:
                ssid = net["ssid"]
                if ssid not in unique_networks or int(net["signal"]) > int(unique_networks[ssid]["signal"]):
                    unique_networks[ssid] = net
            
            return sorted(unique_networks.values(), key=lambda x: int(x["signal"]), reverse=True)
        
        except Exception as e:
            print(f"Error scanning networks: {e}")
            return []
    
    def connect_to_network(self, ssid: str, password: str = None) -> bool:
        """Connect to a WiFi network"""
        try:
            print(f"Connecting to {ssid}...")
            
            if password:
                # Connect with password
                result = subprocess.run(
                    ["nmcli", "dev", "wifi", "connect", ssid, "password", password],
                    capture_output=True, text=True, timeout=30
                )
            else:
                # Connect to open network
                result = subprocess.run(
                    ["nmcli", "dev", "wifi", "connect", ssid],
                    capture_output=True, text=True, timeout=30
                )
            
            if result.returncode == 0:
                print(f"Successfully connected to {ssid}")
                self.save_network(ssid, password)
                return True
            else:
                print(f"Failed to connect: {result.stderr.strip()}")
                return False
        
        except Exception as e:
            print(f"Error connecting to network: {e}")
            return False
    
    def save_network(self, ssid: str, password: str = None):
        """Save network credentials for future use"""
        config = self.load_config()
        
        # Remove existing entry for this SSID
        config["networks"] = [n for n in config["networks"] if n["ssid"] != ssid]
        
        # Add new entry
        network_info = {"ssid": ssid, "password": password, "last_used": time.time()}
        config["networks"].append(network_info)
        config["last_connected"] = ssid
        
        self.save_config(config)
    
    def get_saved_networks(self) -> List[Dict]:
        """Get list of saved networks"""
        config = self.load_config()
        return sorted(config["networks"], key=lambda x: x.get("last_used", 0), reverse=True)
    
    def connect_to_saved(self, ssid: str) -> bool:
        """Connect to a previously saved network"""
        saved_networks = self.get_saved_networks()
        for network in saved_networks:
            if network["ssid"] == ssid:
                return self.connect_to_network(ssid, network["password"])
        
        print(f"Network {ssid} not found in saved networks")
        return False
    
    def get_current_connection(self) -> Optional[str]:
        """Get currently connected network SSID"""
        try:
            result = subprocess.run(
                ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
                capture_output=True, text=True, timeout=10
            )
            
            for line in result.stdout.strip().split('\n'):
                if line.startswith('yes:'):
                    return line.split(':', 1)[1]
            
            return None
        except Exception as e:
            print(f"Error getting current connection: {e}")
            return None
    
    def disconnect(self) -> bool:
        """Disconnect from current network"""
        try:
            result = subprocess.run(
                ["nmcli", "dev", "disconnect", self.interface],
                capture_output=True, text=True, timeout=10
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Error disconnecting: {e}")
            return False
    
    def auto_connect(self) -> bool:
        """Try to connect to the best available saved network"""
        current = self.get_current_connection()
        if current:
            print(f"Already connected to {current}")
            return True
        
        print("Scanning for saved networks...")
        available = self.scan_networks()
        saved = self.get_saved_networks()
        
        # Try to connect to saved networks in order of last used
        for saved_net in saved:
            for available_net in available:
                if saved_net["ssid"] == available_net["ssid"]:
                    print(f"Trying to connect to {saved_net['ssid']}...")
                    if self.connect_to_saved(saved_net["ssid"]):
                        return True
        
        print("No saved networks available")
        return False

def print_menu():
    """Print the main menu"""
    print("\n=== WiFi Manager ===\n")
    print("1. Scan and connect to new network")
    print("2. Connect to saved network")
    print("3. Show saved networks")
    print("4. Show current connection")
    print("5. Auto-connect to best saved network")
    print("6. Disconnect")
    print("7. Exit")
    print("\nChoice: ", end="")

def main():
    wifi = WiFiManager()
    
    # Check if running as root (required for network operations)
    if os.geteuid() != 0:
        print("This script requires root privileges. Please run with sudo.")
        sys.exit(1)
    
    while True:
        try:
            print_menu()
            choice = input().strip()
            
            if choice == "1":
                print("\nScanning for networks...")
                networks = wifi.scan_networks()
                
                if not networks:
                    print("No networks found")
                    continue
                
                print("\nAvailable networks:")
                for i, net in enumerate(networks[:10]):
                    print(f"{i+1}. {net['ssid']} ({net['security']}) - Signal: {net['signal']}%")
                
                try:
                    selection = int(input("\nSelect network (number): ")) - 1
                    if 0 <= selection < len(networks):
                        selected = networks[selection]
                        
                        if selected["security"] != "Open":
                            password = input(f"Enter password for {selected['ssid']}: ")
                            wifi.connect_to_network(selected["ssid"], password)
                        else:
                            wifi.connect_to_network(selected["ssid"])
                    else:
                        print("Invalid selection")
                except ValueError:
                    print("Invalid input")
            
            elif choice == "2":
                saved = wifi.get_saved_networks()
                if not saved:
                    print("\nNo saved networks")
                    continue
                
                print("\nSaved networks:")
                for i, net in enumerate(saved):
                    print(f"{i+1}. {net['ssid']}")
                
                try:
                    selection = int(input("\nSelect network (number): ")) - 1
                    if 0 <= selection < len(saved):
                        wifi.connect_to_saved(saved[selection]["ssid"])
                    else:
                        print("Invalid selection")
                except ValueError:
                    print("Invalid input")
            
            elif choice == "3":
                saved = wifi.get_saved_networks()
                if saved:
                    print("\nSaved networks:")
                    for net in saved:
                        print(f"- {net['ssid']}")
                else:
                    print("\nNo saved networks")
            
            elif choice == "4":
                current = wifi.get_current_connection()
                if current:
                    print(f"\nConnected to: {current}")
                else:
                    print("\nNot connected")
            
            elif choice == "5":
                wifi.auto_connect()
            
            elif choice == "6":
                if wifi.disconnect():
                    print("\nDisconnected")
                else:
                    print("\nFailed to disconnect")
            
            elif choice == "7":
                print("\nExiting...")
                break
            
            else:
                print("\nInvalid choice")
        
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break
        except Exception as e:
            print(f"\nError: {e}")

if __name__ == "__main__":
    main()
