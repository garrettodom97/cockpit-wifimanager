#!/usr/bin/bash

# $1 = network SSID
# $2 = network password

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: wifi-set.sh NETWORK KEY"
	exit 1
fi

# Pick the wifi device. In AP-only mode there's only one wifi vif; in any other
# mode we skip unmanaged vifs (e.g. the AP vif) and use the first NM-managed
# one. Doing this lookup BEFORE we stop the AP ensures the right interface
# regardless of current AP state.
WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
	awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')

if [ -z "$WLAN_DEV" ]; then
	# No managed wifi yet — must be because the AP is running on it. Stop AP
	# so NM takes the wifi vif back, then pick it.
	sudo systemctl stop nest-access-point.service
	sleep 2
	WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
		awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')
fi

if [ -z "$WLAN_DEV" ]; then
	echo "no managed wifi device found"
	exit 1
fi

# Create the connection profile in ONE call, PSK included, with autoconnect off.
#
# Setting the PSK in a later `nmcli conn modify` leaves a window where the profile
# exists with autoconnect enabled but no secret, and NetworkManager's autoconnect
# policy claims it in that window. Observed on the device: auto-activation fired
# 10ms after the key-mgmt update and failed the connection with
# reason 'no-secrets' 320ms before the PSK landed.
#
# That only happens when no wifi is currently active — NM has no reason to
# auto-activate a new profile while another is up — which makes first-time
# provisioning the case that hits it. It is also self-sustaining: the failure leaves
# the device disconnected, so every retry is in the same vulnerable state.
#
# autoconnect stays off until the activation below succeeds, so NM cannot race this
# script for control of the profile, and a profile that never worked cannot come
# back on the next boot.
nmcli conn delete "$1" 2>/dev/null
nmcli conn add type wifi ifname "${WLAN_DEV}" \
	con-name "$1" autoconnect no ssid "$1" \
	wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$2"

# Make sure the AP is stopped, then activate the wifi connection.
sudo systemctl stop nest-access-point.service
if ! nmcli conn up "$1"; then
	# Activation failed (wrong password, network out of range, etc.).
	# Remove the bad profile and bring the AP back so the user can retry.
	# Use 'restart' instead of 'start' — the oneshot may be active(exited).
	nmcli conn delete "$1" 2>/dev/null
	sudo systemctl restart nest-access-point.service
	exit 1
fi

# Activation succeeded, so make the profile persistent across reboots.
nmcli conn modify "$1" connection.autoconnect yes
