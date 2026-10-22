#!/usr/bin/env bash
# Watch the panel after a power-key off/on cycle, without touching anything else.
# Prints ffmpeg signalstats for a crop of the screen: YAVG (light), UAVG/VAVG (blue/red chroma).
set -uo pipefail
S=/home/USER/External/work/src/mainline
rssh() { U880_HOST=192.168.X.Y timeout 30 bash $S/scripts/rssh.sh "$1"; }
measure() {
  local f=/tmp/watch-$1.jpg y
  timeout 10 ffmpeg -nostdin -loglevel error -f v4l2 -input_format mjpeg -video_size 1280x720 \
    -i /dev/video0 -frames:v 1 -y "$f"
  y=$(ffmpeg -nostdin -loglevel info -i "$f" -vf "crop=400:150:500:250,signalstats,metadata=print" -f null - 2>&1 \
      | grep -oE "(YAVG|UAVG|VAVG)=[0-9.]+" | tr '\n' ' ')
  echo "$1: $y"
}
measure before
rssh 'touch /tmp/power-press'; sleep 4; measure off
rssh 'touch /tmp/power-press'
prev=0
for t in 3 8 15 30 60; do sleep $((t-prev)); prev=$t; measure "on+${t}s"; done
