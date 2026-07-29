#!/usr/bin/bash

# $1 = network SSID

if [ -z "$1" ]; then
	echo "usage: wifi-del-configured.sh CONNNAME"
	exit 1
fi

nmcli conn delete "$1"

# If no wifi profiles remain, bring the AP back so the device is reachable
# again for fresh provisioning. Use 'restart' (not 'start') because the unit
# is a Type=oneshot RemainAfterExit=yes; if its last run no-op'd ("wifi
# connection profile present; not starting AP"), systemd still considers it
# active and 'start' becomes a no-op. 'restart' always re-runs ExecStart.
if ! nmcli -t -f TYPE connection show | grep -q "^802-11-wireless$"; then
	sudo systemctl restart nest-access-point.service
fi
