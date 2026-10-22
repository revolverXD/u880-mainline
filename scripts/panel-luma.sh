#!/usr/bin/env bash
# Camera photometry of the panel in three states: current, DPMS off, DPMS on.
# Prints ffmpeg signalstats YAVG (0-255) for a crop of the screen area.
set -uo pipefail
shot() { # shot <tag>
  local f=/tmp/luma-$1.jpg
  timeout 10 ffmpeg -nostdin -loglevel error -f v4l2 -input_format mjpeg -video_size 1280x720 \
    -i /dev/video0 -frames:v 1 -y "$f"
  local y
  y=$(ffmpeg -nostdin -loglevel info -i "$f" -vf "crop=400:150:500:250,signalstats,metadata=print:key=lavfi.signalstats.YAVG" -f null - 2>&1 \
      | grep -o 'YAVG=[0-9.]*' | head -1)
  echo "$1: $y  ($f)"
}
shot cur
touch /tmp/power-press; sleep 4; shot off
touch /tmp/power-press; sleep 6; shot on
