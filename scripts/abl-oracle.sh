#!/usr/bin/env bash
# Usage: abl-oracle.sh <dtb>  -> prints ACCEPT or REJECT.
# Packs the PSCI-reset payload + <dtb> as header v2, fastboot-boots it from a fresh ABL.
# ACCEPT: ABL jumped (device resets to Android; we then return it to fastboot). REJECT: ABL stayed in fastboot.
set -u
M=/home/USER/External/work/src/mainline
DTB=$1; IMG=$M/stage1/oracle-tmp.img
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 \
  --os_version 14.0.0 --os_patch_level 2024-03 --kernel $M/stage1/reset-payload.Image \
  --ramdisk $M/stage1/initramfs.cpio.gz --dtb "$DTB" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 --cmdline "x" -o $IMG || { echo MKBOOTIMG_FAIL; exit 2; }
wait_fb() { for i in $(seq 1 60); do fastboot devices | grep -q . && return 0; sleep 2; done; return 1; }
if ! fastboot devices | grep -q .; then timeout 20 adb reboot bootloader >/dev/null 2>&1; fi
wait_fb || { echo NO_FASTBOOT; exit 3; }
timeout 20 fastboot reboot bootloader >/dev/null 2>&1 || echo "WARN: fastboot reboot timed out" >&2; sleep 5; wait_fb || { echo NO_FASTBOOT; exit 3; }
# ABL must answer before we trust the result (a wedged fastboot looks like REJECT)
timeout 10 fastboot getvar product >/dev/null 2>&1 || { echo FASTBOOT_WEDGED; exit 4; }
timeout 60 fastboot boot $IMG >/dev/null 2>&1
sleep 10
if fastboot devices | grep -q .; then
  echo REJECT
else
  echo ACCEPT
  for i in $(seq 1 60); do adb devices | tail -n +2 | grep -q device && break; sleep 3; done
  timeout 20 adb reboot bootloader >/dev/null 2>&1; wait_fb >/dev/null
fi
rm -f $IMG
