#!/bin/sh
# After the power key brings the panel back, drive the UI (click, then a drag) and see if the picture
# returns. If it does, only the first frame after the wake is missing, not the whole display path.
# Run as root. The panel stays dark in the photos if nothing is displayed.
set -e
shot() { runuser -u USER -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1 grim "/tmp/wk-$1.png"; }
touch /tmp/power-press; sleep 4            # display off
touch /tmp/power-press; sleep 6            # display on: this is the state that stays dark
echo "click 800 500" > /tmp/u880-ui; sleep 2
echo "drag 800 500 200 300" > /tmp/u880-ui; sleep 2
echo "key meta" > /tmp/u880-ui; sleep 3
shot interact
ls -l /tmp/wk-interact.png
