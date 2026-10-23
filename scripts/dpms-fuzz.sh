#!/bin/bash
# Cycle DPMS off/on through KWin with random short delays until the display wedges (mdss gdsc / frame timeout) or N cycles pass. Run on the tablet as root.
# usage: dpms-fuzz.sh [cycles=300] [min_ms=200] [max_ms=6000]
n=${1:-300}; lo=${2:-200}; hi=${3:-6000}
U="sudo -u USER XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus WAYLAND_DISPLAY=wayland-1"
log=/root/dpms-fuzz-$(date +%m%d-%H%M).log
sig='stuck at|clock enable failed|frame done timeout|resume failed'
base=$(dmesg | grep -c -E "$sig")
rnd() { local ms=$(( lo + (RANDOM * 32768 + RANDOM) % (hi - lo) )); printf "%d.%03d" $((ms/1000)) $((ms%1000)); }
for i in $(seq 1 $n); do
  a=$(rnd); b=$(rnd)
  $U kscreen-doctor --dpms off >/dev/null 2>&1; sleep $a
  $U kscreen-doctor --dpms on >/dev/null 2>&1; sleep $b
  now=$(dmesg | grep -c -E "$sig"); st=$(cat /sys/devices/platform/soc/ae00000.display-subsystem/power/runtime_status)
  echo "cycle $i off=${a}s on=${b}s sigs=$((now-base)) mdss=$st" >> $log
  if [ "$now" -gt "$base" ] || [ "$st" = error ]; then echo "WEDGED at cycle $i (off=${a}s on=${b}s)" | tee -a $log; exit 1; fi
done
echo "DONE $n cycles without wedge" | tee -a $log
