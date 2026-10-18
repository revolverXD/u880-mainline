#!/usr/bin/env bash
# Pack stage1/initramfs/ (busybox rescue init + firmware the kernel needs before the SD root is mounted)
# into stage1/initramfs.cpio.gz, the ramdisk that run-live.sh / boot-alarm.sh put into the boot image.
set -e
M=$(cd "$(dirname "$0")/.." && pwd)
cd "$M/stage1/initramfs"
find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > "$M/stage1/initramfs.cpio.gz"
ls -la "$M/stage1/initramfs.cpio.gz"
