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
# since NetworkManager does not manage an interface held by hostapd.
WLAN_DEV=$(nmcli -t -f DEVICE,TYPE,STATE device status | \
	awk -F: '$2=="wifi" && $3!="unmanaged" {print $1; exit}')

if [ -z "$WLAN_DEV" ]; then
	echo "no managed wifi device found"
	exit 1
fi

nmcli conn delete "$1" 2>/dev/null
nmcli conn add type wifi ifname "${WLAN_DEV}" \
	con-name "$1" autoconnect yes ssid "$1"
nmcli conn modify "$1" wifi-sec.key-mgmt wpa-psk
nmcli conn modify "$1" wifi-sec.psk "$2"
