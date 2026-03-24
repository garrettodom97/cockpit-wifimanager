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

def get_active_connections():
    """Return set of connection names that are fully activated."""
    lines = run_nmcli(["-t", "-f", "NAME,STATE", "connection", "show", "--active"])
    active = set()
    for line in lines:
        if not line.strip():
            continue
        name, state = line.split(":", 1)
        if state == "activated":
            active.add(name)
    return active

def get_wifi_connections():
    # Use terse mode for easy parsing
    lines = run_nmcli(["-t", "-f", "NAME,UUID,TYPE", "connection", "show"])
    active = get_active_connections()
    wifi_list = []

    for line in lines:
        if not line.strip():
            continue

        name, uuid, ctype = line.split(":", 2)

        if ctype != "802-11-wireless":
            continue

        ssid = get_ssid(uuid)

        wifi_list.append({
            "id": name,
            "uuid": uuid,
            "ssid": ssid,
            "active": name in active
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

