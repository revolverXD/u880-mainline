#!/usr/bin/env bash
# Standalone Linux boot image for boot_b (same as what scripts/boot-alarm.sh fastboot-boots, but flashable).
# Output: stage1/u880-boot.img. Flash: fastboot flash boot_b stage1/u880-boot.img (see NOTES.md "Standalone boot").
set -e
M=/home/USER/External/work/src/mainline
KIMG=$M/linux-7.2.9/arch/arm64/boot/Image
DTB=$M/stage1/dtb2-disabled.dtb
# Native display (DISP=4): GPU and KMS in one msm DRM device, so no msm.separate_gpu_kms.
[ "${DISP:-0}" = 4 ] && SEP= || SEP=msm.separate_gpu_kms=1
EXTRA="regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=sd $SEP cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0"
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 \
  --os_version 14.0.0 --os_patch_level 2024-03 --kernel $KIMG \
  --ramdisk $M/stage1/initramfs.cpio.gz --dtb "$DTB" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  --cmdline "console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init $EXTRA" -o $M/stage1/u880-boot.img
ls -la $M/stage1/u880-boot.img
