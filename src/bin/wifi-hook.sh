#!/usr/bin/bash
#
# Optional site integration hook, sourced by the scripts that change wifi state.
#
# On some hosts another service shares the wifi radio — an access point running on a
# second virtual interface of the same phy, for instance. Such a service has to be
# stood down while a connection is applied, and restored if the apply fails or the
# last profile is removed. Rather than naming any particular service here, this
# plugin calls a single hook if the host has installed one.
#
# Install an executable at $WIFI_HOOK (default below). It is called with exactly one
# argument naming what happened:
#
#   before-apply      about to associate — release the wifi device if you hold it
#   apply-failed      association failed — restore whatever you had
#   profiles-cleared  no wifi profiles remain — restore whatever you had
#
# Absent or not executable means no integration, which is the upstream default and
# leaves behaviour unchanged.
#
# The hook is deliberately NOT invoked through sudo. It is responsible for its own
# privilege escalation. Invoking it as root would require a blanket "may run this
# script as root" sudoers rule, which is far looser than the narrowly scoped rules an
# integrator would otherwise write — e.g. permitting only
# `systemctl stop <one-unit>` rather than an arbitrary script.
#
# A hook failure is reported and ignored rather than aborting: whatever it manages is
# by definition not the wifi connection the user asked for, and failing the apply
# because a side integration misbehaved would be worse than proceeding.

WIFI_HOOK=${WIFI_HOOK:-/etc/cockpit-wifimanager/hook}

run_wifi_hook() {
	[ -x "$WIFI_HOOK" ] || return 0
	"$WIFI_HOOK" "$1" || echo "warning: ${WIFI_HOOK} $1 exited $?" >&2
	return 0
}
