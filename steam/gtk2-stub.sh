#!/bin/bash
# Build libgtk-x11-2.0.so.0 for the native ARM64 Steam client: an empty library that depends on GTK3 (Arch has no GTK2; Steam's menus/tray use gtk_menu_* etc. which GTK3 provides under the same names).
# Do NOT make it a no-op stub (menus then never open). GTK3's X11 backend crashes in gdk_display_open on Xwayland: the launcher sets GDK_BACKEND=wayland. usage: gtk2-stub.sh <dir>
set -e
D=${1:?dir}
echo 'void u880_gtk2_shim(void){}' | gcc -shared -fPIC -x c - -o $D/libgtk-x11-2.0.so.0 -Wl,-soname,libgtk-x11-2.0.so.0 -Wl,--no-as-needed -lgtk-3
