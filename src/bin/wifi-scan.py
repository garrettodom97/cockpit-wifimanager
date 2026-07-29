#!/usr/bin/python3

import json
import subprocess


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
    results = get_wifi_networks()
    if not results:
        print("No Wi-Fi networks found.")
        return
    print(json.dumps(results))


if __name__ == "__main__":
    main()
