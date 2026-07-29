#!/usr/bin/bash

# $1 = network SSID
# $2 = network password

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: wifi-set.sh NETWORK KEY"
	exit 1
fi

# Optional site hook for a service sharing the wifi radio. See wifi-hook.sh.
. "$(dirname "$0")/wifi-hook.sh"

# Pick the wifi device: the first one NetworkManager is willing to manage. Skipping
# unmanaged vifs avoids picking an interface some other service holds, and it must
# also be quoted below — an unquoted expansion word-splits into an invalid nmcli
# argument list on a host with more than one wifi netdev.
#
# Done BEFORE the hook releases the device, so the right interface is chosen
# regardless of what state that service left it in.
WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
	awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')

if [ -z "$WLAN_DEV" ]; then
	# Nothing managed at all: most likely another service is holding the only
	# radio. Ask it to release, then look again.
	run_wifi_hook before-apply
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

# Release the radio, then activate explicitly rather than relying on autoconnect, so
# the outcome of the association is observable and can be rolled back.
run_wifi_hook before-apply
if ! nmcli conn up "$1"; then
	# Activation failed (wrong password, network out of range, etc.). Remove the bad
	# profile and let the hook restore whatever it stood down, so the user still has
	# a way to reach this page and retry.
	nmcli conn delete "$1" 2>/dev/null
	run_wifi_hook apply-failed
	exit 1
fi

# Activation succeeded, so make the profile persistent across reboots.
nmcli conn modify "$1" connection.autoconnect yes
