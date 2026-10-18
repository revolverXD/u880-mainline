#!/usr/bin/env bash
# Flash stage1/u880-boot.img into boot_b and boot it, from a running Linux (Wi-Fi ip in U880_HOST) or from Android (adb).
# The ABL refuses `fastboot flash` when the bootloader was entered from Linux (PMIC reason), so the flash happens after a detour via Android:
# Linux -> `reboot bootloader` -> set_active a, reboot (Android) -> `adb reboot bootloader` -> flash boot_b, set_active b, reboot.
# After the new image is verified, run scripts/gpt-mark-successful.py on the tablet (set_active clears the successful bit; until then the ABL
# keeps its 7-try fallback to Android). usage: U880_HOST=<ip> scripts/flash-boot-b.sh
set -u
M=/home/USER/External/work/src/mainline; IMG=$M/stage1/u880-boot.img
fb() { timeout 5 fastboot devices 2>/dev/null | grep -q .; }
wait_fb() { for i in $(seq 1 40); do fb && return 0; sleep 3; done; return 1; }
wait_adb() { for i in $(seq 1 60); do adb devices | grep -q 'device$' && break; sleep 5; done
             for i in $(seq 1 40); do adb shell getprop sys.boot_completed 2>/dev/null | grep -q 1 && return 0; sleep 5; done; return 1; }
if adb devices | grep -q 'device$'; then :
elif fb; then :
else
  [ -n "${U880_HOST:-}" ] || { echo "need U880_HOST or adb/fastboot"; exit 2; }
  $M/scripts/rssh.sh 'sync; reboot bootloader' >/dev/null 2>&1; wait_fb || { echo "no fastboot"; exit 3; }
fi
if fb; then timeout 20 fastboot set_active a >/dev/null 2>&1; timeout 20 fastboot reboot >/dev/null 2>&1; fi
wait_adb || { echo "Android did not come up"; exit 4; }
adb reboot bootloader; wait_fb || { echo "no fastboot after adb"; exit 5; }
timeout 120 fastboot flash boot_b $IMG 2>&1 | tail -2 || exit 6
timeout 20 fastboot set_active b 2>&1 | tail -1
timeout 20 fastboot reboot 2>&1 | tail -1
echo "flashed; Linux should boot from slot B (try 1 of 7 used; mark successful after verifying)"
