#!/usr/bin/env bash
# Camera bring-up check, run ON the tablet after RAM-booting a camera dev image (issue #4, NOTES 2026-11-01).
# Loads the camera modules, powers both sensor slots, scans both CCI buses, and shows how the mclk/reset/standby pins are muxed.
# Own-built modules expected in /root/cammods (camcc-sm8650.ko, gc05a2.ko); i2c-qcom-cci comes from the installed module tree.
set -uo pipefail
CAM=/root/cammods
CCI=/soc/qcom,cci0@ac15000

[ -e $CAM/camcc-sm8650.ko ] && insmod $CAM/camcc-sm8650.ko
modprobe i2c-qcom-cci || insmod $CAM/i2c-qcom-cci.ko

# the CCI child devices appear only after the deferred probes finish (camcc -> cci -> sensor)
for i in $(seq 30); do ls -d /sys/bus/i2c/devices/i2c-* >/dev/null 2>&1 && break; sleep 1; done

echo "--- loaded modules"; lsmod | grep -E "camcc|cci|gc05a2"
echo "--- dmesg"; dmesg | grep -iE "cci|cam_cc|gc05a2|titan" | tail -30

for a in /sys/bus/i2c/devices/i2c-*; do
  case "$(cat $a/of_node/full_name 2>/dev/null)" in
    */$CCI/i2c-bus@0) b=0 ;;
    */$CCI/i2c-bus@1) b=1 ;;
    *) continue ;;
  esac
  echo "--- CCI port $b: $(cat $a/name)"
  for c in $a/*/; do [ -e $c/power/control ] && { echo on > $c/power/control; } && echo "powered $(cat $c/of_node/name 2>/dev/null)"; done
  sleep 1
  i2cdetect -y -r ${a##*/i2c-}
  [ -e $a/*/power/control ] && echo off > $a/*/power/control
done

echo "--- camera pins (needs a DEV=1 image)"
grep -hE "pin (2|3|6|15|64|68) " /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null || echo "no pinctrl debugfs"
grep -hE "gpio-(2|3|6|15|64|68)\b" /sys/kernel/debug/gpio 2>/dev/null || true
