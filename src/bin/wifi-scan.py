#!/usr/bin/python3

import json
import subprocess
import sys


AP_SERVICE = "nest-access-point.service"


def ap_is_active() -> bool:
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", AP_SERVICE]
    ).returncode == 0


def get_wifi_networks():
    try:
        output = subprocess.check_output(
            ["nmcli", "-f", "ssid,signal", "-t", "-c", "no", "dev", "wifi", "list", "--rescan", "yes"],
            universal_newlines=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error executing nmcli command: {e}")
        return []

    networks = {}
    for line in output.strip().split("\n"):
        if ":" not in line:
            continue
        ssid, signal = line.split(":", 1)
        if not ssid:
            continue
        signal = int(signal)
        if ssid not in networks or networks[ssid] < signal:
            networks[ssid] = signal

    results = [{"ssid": ssid, "signal": signal} for ssid, signal in networks.items()]
    results.sort(key=lambda x: x["signal"], reverse=True)
    return results


def main():
    # We can't scan while the AP is up — the single radio is locked to AP mode
    # on its channel. Just fail; the user can enter the SSID manually instead.
    if ap_is_active():
        print("Cannot scan while access point is active. Enter SSID manually.")
        sys.exit(1)

    results = get_wifi_networks()
    if not results:
        print("No Wi-Fi networks found.")
        return
    print(json.dumps(results))


if __name__ == "__main__":
    main()
