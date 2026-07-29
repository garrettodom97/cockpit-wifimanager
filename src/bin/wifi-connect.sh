#!/usr/bin/bash

# $1 = name or uuid of an already-configured connection

if [ -z "$1" ]; then
	echo "usage: wifi-connect.sh CONNNAME"
	exit 1
fi

# Optional site hook for a service sharing the wifi radio. See wifi-hook.sh.
. "$(dirname "$0")/wifi-hook.sh"

# Activating a saved profile has to release the radio exactly as applying a new one
# does. Without this, the UI's "connect" action went straight to nmcli and any service
# sharing the radio kept holding it through the handshake — on a single-radio host that
# means the client associates on one channel while the other service still beacons on
# the previous one, which costs the uplink roughly half its packets until something
# notices and reconverges.
run_wifi_hook before-apply

if ! nmcli connection up "$1"; then
	# Restore whatever the hook stood down, so a failed switch still leaves a way in.
	#
	# Deliberately no `nmcli conn delete` here, unlike wifi-set.sh: that script created
	# the profile moments earlier and owns it, whereas this one is activating a profile
	# the user saved previously. Deleting it because one activation failed would throw
	# away working credentials.
	run_wifi_hook apply-failed
	exit 1
fi
