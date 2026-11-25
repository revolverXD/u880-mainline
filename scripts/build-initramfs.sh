#!/usr/bin/env bash
# Pack stage1/initramfs/ (busybox rescue init + firmware the kernel needs before the SD root is mounted)
# into stage1/initramfs.cpio.gz, the ramdisk that run-live.sh / boot-alarm.sh put into the boot image.
set -e
M=$(cd "$(dirname "$0")/.." && pwd)
FW="$M/stage1/initramfs/lib/firmware/qcom"
for f in gen71100_sqe.fw gen71100_gmu.bin gen71100_zap.mbn; do
  [ -s "$FW/$f" ] || [ -n "${ALLOW_NO_GPU_FW:-}" ] || { echo "missing $FW/$f: extract your own GPU firmware (README step 7), or set ALLOW_NO_GPU_FW=1 to build a ramdisk without GPU (no rendering)"; exit 1; }
done
cd "$M/stage1/initramfs"
find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > "$M/stage1/initramfs.cpio.gz"
ls -la "$M/stage1/initramfs.cpio.gz"
