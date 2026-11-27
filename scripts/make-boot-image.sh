#!/usr/bin/env bash
# Pack the production boot image: compressed kernel Image.gz (arch/arm64/boot/Image.gz) + stage1/initramfs.cpio.gz + a DTB, the cmdline of the installed images.
# usage: [DEV=1] [ROOT=ufs|sd,ufs] [KIMAGE=<Image.gz>] [RAMDISK=<cpio.gz>] [MKBOOTIMG=<mkbootimg.py>] [CMDLINE=...] make-boot-image.sh <dtb> <out.img>
#   e.g. scripts/make-boot-image.sh stage1/dtb2-u880.dtb stage1/u880-boot.img
# KIMAGE defaults to Image.gz in the newest of linux-7.4-rc4/linux-7.3.1 in the repo root (smaller, 15 MB; the uncompressed 46 MB Image boots too, KIMAGE=.../Image); RAMDISK to stage1/initramfs.cpio.gz (scripts/build-initramfs.sh); MKBOOTIMG to AOSP system/tools/mkbootimg next to the repo
#   (git clone https://android.googlesource.com/platform/system/tools/mkbootimg). ROOT=sd,ufs tries an SD card first and falls back to the internal root (README step 8a); CMDLINE=... replaces the whole command line.
# DTB: dts/u880.dts compiled by scripts/build-dtb-from-dts.sh -> stage1/dtb2-u880.dtb (README step 4; build-stock-disabled.sh is the porting tool that made it)
# Flash (from the running tablet, boot_b stays marked successful; boot_a ran out of tries, FINDINGS F18):
#   cat <out.img> | rssh.sh 'cat > /root/boot.img'; rssh.sh 'dd if=/dev/sde40 of=/root/u880-backup/boot_b-prev.img bs=4M; blockdev --setrw /dev/sde /dev/sde40 &&
#     dd if=/root/boot.img of=/dev/sde40 bs=4M conv=fsync; sync; blockdev --setro /dev/sde40 /dev/sde; head -c $(stat -c %s /root/boot.img) /dev/sde40 | sha256sum'
set -euo pipefail
M=$(cd "$(dirname "$0")/.." && pwd)
DTB=${1:?dtb}; OUT=${2:?out.img}
KI=${KIMAGE:-}; [ -n "$KI" ] || for k in "$M"/linux-7.4-rc4 "$M"/linux-7.3.1; do [ -s "$k/arch/arm64/boot/Image.gz" ] && { KI=$k/arch/arm64/boot/Image.gz; break; }; done
RD=${RAMDISK:-$M/stage1/initramfs.cpio.gz}; MKB=${MKBOOTIMG:-$M/../LineageOS/system/tools/mkbootimg/mkbootimg.py}
[ -s "$KI" ] || { echo "no kernel Image: build the kernel (README step 3) or set KIMAGE="; exit 2; }
[ -s "$RD" ] || { echo "no ramdisk $RD: run scripts/build-initramfs.sh (README step 5) or set RAMDISK="; exit 2; }
[ -s "$MKB" ] || { echo "no mkbootimg.py at $MKB: git clone https://android.googlesource.com/platform/system/tools/mkbootimg and set MKBOOTIMG="; exit 2; }
CMDLINE=${CMDLINE:-"console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=${ROOT:-ufs} cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=0x0 msm.u880_dbg2=0 fw_devlink.sync_state=timeout apparmor=1 security=apparmor"}   # CMDLINE=... overrides
# Production images turn debugfs off (issue #24); DEV=1 keeps it on for display/power bring-up (there is no RAM boot, FINDINGS F43: flash it only for the measurement and flash the production image back).
[ "${DEV:-0}" = 1 ] || CMDLINE="$CMDLINE debugfs=off"
python3 "$MKB" --header_version 2 --os_version 14.0.0 --os_patch_level 2024-03 \
  --kernel "$KI" --ramdisk "$RD" --dtb "$DTB" \
  --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  --cmdline "$CMDLINE" \
  -o "$OUT"
sha256sum "$OUT" | cut -c1-16
