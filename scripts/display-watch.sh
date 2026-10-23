#!/usr/bin/env bash
# Stream display/suspend related events from the tablet (Wi-Fi), reconnecting when the tablet sleeps. One line per event.
# usage: U880_HOST=<ip> scripts/display-watch.sh
M=/home/USER/External/work/src/mainline
state='echo "STATE up=$(cut -d. -f1 /proc/uptime)s mdss=$(cat /sys/devices/platform/soc/ae00000.display-subsystem/power/runtime_status) dsi=$(cat /sys/class/drm/card1-DSI-1/dpms) bl=$(cat /sys/class/backlight/u880-backlight/actual_brightness) wedge_lines=$(dmesg | grep -c -E "stuck at|clock enable failed|frame done timeout")"'
pat='PM: suspend (entry|exit)|Triggering wakeup|stuck at|clock enable failed|resume failed|Power on failed|frame done timeout|vblank timeout|panel on sequence done|underflow|Atomic commit failed|dpu error|systemd-logind.*(Power key|suspend|sleep|Lid|idle)|powerdevil.*(DPMS|suspend|dim|idle|screen)|kwin.*(DPMS|output)'
connected=0
while true; do
  if $M/scripts/rssh.sh "$state" 2>/dev/null; then
    [ $connected = 0 ] && echo "CONNECTED"; connected=1
    $M/scripts/rssh.sh "journalctl -f -n 0 -o short-monotonic --no-pager" 2>/dev/null \
      | grep --line-buffered -E "$pat" \
      | awk '{ k=$0; sub(/^\[[^]]*\] /,"",k); gsub(/[0-9]+/,"N",k); if (k==last) { n++; if (n%50) next; else $0=$0" (x"n")" } else { n=0; last=k } print; fflush() }'
    echo "DISCONNECTED (tablet asleep, rebooting or link lost)"; connected=0
  fi
  sleep 4
done
