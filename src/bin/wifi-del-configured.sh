#!/usr/bin/bash

# $1 = network SSID
# $2 = network password

if [ -z "$1" ]; then
	echo "usage: wifi-del-configured.sh CONNNAME"
	exit 1
fi

nmcli conn delete "$1"
