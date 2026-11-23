#!/usr/bin/env bash
# Write a boot image to boot_b from the running tablet with dd (Linux side; no fastboot), backing up the current boot_b first, then verify the sha256 of the written bytes.
# usage: U880_HOST=<ip> flash-boot-b-dd.sh <boot.img> <backup-name>      e.g. stage1/u880-boot-prod-u880e-t23.img boot_b-before-t23
# After the write the slot is marked NOT successful (retry 7), so a bad image is counted down by ABL and the tablet falls back to the other slot after 7 boots;
# u880-boot-success.service marks it successful again 90 s after a good boot (FINDINGS F42). Then just reboot.
set -euo pipefail
M=/home/USER/External/work/src/mainline
IMG=${1:?boot image}; BK=${2:?backup name}
[ -f "$IMG" ] || { echo "no such image: $IMG"; exit 2; }
SZ=$(stat -c %s "$IMG"); WANT=$(sha256sum "$IMG" | cut -c1-64)
echo "image $IMG  $SZ bytes  sha256 $WANT"
$M/scripts/rssh.sh "readlink -f /dev/disk/by-partlabel/boot_b" | grep -q '^/dev/sde40$' || { echo "boot_b is not /dev/sde40 on this tablet; aborting"; exit 3; }
cat "$IMG" | $M/scripts/rssh.sh "cat > /root/$BK-new.img; [ \$(stat -c %s /root/$BK-new.img) = $SZ ]"
$M/scripts/rssh.sh "dd if=/dev/sde40 of=/root/u880-backup/$BK.img bs=4M 2>&1 | tail -1; blockdev --setrw /dev/sde /dev/sde40 && dd if=/root/$BK-new.img of=/dev/sde40 bs=4M conv=fsync 2>&1 | tail -1; sync; blockdev --setro /dev/sde40 /dev/sde"
GOT=$($M/scripts/rssh.sh "head -c $SZ /dev/sde40 | sha256sum | cut -c1-64")
echo "written sha256 $GOT"
[ "$GOT" = "$WANT" ] || { echo "MISMATCH"; exit 4; }
echo "OK: boot_b matches the image"
$M/scripts/rssh.sh "blockdev --setrw /dev/sde; python3 /usr/local/bin/u880-gpt-mark-successful /dev/sde boot_b --clear --write; blockdev --setro /dev/sde"
