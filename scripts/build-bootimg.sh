#!/usr/bin/env bash
# Stage 1: compile u880-min.dts and pack Image + initramfs + DTB as a boot image header v2 (for `fastboot boot`).
# Run inside the aosp container after build-kernel.sh. Regenerate stage1/stubs.dtsi on the host first if o25 changes:
#   nix-shell -p dtc --run "bash scripts/gen-stubs.sh > stage1/stubs.dtsi"
set -e
M=/home/USER/External/work/src/mainline
K=$M/linux-6.17.11
S=$M/stage1
cd $S
python3 -I $M/scripts/gen-resmem.py $M/live/live.dts > resmem.dtsi
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $K/include -I $K/scripts/dtc/include-prefixes u880-min.dts -o u880-min.pp.dts
$K/scripts/dtc/dtc -@ -I dts -O dtb -i $S -o u880-min.dtb u880-min.pp.dts
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py \
  --header_version 2 --os_version 14.0.0 --os_patch_level 2024-03 \
  --kernel $K/arch/arm64/boot/Image --ramdisk initramfs.cpio.gz --dtb u880-min.dtb \
  --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000 \
  --pagesize 4096 \
  --cmdline "console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=8 ignore_loglevel rdinit=/init panic=10 reboot=warm" \
  -o boot-stage1.img
ls -la u880-min.dtb boot-stage1.img
sha256sum boot-stage1.img
