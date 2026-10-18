#!/usr/bin/env bash
# usage: crumb-test.sh <N> [dtb] -> REACHED / NOT_REACHED / REJECT / STUCK, with time to adb.
# Boots the mainline kernel with u880crumb=N; checkpoint N does PSCI SYSTEM_RESET (see init/main.c).
# Env: CPUOPTS (default "maxcpus=1 cpuidle.off=1").
CPUOPTS=${CPUOPTS-maxcpus=1 cpuidle.off=1}
set -u
M=/home/USER/External/work/src/mainline; N=$1; DTB=${2:-$M/stage1/dtb2-disabled.dtb}; IMG=$M/stage1/crumb.img
python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 \
  --os_version 14.0.0 --os_patch_level 2024-03 --kernel $M/linux-6.17.11/arch/arm64/boot/Image \
  --ramdisk $M/stage1/initramfs.cpio.gz --dtb "$DTB" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
  --cmdline "u880crumb=$N x console=tty0 clk_ignore_unused pd_ignore_unused loglevel=8 rdinit=/init panic=10 $CPUOPTS" -o $IMG >/dev/null
wait_fb() { for i in $(seq 1 60); do timeout 5 fastboot devices | grep -q . && return 0; sleep 2; done; return 1; }
timeout 5 fastboot devices | grep -q . || timeout 20 adb reboot bootloader >/dev/null 2>&1
wait_fb || { echo NO_FASTBOOT; exit 3; }
timeout 20 fastboot reboot bootloader >/dev/null 2>&1; sleep 5; wait_fb || { echo NO_FASTBOOT; exit 3; }
timeout 10 fastboot getvar product >/dev/null 2>&1 || { echo FASTBOOT_WEDGED; exit 4; }
timeout 60 fastboot boot $IMG >/dev/null 2>&1; T0=$(date +%s); sleep 8
timeout 5 fastboot devices | grep -q . && { echo REJECT; exit 0; }
for i in $(seq 1 100); do adb devices | tail -n +2 | grep -q device && break; sleep 3; done
T=$(( $(date +%s) - T0 ))
if ! adb devices | tail -n +2 | grep -q device; then echo "STUCK (no adb after ${T}s)"; exit 5; fi
if [ $T -le 55 ]; then echo "REACHED (adb after ${T}s)"; else echo "NOT_REACHED (adb after ${T}s)"; fi
