#!/bin/bash
# Mean battery power with the screen off (DPMS off through KWin, system awake), for display-subsystem power/control = on and auto. Run on the tablet as root, charger unplugged.
# usage: idle-power.sh [settle_s=30] [sample_s=90]
settle=${1:-30}; samp=${2:-90}
B=/sys/class/power_supply/qcom-battmgr-bat; D=/sys/devices/platform/soc/ae00000.display-subsystem/power/control
U="sudo -u USER XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus WAYLAND_DISPLAY=wayland-1"
orig=$(cat $D)
[ "$(cat /sys/class/power_supply/qcom-battmgr-usb/online)" = 1 ] && { echo "charger still connected"; exit 1; }
meas() { # prints mean mW and mean mA
  local n=0 sum=0 sa=0 e=$(( $(date +%s) + samp ))
  while [ $(date +%s) -lt $e ]; do
    i=$(cat $B/current_now); v=$(cat $B/voltage_now)
    sum=$(( sum + (i < 0 ? -i : i) / 1000 * (v / 1000) / 1000 )); sa=$(( sa + (i < 0 ? -i : i) / 1000 )); n=$((n+1)); sleep 1
  done
  echo "$((sum/n)) mW  $((sa/n)) mA  ($n samples)"
}
for mode in on auto on auto; do
  echo $mode > $D; $U kscreen-doctor --dpms off >/dev/null 2>&1; sleep $settle
  echo "control=$mode screen off: $(meas) status=$(cat $B/status)"
  $U kscreen-doctor --dpms on >/dev/null 2>&1; sleep 5
done
echo $orig > $D
