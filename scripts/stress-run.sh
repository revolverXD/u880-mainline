#!/bin/bash
# Thermal/stress run with logging and a software cut-off (the kernel has no CPU cooling maps, see NOTES 2026-10-23).
# usage: stress-run.sh <cpu|gpu|both|idle> <minutes> [limit_C=95] [batt_limit_C=45]
mode=${1:-cpu}; mins=${2:-5}; lim=${3:-95}; blim=${4:-45}
log=/root/stress-$mode-$(date +%m%d-%H%M).log
B=/sys/class/power_supply/qcom-battmgr-bat
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; pkill -x stress-ng 2>/dev/null; pkill -x glmark2-es2-wayland 2>/dev/null; }
trap cleanup EXIT
U="sudo -u USER XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1"
case $mode in cpu|both) stress-ng --cpu 8 --cpu-method matrixprod --timeout $((mins*60))s >/dev/null 2>&1 & pids+=($!);; esac
case $mode in gpu|both) $U glmark2-es2-wayland --run-forever --fullscreen >/dev/null 2>&1 & pids+=($!);; esac
end=$(( $(date +%s) + mins*60 ))
echo "# mode=$mode mins=$mins limit=${lim}C batt_limit=${blim}C start batt=$(cat $B/capacity)% $(cat $B/status)" | tee $log
echo "t_s maxcpu(zone) maxgpu batt_C cpu0/3/7_MHz gpu_MHz cdev_cur(c0 c3 c7 gpu wifi) batt_mA status" | tee -a $log
t0=$(date +%s)
while [ $(date +%s) -lt $end ]; do
  maxc=0; maxcn=; maxg=0; maxall=0; maxalln=
  for z in /sys/class/thermal/thermal_zone*; do
    t=$(cat $z/temp 2>/dev/null) || continue; n=$(cat $z/type)
    [ "$t" -gt "$maxall" ] && { maxall=$t; maxalln=$n; }
    case $n in cpu-*) [ "$t" -gt "$maxc" ] && { maxc=$t; maxcn=$n; };; gpuss-*) [ "$t" -gt "$maxg" ] && maxg=$t;; esac
  done
  bt=$(cat $B/temp); f0=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)/1000 ))
  f3=$(( $(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq)/1000 )); f7=$(( $(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq)/1000 ))
  gf=$(( $(cat /sys/class/devfreq/3d00000.qcom,kgsl-3d0/cur_freq)/1000000 ))
  cd_=$(for i in 0 1 2 3 4; do cat /sys/class/thermal/cooling_device$i/cur_state; done | tr '\n' ' ')
  echo "$(( $(date +%s)-t0 )) $((maxc/1000))($maxcn) $((maxg/1000)) $((bt/10)).$((bt%10)) $f0/$f3/$f7 $gf $cd_ $(( $(cat $B/current_now)/1000 )) $(cat $B/status)" | tee -a $log
  if [ "$maxall" -ge $((lim*1000)) ] || [ "$bt" -ge $((blim*10)) ]; then echo "ABORT: $maxalln=$((maxall/1000))C batt=$((bt/10))C over limit" | tee -a $log; break; fi
  sleep 5
done
echo "# end $(date +%T) batt=$(cat $B/capacity)% log=$log" | tee -a $log
