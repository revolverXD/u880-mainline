#!/usr/bin/env bash
# Build a ready-to-write ext4 root filesystem IMAGE for the U880 on the PC, so nothing has to be formatted or unpacked on the tablet
# (the rescue initramfs has no mkfs and only busybox tar, which drops xattrs/capabilities). Run as root:
#   sudo TARBALL=ArchLinuxARM-aarch64-latest.tar.gz MODULES=<kernel modules_install dir>/lib/modules/<release> FWDIR=<firmware overlay> \
#        [TABLET_USER=alarm] [IMG_SIZE=10G] scripts/build-rootfs-image.sh <out.img>
# TARBALL  verified Arch Linux ARM tarball (README step 8)
# MODULES  the built kernel modules of the SAME release as the boot image (its `build`/`source` symlinks are skipped)
# FWDIR    directory laid out like / with the firmware you extracted from your own stock images and the locally built blobs of
#          tablet-rootfs/BLOBS (README step 7), e.g. FWDIR/usr/lib/firmware/qcom/gen71100_zap.mbn
# SSH_PUBKEY  file with your SSH public key: installed as authorized_keys for root and TABLET_USER (the tarball has none; otherwise log in as alarm/alarm)
# ROOT_LABEL  filesystem label (default u880root; use another one, e.g. u880sdtest, for a second root next to an installed one: the udev read-only rule, fstab and u880-growfs all key on it)
# The image is sparse (IMG_SIZE, default 10G); the first boot grows it to the whole partition (u880-growfs.service).
# Then write it to the root partition from the rescue shell: README step 8 / scripts/install-from-rescue.md.
set -euo pipefail
OUT=${1:?out.img}; M=$(cd "$(dirname "$0")/.." && pwd); R=$M/tablet-rootfs
: "${TARBALL:?}" "${MODULES:?}" "${FWDIR:?}"; U=${TABLET_USER:-alarm}; SZ=${IMG_SIZE:-10G}; LBL=${ROOT_LABEL:-u880root}
[ "$(id -u)" = 0 ] || { echo "run as root (sudo): file owners, device nodes and xattrs of the tarball need it"; exit 1; }
for f in "$TARBALL" "$MODULES/modules.dep" "$FWDIR"; do [ -e "$f" ] || { echo "missing: $f"; exit 2; }; done
REL=$(basename "$MODULES"); W=$(mktemp -d /var/tmp/u880-rootfs.XXXXXX); trap 'rm -rf "$W"' EXIT; T=$W/root; mkdir "$T"
echo "== 1. unpack the Arch tarball (numeric owners, xattrs, ACLs)"
# the ALARM tarball is made by libarchive: only bsdtar restores its file capabilities (ping, newuidmap, ...); GNU tar prints "Ignoring unknown extended header keyword" and drops them
if command -v bsdtar >/dev/null; then bsdtar -xpf "$TARBALL" -C "$T" --numeric-owner --xattrs --acls
else echo "WARNING: no bsdtar (libarchive): file capabilities are lost (ping, newuidmap); install libarchive or reinstall those packages after first boot"
  tar --numeric-owner --xattrs --xattrs-include='*' --acls -xpf "$TARBALL" -C "$T"; fi
