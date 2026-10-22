#!/usr/bin/env bash
# DPMS A/B with real pixel capture: screenshot the compositor output before and after a
# power-key off/on cycle. Run on the tablet (root). usage: dpms-grim.sh [outdir]
set -uo pipefail
out=${1:-/tmp/dpms-grim}
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1
mkdir -p "$out"

shot() { # shot <name>
  timeout 10 grim "$out/$1.png" && echo "captured $out/$1.png" || echo "grim FAILED for $1"
  denialctl outputs | sed -n 's/^  DSI-1: \(.*\)$/\1/p' | head -1 | sed "s/^/  DSI-1: $1 /"
  cat /sys/class/backlight/u880-backlight/bl_power 2>/dev/null | sed "s/^/  bl_power $1: /"
}

state() { grep -m1 . /sys/kernel/debug/dri/1/state 2>/dev/null; }

shot 01-before
touch /tmp/power-press; echo "pressed power (off)"; sleep 4
shot 02-off
touch /tmp/power-press; echo "pressed power (on)"; sleep 6
shot 03-after
touch /tmp/power-press; echo "pressed power (off)"; sleep 4
touch /tmp/power-press; echo "pressed power (on)"; sleep 6
shot 04-after2
