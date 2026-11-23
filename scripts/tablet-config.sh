#!/usr/bin/env bash
# Mirror of the tablet's own root-filesystem state (everything that is not in a boot image).
#   tablet-config.sh pull            capture the files in tablet-rootfs/PATHS into tablet-rootfs/<abs path>, hash the blobs in tablet-rootfs/BLOBS
#   tablet-config.sh push            install tablet-rootfs/ onto the tablet (needs root on the tablet; backs up what it replaces)
#   tablet-config.sh modules         install the rebuilt kernel modules that differ from the stock build (modules-out/, from build-kernel-7.sh)
#   tablet-config.sh status          compare the tablet with the repo (changed / missing files)
# Host: U880_HOST (Wi-Fi IP) as for rssh.sh. push/modules write system files and reboot nothing; reload with: systemctl daemon-reload && udevadm control --reload
set -uo pipefail
M=/home/USER/External/work/src/mainline; R=$M/tablet-rootfs
rs() { "$M/scripts/rssh.sh" "$@"; }
paths() { grep -vE '^\s*(#|$)' "$1"; }
# kernel modules we patched; the rest of /usr/lib/modules comes from the stock build
MODS="kernel/drivers/clk/qcom/dispcc-sm8550.ko kernel/drivers/soc/qcom/pmic_glink_altmode.ko kernel/drivers/usb/typec/mux/wcd939x-usbss.ko kernel/drivers/phy/qualcomm/phy-qcom-qmp-combo.ko"
case "${1:-}" in
pull)
  for p in $(paths $R/PATHS); do
    mkdir -p "$R$(dirname $p)"; rs "cat $p" > "$R$p" 2>/dev/null || { echo "missing on tablet: $p"; rm -f "$R$p"; }
  done
  : > $R/BLOBS.sha256
  for p in $(paths $R/BLOBS); do rs "sha256sum $p" 2>/dev/null >> $R/BLOBS.sha256 || echo "missing blob: $p"; done
  for m in $MODS; do rs "sha256sum /usr/lib/modules/7.2.9-u880c/$m" >> $R/BLOBS.sha256; done
  chmod +x $R/usr/local/bin/* $R/usr/lib/systemd/system-sleep/* 2>/dev/null
  echo "pulled $(find $R -type f | wc -l) files; blobs hashed in BLOBS.sha256" ;;
push)
  T=/root/u880-backup/rootfs-$(date +%Y%m%d-%H%M%S)
  rs "mkdir -p $T"
  for p in $(paths $R/PATHS); do
    [ -f "$R$p" ] || { echo "not in repo: $p"; continue; }
    rs "[ -f $p ] && { mkdir -p $T$(dirname $p); cp -a $p $T$p; }; mkdir -p $(dirname $p)"
    mode=$(stat -c %a "$R$p"); owner=root:root; case $p in /home/USER/*) owner=USER:USER;; esac
    cat "$R$p" | rs "cat > $p && chmod $mode $p && chown $owner $p"
  done
  rs "systemctl daemon-reload; udevadm control --reload; for u in u880-bt-addr u880-boot-success u880-icc-sync u880-mem-sleep u880-powerlog u880-sdp-budget u880-touch-follow-screen u880-usb-ss-retrain hexagonrpcd-adsp-sensorspd; do systemctl enable \$u.service 2>&1 | tail -0; done; echo pushed; echo backup=$T" ;;
modules)
  B=$M/modules-out/lib/modules/7.2.9-u880c
  rs "mkdir -p /root/orig-modules"
  for m in $MODS; do
    rs "cp -n /usr/lib/modules/7.2.9-u880c/$m /root/orig-modules/$(basename $m)"
    cat $B/$m | rs "cat > /usr/lib/modules/7.2.9-u880c/$m"
  done
  rs "depmod 7.2.9-u880c && sync && echo modules installed" ;;
status)
  for p in $(paths $R/PATHS); do
    [ -f "$R$p" ] || { echo "not in repo: $p"; continue; }
    a=$(sha256sum < "$R$p" | cut -c1-16); b=$(rs "sha256sum < $p 2>/dev/null" | cut -c1-16)
    [ "$a" = "$b" ] || echo "DIFF $p (repo $a tablet ${b:-missing})"
  done
  B=$M/modules-out/lib/modules/7.2.9-u880c
  for m in $MODS; do a=$(sha256sum < $B/$m | cut -c1-16); b=$(rs "sha256sum < /usr/lib/modules/7.2.9-u880c/$m" | cut -c1-16); [ "$a" = "$b" ] || echo "DIFF module $m (build $a tablet $b)"; done
  echo status done ;;
*) sed -n 2,7p "$0"; exit 2 ;;
esac
