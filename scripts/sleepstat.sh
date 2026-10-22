#!/bin/bash
# usage: [DIRECT=deep] [PRE=..] [POST=..] sleepstat.sh <seconds> <log>   suspend with an RTC alarm, compare qcom_stats before/after
# DIRECT=deep: mem_sleep=deep + echo mem > /sys/power/state (PSCI SYSTEM_SUSPEND), bypassing logind and the Denial mem_sleep hook; mem_sleep is put back to s2idle
S=${1:-45}; L=${2:-/root/sleepstat.log}
D=/sys/kernel/debug/qcom_stats
snap() { for n in aosd cxsd ddr apss adsp wpss; do echo "$n $(grep -m1 Count $D/$n | cut -d' ' -f2) $(grep -m1 Accumulated $D/$n | cut -d' ' -f3)"; done; grep -E "LPM Stat" $D/ddr_stats | awk '{print "ddrlpm",$4,$5}' ; }
echo 0 > /sys/class/rtc/rtc0/wakealarm
{ echo "== before $(date +%T) mem_sleep=$(cat /sys/power/mem_sleep) batt=$(cat /sys/class/power_supply/qcom-battmgr-bat/charge_counter) uAh"; snap; } > $L
snap > /tmp/ss.before
eval "$PRE"
echo "+$S" > /sys/class/rtc/rtc0/wakealarm
T0=$(date +%s); BT0=$(cut -d' ' -f1 /proc/uptime)
if [ "${DIRECT:-}" = deep ]; then echo deep > /sys/power/mem_sleep; echo mem > /sys/power/state; echo s2idle > /sys/power/mem_sleep; else systemctl suspend; fi
sleep 3
BT1=$(cut -d' ' -f1 /proc/uptime)
{ echo "== after $(date +%T) wall=$(( $(date +%s)-T0 )) s  uptime-delta=$(python3 -c "print(round($BT1-$BT0,1))") wake-irq=$(cat /sys/power/pm_wakeup_irq 2>&1) batt=$(cat /sys/class/power_supply/qcom-battmgr-bat/charge_counter) uAh"; snap; } >> $L
snap > /tmp/ss.after
{ echo "== delta (count, duration ticks)"; paste /tmp/ss.before /tmp/ss.after | awk '{printf "%s: count +%d  dur +%d\n",$1,$5-$2,$6-$3}'; echo "== suspend_stats"; for f in success fail failed_resume last_failed_dev; do echo "$f=$(cat /sys/power/suspend_stats/$f)"; done; echo DONE; } >> $L
eval "$POST"   # after the counters are logged (e.g. rfkill unblock, or a hard reboot after stopping remoteprocs)
