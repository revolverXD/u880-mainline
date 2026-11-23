#!/usr/bin/env bash
# Install the SDDM session chooser + the Denial session on the tablet (files from tablet-rootfs/), keeping the old theme in /root/u880-backup/.
# Takes effect at the next SDDM greeter start (log out or reboot); the last chosen session is remembered (RememberLastSession=true).
# Rollback over ssh: cp /root/u880-backup/sddm-u880-Main.qml.before-chooser /usr/share/sddm/themes/u880/Main.qml; rm /usr/share/wayland-sessions/u880-denial.desktop
set -euo pipefail
M=/home/USER/External/work/src/mainline; R=$M/tablet-rootfs; rs() { "$M/scripts/rssh.sh" "$@"; }
rs 'mkdir -p /root/u880-backup; cp -n /usr/share/sddm/themes/u880/Main.qml /root/u880-backup/sddm-u880-Main.qml.before-chooser'
for f in /usr/local/bin/u880-denial-session /usr/share/wayland-sessions/u880-denial.desktop /usr/share/sddm/themes/u880/Main.qml; do
  mode=$(stat -c %a "$R$f"); cat "$R$f" | rs "cat > $f.new && chmod $mode $f.new && mv $f.new $f"
done
rs 'which denial-session; ls /usr/share/wayland-sessions'
