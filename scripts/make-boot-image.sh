#!/usr/bin/env bash
# Pack the production boot image: kernel Image + stage1/initramfs-u880c.cpio.gz + a DTB, the cmdline of the installed images.
# usage: [DEV=1] make-boot-image.sh <dtb> <out.img>          e.g. stage1/dtb2-native-dp3-20261022.dtb stage1/u880-boot-prod-dp.img
# DTB: DISP=4 GPU=1 USB3=1 POWER=1 DP=1 ALLOW=scripts/allow-2a.txt nix-shell -p dtc --run "bash scripts/build-stock-disabled.sh" -> stage1/dtb2-disabled.dtb
# Flash (from the running tablet, boot_b stays marked successful; boot_a ran out of tries, FINDINGS F18):
#   cat <out.img> | rssh.sh 'cat > /root/boot.img'; rssh.sh 'dd if=/dev/sde40 of=/root/u880-backup/boot_b-prev.img bs=4M; blockdev --setrw /dev/sde /dev/sde40 &&
#     dd if=/root/boot.img of=/dev/sde40 bs=4M conv=fsync; sync; blockdev --setro /dev/sde40 /dev/sde; head -c $(stat -c %s /root/boot.img) /dev/sde40 | sha256sum'
set -euo pipefail
M=/home/USER/External/work/src/mainline
DTB=${1:?dtb}; OUT=${2:?out.img}
CMDLINE=${CMDLINE:-"console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=ufs cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=0x0 msm.u880_dbg2=0 fw_devlink.sync_state=timeout apparmor=1 security=apparmor"}   # CMDLINE=... overrides (RAM-boot experiments)
# Production images turn debugfs off (issue #24); DEV=1 keeps it on for display/power bring-up (RAM-boot that image, do not flash it).
[ "${DEV:-0}" = 1 ] || CMDLINE="$CMDLINE debugfs=off"
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 14.0.0 --os_patch_level 2024-03 \
  --kernel ${KIMAGE:-$M/linux-7.3.1/arch/arm64/boot/Image} --ramdisk ${RAMDISK:-$M/stage1/initramfs-u880c.cpio.gz} --dtb "$DTB" \
  --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  --cmdline "$CMDLINE" \
  -o "$OUT"
sha256sum "$OUT" | cut -c1-16
