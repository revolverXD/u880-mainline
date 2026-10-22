#!/bin/bash
# Build a no-op libgtk-x11-2.0.so.0 for the native ARM64 Steam client (it only uses GTK2 for its tray menu; real GTK3 crashes in gdk_display_open on Xwayland). usage: gtk2-stub.sh <dir>
set -e
D=${1:?dir}; T=$(mktemp -d)
{ echo 'long u880_stub_ret0(void){return 0;}'
  for f in $(cd $D && for l in steamui.so steam steamwebhelper vgui2_s.so; do nm -D --undefined-only $l 2>/dev/null; done | grep -oE ' U (gtk|gdk)_[a-z0-9_]+$' | sed 's/ U //' | grep -v '^gdk_pixbuf' | sort -u); do
    echo "long $f(){return 0;}"; done; } > $T/stub.c
gcc -shared -fPIC -o $D/libgtk-x11-2.0.so.0 -Wl,-soname,libgtk-x11-2.0.so.0 $T/stub.c; rm -rf $T
nm -D --defined-only $D/libgtk-x11-2.0.so.0 | grep -c ' T '
