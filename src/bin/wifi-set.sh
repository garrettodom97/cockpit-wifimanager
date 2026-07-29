#!/usr/bin/bash

# $1 = network SSID
# $2 = network password

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: wifi-set.sh NETWORK KEY"
	exit 1
fi

# Pick the wifi device: the first one NetworkManager is willing to manage.
#
# The previous lookup returned *every* wifi netdev. On a host with a second wifi
# vif — an access point running alongside the client, say — that is two names, and
# unquoted ${WLAN_DEV} then word-splits into
#
#     nmcli conn add type wifi ifname <sta> <ap> con-name ...
#
# where nmcli reads the second name as a setting.property and fails with
# `invalid <setting>.<property> '<ap>'`. The profile is never created, so every
# attempt to join a network fails identically.
#
# Filtering on STATE != unmanaged also picks the client rather than the AP vif,
# since NetworkManager does not manage an interface held by hostapd. Doing this
# lookup BEFORE stopping the AP gets the right interface regardless of AP state.
WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
	awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')

if [ -z "$WLAN_DEV" ]; then
	# No managed wifi at all: on a NeST device that means the AP has claimed the
	# only radio. Stop it so NetworkManager takes the vif back, then look again.
	sudo systemctl stop nest-access-point.service
	sleep 2
	WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
		awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')
fi

if [ -z "$WLAN_DEV" ]; then
	echo "no managed wifi device found"
	exit 1
fi

nmcli conn delete "$1" 2>/dev/null
nmcli conn add type wifi ifname "${WLAN_DEV}" \
	con-name "$1" autoconnect yes ssid "$1"
nmcli conn modify "$1" wifi-sec.key-mgmt wpa-psk
nmcli conn modify "$1" wifi-sec.psk "$2"

# Free the radio, then activate explicitly rather than leaving it to autoconnect,
# so the outcome of the association is observable and can be rolled back.
sudo systemctl stop nest-access-point.service
if ! nmcli conn up "$1"; then
	# Activation failed (wrong password, network out of range, etc.). Remove the
	# bad profile and bring the AP back so the user can reach the portal to retry;
	# otherwise a failed join leaves the device with no route in at all.
	#
	# 'restart' rather than 'start': the unit is Type=oneshot RemainAfterExit=yes,
	# so if its last run no-op'd systemd still considers it active and 'start' does
	# nothing. 'restart' always re-runs ExecStart.
	nmcli conn delete "$1" 2>/dev/null
	sudo systemctl restart nest-access-point.service
	exit 1
fi
