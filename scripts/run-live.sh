#!/usr/bin/env bash
# Boot the stage-1 mainline image for an interactive session (no auto-reboot) and wait for the USB serial gadget.
# usage: run-live.sh [dtb]   Env: CPUOPTS (default empty), KIMG (default 6.17.11 Image), EXTRA (more cmdline)
set -u
M=/home/USER/External/work/src/mainline; DTB=${1:-$M/stage1/dtb2-disabled.dtb}; IMG=$M/stage1/live.img
CPUOPTS=${CPUOPTS-}   # cpuidle works since 2026-10-18 (psci_idle, OSI); was cpuidle.off=1
KIMG=${KIMG:-$M/linux-6.17.11/arch/arm64/boot/Image}
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 \
  --os_version 14.0.0 --os_patch_level 2024-03 --kernel $KIMG \
  --ramdisk $M/stage1/initramfs.cpio.gz --dtb "$DTB" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  --cmdline "console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=8 rdinit=/init $CPUOPTS ${EXTRA:-}" -o $IMG >/dev/null
wait_fb() { for i in $(seq 1 60); do timeout 5 fastboot devices | grep -q . && return 0; sleep 2; done; return 1; }
timeout 5 fastboot devices | grep -q . || timeout 20 adb reboot bootloader >/dev/null 2>&1
wait_fb || { echo NO_FASTBOOT; exit 3; }
timeout 20 fastboot reboot bootloader >/dev/null 2>&1; sleep 5; wait_fb || { echo NO_FASTBOOT; exit 3; }
timeout 10 fastboot getvar product >/dev/null 2>&1 || { echo FASTBOOT_WEDGED; exit 4; }
timeout 60 fastboot boot $IMG >/dev/null 2>&1; T0=$(date +%s); echo "booted $(date +%T)"
for i in $(seq 1 60); do
  for d in /sys/bus/usb/devices/*; do
    [ -f $d/idVendor ] || continue
    v=$(cat $d/idVendor):$(cat $d/idProduct)
    case $v in 18d1:*|05c6:*|1d6b:*) ;; *) [ "$(basename $d)" = "5-4.3.3" ] && echo "$(( $(date +%s)-T0 ))s: new USB device $v $(cat $d/product 2>/dev/null) at $(basename $d)";; esac
  done
  ls /dev/ttyACM* 2>/dev/null && { echo "serial gadget up after $(( $(date +%s)-T0 ))s"; exit 0; }
  sleep 2
done
echo "no serial gadget after $(( $(date +%s)-T0 ))s"
