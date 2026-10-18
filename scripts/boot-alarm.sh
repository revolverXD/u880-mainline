#!/usr/bin/env bash
# Boot Arch Linux ARM (microSD p1) on the U880 via `fastboot boot` (RAM only, flash untouched).
# Tablet must be in LineageOS (adb) or fastboot. Afterwards: ssh alarm@172.16.42.2 (PC: nmcli profile u880-usb).
# Env MORE: extra kernel cmdline. Rescue system instead (busybox shell on /dev/ttyACM0): run without u880root=sd, i.e. scripts/run-live.sh with the same EXTRA.
M=/home/USER/External/work/src/mainline
KIMG=$M/linux-7.2.9/arch/arm64/boot/Image EXTRA="regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=sd msm.separate_gpu_kms=1 cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 ${MORE:-}" \
  exec $M/scripts/run-live.sh "$@"
