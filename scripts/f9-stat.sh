#!/usr/bin/env bash
# usage: stat3.sh <variant> <runs> [arg3]; photo 4 s after the "on" line, hold long enough that cyc is still running
S=/home/USER/External/work/src/mainline; F=/tmp/claude-1000/f9
for n in $(seq 1 $2); do
  : > $F/lines.txt
  (timeout 60 $S/scripts/rssh.sh "OFFMS=${OFFMS:-4000} stdbuf -oL /root/cyc $1 12 ${3:-0}" > $F/lines.txt 2>&1 &)
  for i in $(seq 1 100); do grep -q "^on:" $F/lines.txt && break; sleep 0.2; done
  sleep ${4:-4}
  timeout 10 ffmpeg -nostdin -loglevel error -f v4l2 -input_format mjpeg -video_size 1280x720 -i /dev/video0 -frames:v 1 -y $F/t$1-$n.jpg
  y=$(ffmpeg -nostdin -loglevel info -i $F/t$1-$n.jpg -vf "crop=400:150:500:250,signalstats,metadata=print" -f null - 2>&1 | grep -oE "YAVG=[0-9.]+")
  echo "v$1 run$n $y"
  sleep 12
done
