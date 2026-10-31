#!/bin/sh
# Standby A/B, counterbalanced (ABBA): Wi-Fi associated (ON) vs disconnected with `nmcli dev disconnect wlan0` (OFF, radio stays powered, no rfkill: issue #16) during s2idle, 10 windows of $1 seconds (default 2700).
# Run on the tablet with NOTHING plugged in and the tablet untouched. Results: /root/standby-wifi.out
# Charge is read at gauge update steps (quantum about 5.07 mAh); interrupts = sum of all per-CPU counts in /proc/interrupts.
B=/sys/class/power_supply/qcom-battmgr-bat
OUT=/root/standby-wifi.out
D=${1:-2700}
CON=$(nmcli -t -f NAME,TYPE con show --active | grep wireless | head -1 | cut -d: -f1)
[ -n "$CON" ] || { echo "no active Wi-Fi connection, abort" > $OUT; exit 1; }
for o in /sys/class/power_supply/*/online; do [ "$(cat $o)" = 1 ] && { echo "external power on $o, abort" > $OUT; exit 1; }; done
: > $OUT
echo "start $(date +%T) window=${D}s batt=$(cat $B/capacity)% con=$CON wifi_powersave=$(iw dev wlan0 get power_save 2>/dev/null)" >> $OUT
wifi_off() { nmcli dev disconnect wlan0 >/dev/null 2>&1; }
wifi_on()  { nmcli con up "$CON" >/dev/null 2>&1; i=0; while [ $i -lt 40 ]; do [ "$(nmcli -g GENERAL.STATE dev show wlan0 | cut -c1-3)" = 100 ] && return; i=$((i+1)); sleep 2; done; systemctl restart NetworkManager; }
now() { date +%s; }
irqs() { awk 'NR>1{for(i=2;i<=9;i++) if ($i ~ /^[0-9]+$/) s+=$i} END{print s+0}' /proc/interrupts; }
wait_change() {
  s=$(now)
  while [ $(( $(now) - s )) -lt "$2" ]; do CH_V=$(cat $B/charge_counter); [ "$CH_V" != "$1" ] && { CH_T=$(now); return; }; sleep 1; done
  CH_V=$(cat $B/charge_counter); CH_T=$(now)
}
run() {   # $1 label
  sleep 20
  cur=$(cat $B/charge_counter); wait_change $cur 180; c0=$CH_V; t0=$CH_T
  a=$(awk -v c="$(cat $B/current_now)" 'BEGIN{print (c<0?-c:c)}'); i0=$(irqs)
  echo 0 > /sys/class/rtc/rtc0/wakealarm; echo "+$D" > /sys/class/rtc/rtc0/wakealarm
  tf=$(now); echo freeze > /sys/power/state; tw=$(now)
  wait_change $c0 240; c1=$CH_V; t1=$CH_T; i1=$(irqs)
  awk -v l="$1" -v c0=$c0 -v c1=$c1 -v t0=$t0 -v tf=$tf -v tw=$tw -v t1=$t1 -v a=$a -v di=$((i1-i0)) -v wk="$(cat /sys/power/pm_wakeup_irq 2>/dev/null)" 'BEGIN{
    awake=(tf-t0)+(t1-tw); susp=tw-tf; dq=c0-c1; dq_s=dq-a*awake/3600;
    mw=(susp>0)? dq_s/1000*3600/susp*3.95 : 0;
    printf "%s: suspended=%ds awake=%ds charge=%duAh power=%.0fmW interrupts=%d (%.2f/s) wakeirq=%s\n", l, susp, awake, dq, mw, di, (susp>0?di/susp:0), wk }' >> $OUT
}
n=0
for c in ON OFF OFF ON ON OFF OFF ON ON OFF; do
  n=$((n+1))
  if [ $c = OFF ]; then wifi_off; fi
  run "w$n wifi=$c"
  [ $c = OFF ] && wifi_on
done
echo "end $(date +%T) batt=$(cat $B/capacity)%" >> $OUT
iw dev wlan0 set power_save off 2>/dev/null; echo "wifi power save switched off at the end so the tablet stays reachable" >> $OUT
echo DONE >> $OUT
