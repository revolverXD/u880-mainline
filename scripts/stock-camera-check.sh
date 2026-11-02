#!/usr/bin/env bash
# Ask the *stock* Android stack whether its own camera driver finds the modules. Run on the host after
# `fastboot boot ../recovery/stock/U880_B14_V3.0L.1_0311/images/boot.img` (FINDINGS F39: that boot does NOT format our rootfs, but it gets no further
# than adbd while `userdata` is our ext4 - so this script needs Android to have its own /data, and a screen to tap "Allow USB debugging" on).
# Stock is a user build, so there is no `adb root`: everything here works as the shell user.
# usage: scripts/stock-camera-check.sh > logs/stock-camera-$(date +%Y%m%d).log 2>&1
set -u
say() { echo; echo "=== $*"; }
# `adb get-state` only says "device" for an AUTHORIZED device. A stock Android with no working /data has no adb_keys store, so it answers
# "unauthorized" and shows the RSA prompt on its screen - if that screen is black nobody can tap Allow. 2026-11-02: this loop waited through
# a whole stock boot and logged nothing, so print what the state actually is.
for i in $(seq 1 60); do st=$(adb get-state 2>&1); echo "$(date +%T) adb state: $st"; [ "$st" = device ] && break; sleep 5; done
adb wait-for-device
say "build and slot"
adb shell getprop ro.build.display.id ro.build.version.release ro.boot.slot_suffix ro.bootmode
say "root? (stock is usually a user build, then this fails and the extras below are skipped)"
adb root >/dev/null 2>&1; sleep 3; adb wait-for-device
ROOT="$(adb shell id -u 2>/dev/null | tr -d '\r')"; echo "uid=$ROOT"
if [ "$ROOT" = "0" ]; then
  say "the DT the stock kernel actually runs: which sensor nodes, which GPIOs, which rails"
  adb shell 'for n in $(find /proc/device-tree -name "*cam-sensor*" -o -name "*cam-actuator*" 2>/dev/null); do echo "## $n"; for f in $n/*; do printf "%s=" "$(basename $f)"; od -An -tx1 "$f" 2>/dev/null | tr -d " \n"; echo; done; done' 2>/dev/null | head -120
  say "stock kernel camera/CCI log"
  adb shell 'dmesg' 2>/dev/null | grep -iE "cci|camcc|cam_|sensor|probe.*fail" | head -60
  say "stock i2c adapters and clients, gpio state, and the camera clock tree"
  adb shell 'ls /sys/bus/i2c/devices/ 2>/dev/null; cat /sys/kernel/debug/gpio 2>/dev/null | head -60' 2>/dev/null
  adb shell 'cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | grep -iE "cam_cc_(mclk|cci)" ' 2>/dev/null | head -40
fi
say "how many cameras does the framework see"
adb shell dumpsys media.camera 2>/dev/null | grep -iE "Number of cameras|Camera [0-9]+ .*info|device.*back|facing" | head -40
say "sensor probe result in the vendor logs"
adb logcat -d 2>/dev/null | grep -iE "probe.*sensor|sensor.*probe|not detect|no matching|Ci2c|CCI|camx.*error|CSL.*open|acquire.*sensor" | head -60
say "start the camera app and screenshot the preview (a real image = the sensor streams)"
adb shell am start -a android.media.action.STILL_IMAGE_CAMERA >/dev/null
sleep 12
adb exec-out screencap -p > /tmp/u880-stock-camera.png 2>/dev/null
ls -l /tmp/u880-stock-camera.png
adb shell dumpsys media.camera 2>/dev/null | grep -iE "Number of cameras|open|client pkg|hal device" | head -30
say "done - now go back to Arch: set_active b + reboot, then re-mark boot_b (FINDINGS F9 / README)"
