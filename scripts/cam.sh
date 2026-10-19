#!/usr/bin/env bash
# Grab one webcam frame of the tablet screen (eMeet C980 Pro at /dev/video0, pointed at the display).
# usage: scripts/cam.sh [out.jpg]   (default photos/cam-<time>.jpg). Prints the file path.
set -euo pipefail
out=${1:-$(dirname "$0")/../photos/cam-$(date +%H%M%S).jpg}
timeout 20 ffmpeg -loglevel error -f v4l2 -video_size 1280x720 -i /dev/video0 -frames:v 1 -update 1 -y "$out"
realpath "$out"
