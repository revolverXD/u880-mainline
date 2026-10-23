#!/bin/bash
# Runs ON the tablet: profile a play session. Every 5 s one CSV row to /root/game-profile.csv (CPU/GPU load and clocks, temperatures,
# cooling states, battery power, memory, Wi-Fi), kernel warnings/errors to /root/game-profile-dmesg.log. Stops after $1 minutes (default 45).
# usage: systemd-run --unit=game-profile /root/game-profile.sh 45      stop early: systemctl stop game-profile
MIN=${1:-45}; CSV=/root/game-profile.csv; DM=/root/game-profile-dmesg.log
B=/sys/class/power_supply/qcom-battmgr-bat; G=/sys/class/devfreq/3d00000.qcom,kgsl-3d0
echo "time,bat_pct,bat_C,bat_mA,bat_V,power_W,cpu_busy_pct,load1,f_little,f_gold,f_prime,cpu_max_C,cpu_max_zone,gpu_zone_C,ddr_C,gpu_MHz,gpu_busy_pct,cool_l,cool_g,cool_p,cool_gpu,top_proc,top_cpu_pct,mem_avail_MB,swap_used_MB,wifi_dBm,wifi_rx_Mbps,wifi_tx_Mbps,screen" > $CSV
: > $DM
dmesg -w -l warn,err 2>/dev/null | grep --line-buffered -v -E "novatek|Error selecting event page|slot .* out of range|unknown state" > $DM &
DMPID=$!
trap 'kill $DMPID 2>/dev/null' EXIT
declare -A prevg; k=0; GP=""; read -r _ u n s i io irq sirq st _ < /proc/stat; pt=$((u+n+s+i+io+irq+sirq+st)); pi=$((i+io))
end=$(( $(date +%s) + MIN*60 ))
zone() { for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type) $(cat $z/temp)"; done; }
while [ $(date +%s) -lt $end ]; do
  read -r _ u n s i io irq sirq st _ < /proc/stat; t=$((u+n+s+i+io+irq+sirq+st)); idle=$((i+io))
  cpu=$(( (100*((t-pt)-(idle-pi))) / ( (t-pt) > 0 ? (t-pt) : 1 ) )); pt=$t; pi=$idle
  Z=$(zone)
  cmax=$(echo "$Z" | awk '$1 ~ /^cpu-/ {if ($2>m) {m=$2; n=$1}} END {printf "%d,%s", m/1000, n}')
  gz=$(echo "$Z" | awk '$1 ~ /^gpuss/ {if ($2>m) m=$2} END {print int(m/1000)}'); dd=$(echo "$Z" | awk '$1=="ddr" {print int($2/1000)}')
  if [ $((k % 6)) -eq 0 ]; then GP=""; for p in $(ls /proc | grep -E '^[0-9]+$'); do for f in /proc/$p/fd/*; do case "$(readlink $f 2>/dev/null)" in /dev/dri/render*) GP="$GP $p"; break;; esac; done; done; fi; k=$((k+1))
  gb=0; for p in $GP; do
    tot=0; seen=""
    for f in /proc/$p/fd/*; do l=$(readlink $f 2>/dev/null); case $l in /dev/dri/render*) ;; *) continue;; esac
      id=$(grep -E "^drm-client-id" /proc/$p/fdinfo/${f##*/} 2>/dev/null | awk '{print $2}'); case " $seen " in *" $id "*) continue;; esac; seen="$seen $id"
      ns=$(grep -E "^drm-engine-gpu" /proc/$p/fdinfo/${f##*/} 2>/dev/null | awk '{print $2}'); tot=$((tot + ${ns:-0})); done
    [ -n "$seen" ] || continue; d=$((tot - ${prevg[$p]:-$tot})); prevg[$p]=$tot; gb=$((gb + d/50000000))
  done; [ $gb -gt 100 ] && gb=100
  cur=$(cat $B/current_now); vol=$(cat $B/voltage_now); pw=$(awk -v c=$cur -v v=$vol 'BEGIN {c=(c<0?-c:c); printf "%.2f", c*v/1e12}')
  top=$(ps -eo pcpu,comm --sort=-pcpu | sed -n 2p | awk '{print $2","$1}')
  wl=$(iw dev wlan0 link 2>/dev/null); sig=$(echo "$wl" | awk '/signal/ {print $2}'); rx=$(echo "$wl" | awk '/rx bitrate/ {print $3}'); tx=$(echo "$wl" | awk '/tx bitrate/ {print $3}')
  scr=$(cat /sys/class/drm/card1-DSI-1/dpms 2>/dev/null)
  echo "$(date +%T),$(cat $B/capacity),$(( $(cat $B/temp)/10 )),$((cur/1000)),$(awk -v v=$vol 'BEGIN {printf "%.2f", v/1e6}'),$pw,$cpu,$(cut -d' ' -f1 /proc/loadavg),$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)/1000 )),$(( $(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq)/1000 )),$(( $(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq)/1000 )),$cmax,$gz,$dd,$(( $(cat $G/cur_freq)/1000000 )),$gb,$(cat /sys/class/thermal/cooling_device0/cur_state),$(cat /sys/class/thermal/cooling_device1/cur_state),$(cat /sys/class/thermal/cooling_device2/cur_state),$(cat /sys/class/thermal/cooling_device3/cur_state),$top,$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo),$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print int((t-f)/1024)}' /proc/meminfo),$sig,$rx,$tx,$scr" >> $CSV
  sleep 5
done
