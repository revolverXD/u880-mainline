#!/usr/bin/env bash
# Repack stage1/initramfs-u880c.cpio.gz with the UFS modules of the current linux-7.2.9 build -> stage1/initramfs-<tag>.cpio.gz.
# The initramfs carries its own ufs-qcom/qcom_ice/phy-qcom-qmp-ufs; a kernel whose release (LOCALVERSION) differs from them refuses to load them and hangs at boot (seen 2026-10-22 with -u880d).
# usage: build-initramfs-ufs.sh <tag, e.g. u880d>
set -euo pipefail
M=/home/USER/External/work/src/mainline; T=$M/linux-7.2.9; D=$(mktemp -d); trap 'rm -rf $D' EXIT
cd $D && zcat $M/stage1/initramfs-u880c.cpio.gz | cpio -id --quiet
for f in ufs-qcom qcom_ice phy-qcom-qmp-ufs; do cp $(find $T/drivers -name $f.ko | head -1) lib/modules-ufs/$f.ko; done
find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > $M/stage1/initramfs-${1:?tag}.cpio.gz
