#!/usr/bin/env python3
import subprocess
import json

def run_nmcli(args):
    """Run nmcli and return stdout lines."""
    result = subprocess.run(
        ["nmcli"] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True
    )
    return result.stdout.splitlines()

def get_wifi_connections():
    # Use terse mode for easy parsing
    lines = run_nmcli(["-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show"])
    wifi_list = []

    for line in lines:
        if not line.strip():
            continue

        name, uuid, ctype, device = line.split(":", 3)

        if ctype != "802-11-wireless":
            continue

        ssid = get_ssid(uuid)

        wifi_list.append({
            "id": name,
            "uuid": uuid,
            "ssid": ssid
        })

    return wifi_list

def get_ssid(uuid):
    """Extract SSID from nmcli connection show <uuid>."""
    detail = run_nmcli(["-t", "-f", "802-11-wireless.ssid", "connection", "show", uuid])

    # Output looks like: "802-11-wireless.ssid:MyNetwork"
    for line in detail:
        if line.startswith("802-11-wireless.ssid:"):
            return line.split(":", 1)[1]

    return None  # If no SSID found

if __name__ == "__main__":
    wifi_connections = get_wifi_connections()
    print(json.dumps(wifi_connections, indent=2))