echo "== 2. kernel modules $REL + depmod"
mkdir -p "$T/usr/lib/modules"; rm -rf "$T/usr/lib/modules/$REL"
tar -C "$(dirname "$MODULES")" --exclude="$REL/build" --exclude="$REL/source" -cf - "$REL" | tar -C "$T/usr/lib/modules" -xf -
depmod -b "$T/usr" "$REL" 2>/dev/null || depmod -b "$T" "$REL"
echo "== 3. firmware and blobs from $FWDIR"
cp -a --no-preserve=ownership "$FWDIR"/. "$T"/; chown -R 0:0 "$T/usr/lib/firmware" "$T/usr/local" 2>/dev/null || true
echo "== 4. project configuration (tablet-rootfs/PATHS), what 'tablet-config.sh push' does, offline"
UID_U=$(awk -F: -v u="$U" '$1==u{print $3":"$4}' "$T/etc/passwd"); [ -n "$UID_U" ] || { echo "user $U is not in the tarball's /etc/passwd"; exit 3; }
n=0
while read -r p; do
  case "$p" in ''|'#'*) continue;; /etc/fstab) continue;; esac       # fstab is written below: ours names the owner's SD card
  src=$R$p; dst=$p; own=0:0
  case $p in /home/*) h=${p#/home/}; h=${h%%/*}; dst=/home/$U/${p#/home/$h/}; own=$UID_U;; esac   # the mirror's home directory -> TABLET_USER's
  [ -f "$src" ] || { echo "  not in repo: $p"; continue; }
  install -D -m "$(stat -c %a "$src")" "$src" "$T$dst"
  # the public export replaces the owner's name by the placeholder USER: use the real user here
  grep -qI . "$T$dst" && sed -i "s#/home/USER/#/home/$U/#g; s#^User=USER\$#User=$U#" "$T$dst"
  if [ "$own" != 0:0 ]; then d=$T$dst; while [ "$d" != "$T/home/$U" ]; do chown "$own" "$d"; d=$(dirname "$d"); done; else chown 0:0 "$T$dst"; fi
  n=$((n+1))
done < "$R/PATHS"
echo "  $n files"
# the UCM entry for the sound card is a symlink in the distro's conf.d (a PATHS file copy cannot carry it): without it PipeWire only offers off/pro-audio and there is no speaker sink
if [ -d "$T/usr/share/alsa/ucm2/Qualcomm/sm8550/U880" ]; then install -d "$T/usr/share/alsa/ucm2/conf.d/sm8550"; ln -sf ../../Qualcomm/sm8550/U880/U880.conf "$T/usr/share/alsa/ucm2/conf.d/sm8550/U880.conf"; fi
# system user/group for hexagonrpcd (ADSP sensors, FastRPC): it must exist BEFORE the first boot, or udev cannot apply GROUP="fastrpc" to /dev/fastrpc-adsp (root:root 0600) and the service dies with 4/NOPERMISSION
grep -q '^fastrpc:' "$T/etc/group" || { echo 'fastrpc:x:961:' >> "$T/etc/group"; echo 'fastrpc:!*::' >> "$T/etc/gshadow"; }
grep -q '^fastrpc:' "$T/etc/passwd" || { echo 'fastrpc:x:961:961::/var/lib/hexagonrpcd:/usr/bin/nologin' >> "$T/etc/passwd"; echo 'fastrpc:!*:20000::::::' >> "$T/etc/shadow"; }
printf '# root filesystem (ext4, label %s)\nLABEL=%s  /  ext4  rw,noatime  0 1\n' "$LBL" "$LBL" > "$T/etc/fstab"
[ "$LBL" = u880root ] || grep -rl u880root "$T/etc/udev/rules.d" 2>/dev/null | xargs -r sed -i "s/u880root/$LBL/g"
cat > "$T/etc/systemd/system/u880-growfs.service" <<'EOF'
[Unit]
Description=Grow the root filesystem to the whole partition (first boot)
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/usr/bin/resize2fs /dev/disk/by-label/@LBL@
[Install]
WantedBy=multi-user.target
EOF
sed -i "s/@LBL@/$LBL/" "$T/etc/systemd/system/u880-growfs.service"
for u in u880-bt-addr u880-boot-success u880-icc-sync u880-mem-sleep u880-powerlog u880-sdp-budget u880-touch-follow-screen u880-usb-ss-retrain hexagonrpcd-adsp-sensorspd u880-thermal-guard u880-bt-connectable u880-zram u880-gpu-sample u880-growfs; do
  [ -e "$T/etc/systemd/system/$u.service" ] || [ -e "$T/usr/lib/systemd/system/$u.service" ] || [ -e "$T/usr/local/lib/systemd/system/$u.service" ] || { echo "  unit missing, not enabled: $u"; continue; }
  systemctl --root="$T" enable "$u.service" >/dev/null 2>&1 || echo "  could not enable $u"
done
if [ -n "${SSH_PUBKEY:-}" ]; then
  [ -f "$SSH_PUBKEY" ] || { echo "no such file: $SSH_PUBKEY"; exit 4; }
  install -d -m 700 "$T/root/.ssh" && install -m 600 "$SSH_PUBKEY" "$T/root/.ssh/authorized_keys"
  install -d -m 700 -o "${UID_U%%:*}" -g "${UID_U##*:}" "$T/home/$U/.ssh" && install -m 600 -o "${UID_U%%:*}" -g "${UID_U##*:}" "$SSH_PUBKEY" "$T/home/$U/.ssh/authorized_keys"
fi
echo "== 5. ext4 image $SZ (label u880root)"
rm -f "$OUT"; truncate -s "$SZ" "$OUT"
mkfs.ext4 -q -L "$LBL" -b 4096 -m 1 -E root_owner=0:0 -d "$T" "$OUT"
e2fsck -fn "$OUT" | tail -2
ls -ls "$OUT"; sha256sum "$OUT" | tee "$OUT.sha256"
echo "OK: $OUT   (default logins alarm/alarm and root/root: change them before the tablet joins a network, README step 8.4)"
