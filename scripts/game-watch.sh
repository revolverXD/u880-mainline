#!/bin/bash
# Runs ON the tablet: every 5 s log load, memory, top processes, GPU busy/freq, max temp and battery to /root/game-watch.log; kernel messages to /root/game-watch-dmesg.log.
L=/root/game-watch.log; : > $L; dmesg -w > /root/game-watch-dmesg.log 2>&1 &
B=/sys/class/power_supply/qcom-battmgr-bat
while true; do
  echo "== $(date +%T) load=$(cut -d' ' -f1-3 /proc/loadavg) mem_avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)MB swap_used=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print int((t-f)/1024)}')MB bat=$(cat $B/capacity 2>/dev/null)% cur=$(cat $B/current_now 2>/dev/null) tmax=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)" >> $L
  for g in /sys/class/devfreq/*kgsl*; do [ -d $g ] && echo "gpu freq=$(cat $g/cur_freq)" >> $L; done
  ps -eo pcpu,pmem,comm --sort=-pcpu | head -5 | tail -4 | tr '\n' ';' >> $L; echo >> $L
  sleep 5
done
