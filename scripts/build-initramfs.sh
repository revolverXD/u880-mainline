#!/usr/bin/env bash
# Pack stage1/initramfs/ (busybox init v12: mounts the root named by u880root= (ufs|sd|sd,ufs), plus the UFS modules and GPU firmware the kernel needs before it)
# into stage1/initramfs.cpio.gz, the ramdisk that scripts/make-boot-image.sh puts into the boot image (README step 5).
set -e
M=$(cd "$(dirname "$0")/.." && pwd)
FW="$M/stage1/initramfs/lib/firmware/qcom"
for f in gen71100_sqe.fw gen71100_gmu.bin gen71100_zap.mbn; do
  [ -s "$FW/$f" ] || [ -n "${ALLOW_NO_GPU_FW:-}" ] || { echo "missing $FW/$f: extract your own GPU firmware (README step 7), or set ALLOW_NO_GPU_FW=1 to build a ramdisk without GPU (no rendering)"; exit 1; }
done
for m in ufs-qcom qcom_ice phy-qcom-qmp-ufs; do [ -s "$M/stage1/initramfs/lib/modules-ufs/$m.ko" ] || { echo "missing stage1/initramfs/lib/modules-ufs/$m.ko: copy the three UFS modules of the kernel you built (README step 5), they must match its release"; exit 1; }; done
cd "$M/stage1/initramfs"
# git does not keep empty directories: a fresh clone has no /dev /proc /sys /newroot /tmp, and init cannot mount without them (boot would hang)
mkdir -p dev proc sys newroot tmp
find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > "$M/stage1/initramfs.cpio.gz"
ls -la "$M/stage1/initramfs.cpio.gz"
