#!/bin/bash
# Runs ON the tablet: every 5 s log GPU busy % per process (from DRM fdinfo drm-engine-gpu deltas) and the GPU clock to /root/gpu-watch.log.
L=/root/gpu-watch.log; : > $L; declare -A prev
while true; do
  line="$(date +%T) gpu_freq=$(cat /sys/class/devfreq/3d00000.qcom,kgsl-3d0/cur_freq 2>/dev/null)"
  for p in $(ls /proc | grep -E '^[0-9]+$'); do
    tot=0; seen=""
    for f in /proc/$p/fd/*; do
      l=$(readlink $f 2>/dev/null); case $l in /dev/dri/render*) ;; *) continue;; esac
      id=$(grep -E "^drm-client-id" /proc/$p/fdinfo/${f##*/} 2>/dev/null | awk '{print $2}'); case " $seen " in *" $id "*) continue;; esac; seen="$seen $id"
      ns=$(grep -E "^drm-engine-gpu" /proc/$p/fdinfo/${f##*/} 2>/dev/null | awk '{print $2}'); tot=$((tot + ${ns:-0}))
    done
    [ -n "$seen" ] || continue
    d=$((tot - ${prev[$p]:-$tot})); prev[$p]=$tot
    pct=$((d / 50000000)); [ $pct -gt 0 ] && line="$line $(cat /proc/$p/comm):${pct}%"
  done
  echo "$line" >> $L; sleep 5
done
