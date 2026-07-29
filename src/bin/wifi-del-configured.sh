#!/usr/bin/bash

# $1 = network SSID

if [ -z "$1" ]; then
	echo "usage: wifi-del-configured.sh CONNNAME"
	exit 1
fi

# Optional site hook for a service sharing the wifi radio. See wifi-hook.sh.
. "$(dirname "$0")/wifi-hook.sh"

nmcli conn delete "$1"

# Deleting the last wifi profile can leave a headless host with no network path in at
# all. Tell the hook, so anything that provides a fallback — a setup access point, say
# — can come back and keep the machine reachable for fresh provisioning.
if ! nmcli -t -f TYPE connection show | grep -q "^802-11-wireless$"; then
	run_wifi_hook profiles-cleared
fi
