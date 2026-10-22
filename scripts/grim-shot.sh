#!/bin/sh
# Capture what the compositor is rendering, as the user USER (the session owns the control socket).
# Usage: sh grim-shot.sh /tmp/out.png
runuser -u USER -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1 grim "$1"
