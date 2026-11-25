#!/usr/bin/env bash
# Write a root filesystem image (scripts/build-rootfs-image.sh) to an SD card in the PC's card reader, check it, grow it to the card.
# Run as root ON THE PC (not on the tablet: the tablet's slot writes slowly, a 3.6 GB image took 30+ minutes there and 5 minutes here):
#   sudo bash scripts/write-sd-image.sh <image.img> /dev/sdX
# DESTROYS everything on the card. It refuses anything that is not a removable disk of 8-512 GB, or is mounted.
# Shrink the image first to write less: cp --sparse=always img min.img; e2fsck -f min.img; resize2fs -M min.img; truncate -s <block count * 4096> min.img
set -euo pipefail
IMG=${1:?image}; D=${2:?device, e.g. /dev/sde}; N=$(basename "$D")
[ -b "$D" ] || { echo "not a block device: $D"; exit 1; }
[ "$(cat /sys/block/$N/removable)" = 1 ] || { echo "$D is not removable, refusing"; exit 1; }
B=$(blockdev --getsize64 "$D"); [ "$B" -ge 8000000000 ] && [ "$B" -le 512000000000 ] || { echo "$D is $B bytes, not an SD card of 8-512 GB, refusing"; exit 1; }
grep -q "^$D" /proc/mounts && { echo "$D is mounted, unmount it first"; exit 1; }
SZ=$(stat -c %s "$IMG"); WANT=$(sha256sum "$IMG" | cut -c1-64)
echo "card: $D  $((B/1000000000)) GB  $(cat /sys/block/$N/device/model 2>/dev/null)   image: $IMG  $((SZ/1000000)) MB"; lsblk -o NAME,SIZE,FSTYPE,LABEL "$D"
read -r -p "Everything on $D will be erased. Type YES: " a; [ "$a" = YES ] || exit 1
wipefs -a "${D}"[0-9]* >/dev/null 2>&1 || true; wipefs -a "$D" >/dev/null
printf 'label: dos\n,,L\n' | sfdisk -q "$D"; partprobe "$D"; sleep 2
P=${D}1; [ -b "$P" ] || P=${D}p1
s=$(date +%s); dd if="$IMG" of="$P" bs=4M conv=fsync status=progress; sync
echo "written in $(( $(date +%s)-s )) s"
GOT=$(head -c "$SZ" "$P" | sha256sum | cut -c1-64); echo "read back: $GOT"; [ "$GOT" = "$WANT" ] || { echo "CHECKSUM MISMATCH"; exit 2; }
e2fsck -fy "$P" | tail -2; resize2fs "$P"; e2fsck -fn "$P" | tail -1; blkid "$P"
echo "OK: card ready. Put it in the tablet."
