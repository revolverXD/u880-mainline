#!/bin/bash
# Battery-drain measurement per state, run ON the tablet with every cable unplugged (charging hides the draw). Results in /root/powertest.log.
# usage: powertest.sh <seconds per state> [states...]   states: idle (awake, screen as is) | s2idle | deep   (default: idle s2idle deep)
# Suspend states wake by RTC alarm (+seconds). mA = delta(charge_counter uAh) / delta(CLOCK_BOOTTIME h); suspend time is included in BOOTTIME.
S=${1:-90}; shift; STATES=${*:-idle s2idle deep}; L=/root/powertest.log
B=/sys/class/power_supply/qcom-battmgr-bat; U=/sys/class/power_supply/qcom-battmgr-usb
cc() { cat $B/charge_counter; }; bt() { cut -d' ' -f1 /proc/uptime; }
: > $L
echo "start $(date +%T) usb_online=$(cat $U/online) status=$(cat $B/status) soc=$(cat $B/capacity)% v=$(cat $B/voltage_now) temp=$(cat $B/temp)" >> $L
for st in $STATES; do
  echo 0 > /sys/class/rtc/rtc0/wakealarm
  sleep 5; c0=$(cc); t0=$(bt)
  case $st in
    idle) sleep $S ;;
    s2idle) echo "+$S" > /sys/class/rtc/rtc0/wakealarm; echo s2idle > /sys/power/mem_sleep; echo mem > /sys/power/state ;;
    deep)   echo "+$S" > /sys/class/rtc/rtc0/wakealarm; echo deep > /sys/power/mem_sleep; echo mem > /sys/power/state; echo s2idle > /sys/power/mem_sleep ;;
  esac
  sleep 4; c1=$(cc); t1=$(bt)
  python3 - "$st" $c0 $c1 $t0 $t1 >> $L <<P
import sys
st,c0,c1,t0,t1=sys.argv[1],*map(float,sys.argv[2:6])
dt=(t1-t0)/3600; dq=(c0-c1)/1000.0   # mAh drawn (positive = discharge)
print("%-7s dt=%6.1f s  drawn=%7.3f mAh  avg=%7.1f mA  ~%5.2f W at 3.9 V"%(st,t1-t0,dq,dq/dt if dt else 0,dq/dt*3.9/1000 if dt else 0))
P
done
echo "usb_online_end=$(cat $U/online) soc=$(cat $B/capacity)%" >> $L; echo DONE >> $L
