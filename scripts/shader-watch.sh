#!/bin/bash
# Runs ON the tablet, prints one line per notable event: Steam shader-compile processes, shader log errors, kernel gpu faults (counted per 15 s), other kernel warnings, crashes, OOM kills.
SL=/home/USER/.local/share/Steam/logs/shader_log.txt
tail -n0 -F $SL 2>/dev/null | grep --line-buffered -i -E "error|fail|crash|invalid|timeout|segfault|killed|abort" | sed 's/^/SHADERLOG /' &
dmesg -W -l warn,err 2>/dev/null | grep --line-buffered -v -E "novatek|Error selecting event page|slot .* out of range|unknown state|gpu fault|adreno_fault_handler" | sed 's/^/KERNEL /' &
last_f=$(dmesg | grep -c "gpu fault"); last_c=$(coredumpctl list --no-legend 2>/dev/null | wc -l)
while true; do
  sleep 15
  f=$(dmesg | grep -c "gpu fault"); [ $((f-last_f)) -gt 0 ] && echo "GPUFAULT +$((f-last_f)) in 15 s (total $f)"; last_f=$f
  n=$(pgrep -c fossilize_replay); [ "$n" -gt 0 ] && echo "SHADERS fossilize_replay procs=$n cpu=$(ps -C fossilize_replay -o pcpu= | awk '{s+=$1} END {print int(s)}')% mem_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)MB tmax=$(cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -1 | awk '{print int($1/1000)}')C"
  c=$(coredumpctl list --no-legend 2>/dev/null | wc -l); [ $c -gt $last_c ] && { echo "CRASH new coredump: $(coredumpctl list --no-legend | tail -1 | cut -c1-120)"; last_c=$c; }
  journalctl -k --no-pager --since "-16s" 2>/dev/null | grep -i -E "out of memory|oom-kill|Killed process" | head -2 | sed 's/^/OOM /'
done
