#!/bin/sh
# Backlight state at each step of a power-key off/on cycle. The panel is an LCD, so "the screen is
# dark" can mean the backlight stopped being driven rather than the pixels. Run as root.
state() {
	echo "== $1"
	grep -A3 "u880-backlight" /sys/kernel/debug/pwm | grep -E "requested|actual"
	cat /sys/class/backlight/u880-backlight/brightness /sys/class/backlight/u880-backlight/bl_power
}
state now
touch /tmp/power-press; sleep 4; state after-off
touch /tmp/power-press; sleep 6; state after-on
