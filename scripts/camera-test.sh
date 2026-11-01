#!/usr/bin/env bash
# Camera bring-up check, run ON the tablet after RAM-booting a camera dev image (issue #4, NOTES 2026-11-01).
# Loads the camera modules, powers both sensor slots, scans both CCI buses, reads the chip IDs, shows rails/clocks/pin mux.
# The standby/power-down lines are driven low by the DTB itself (scripts/camera-cci-dtb.sh), not from here.
# Own-built modules expected in /root/cammods (camcc-sm8650.ko, gc05a2.ko); the rest comes from the installed module tree.
set -uo pipefail
CAM=/root/cammods
TLMM=$(gpioinfo | awk '/gpioinfo|gpiochip[0-9]+ - 1[0-9][0-9] lines:/{print $1}' | head -1)
# candidate sensor addresses, not a full 1..127 scan (that is what wedges the CCI queue)
ADDR="0x10 0x18 0x1a 0x20 0x29 0x34 0x36 0x37 0x3c 0x50 0x58 0x6c"

load() { # our own build in /root/cammods wins over the installed module tree (that is what the dev image is for)
  [ -e $CAM/camcc-sm8650.ko ] && insmod $CAM/camcc-sm8650.ko 2>/dev/null
  insmod $CAM/i2c-qcom-cci.ko 2>/dev/null || modprobe i2c-qcom-cci
  insmod $CAM/gc05a2.ko 2>/dev/null || modprobe gc05a2
  for i in $(seq 30); do detect && [ -n "$devs" ] && return; sleep 1; done
}
unload() { rmmod gc05a2 i2c_qcom_cci camcc_sm8650 2>/dev/null; devs=""; }
# the sensor clients are found by their DT path (of_node has no full_name attribute here: read the symlink).
# The adapter itself appears as i2c-N with the same of_node path, so match the sensor node, not just the bus.
detect() {
  devs=""; rear=""; front=""
  for d in /sys/bus/i2c/devices/*-*; do
    case "$(readlink $d/of_node 2>/dev/null)" in *cci0*/i2c-bus@0/camera@*) rear=$d; devs="$devs $d";;
                                    *cci0*/i2c-bus@1/camera@*) front=$d; devs="$devs $d";; esac
  done
  buses=$(for d in $devs; do basename $d | cut -d- -f1; done | sort -u | tr '\n' ' ')
  REAR=$(basename "$rear" | cut -d- -f1); FRONT=$(basename "$front" | cut -d- -f1)
  [ -n "$rear" ] && [ -n "$front" ]
}
power() { for d in $devs; do echo on > $d/power/control; done; sleep 1; }
# The DTB may describe the slots with a compatible that binds no driver (COMPAT0/1 in scripts/camera-cci-dtb.sh). Then the client exists with all its
# supplies, pinctrl and reset gpio but nothing is claimed; bind the driver here, after the modules are up. EBUSY (already bound) is fine.
bind() { for d in $devs; do echo gc05a2 > $d/driver_bind 2>/dev/null; done; sleep 2; }
unbind() { for d in $devs; do echo gc05a2 > $d/driver_unbind 2>/dev/null; done; }
scan() { for b in $buses; do printf "  bus %s:" $b
  for a in $ADDR; do i2ctransfer -f -y $b w0@$a 2>/dev/null && printf " ACK@%s" $a; done; echo; done; }
rails() { grep "pm8010m_l[1-7] " /sys/kernel/debug/regulator/regulator_summary | awk '{print $1" use="$2" "$5}'; }
mclk() { grep -E "cam_cc_mclk[04]_clk " /sys/kernel/debug/clk/clk_summary | awk '{print $1" en="$3" "$5}'; }

# Chip IDs where the stock module config says they are (2026-11-01, read out of vendor.img:/lib64/camera/com.qti.sensormodule.c2_ov13b10.bin
# and .c2_gc05a2.bin, sensorDriverData "Default" block: an 8-bit I2C SID plus the chip-ID register and value).
# rear OV13B10-family SID 0x20 -> 7-bit 0x10, regs 0x300a/0x300b must read 0d 42; front GC05A2 SID 0x6e -> 7-bit 0x37, reg 0x03f0 = 05 a2.
# The vendor config declares no EEPROM driver (only actuator dw9714v on the rear), so the 0x50/0x58 devices are unidentified hardware.
ids() {
  on
  echo "--- rear 0x10: OV13B10 chip id (expect 0d 42)"; timeout 10 i2ctransfer -f -y "$REAR" w2@0x10 0x30 0x0a r2
  echo "--- front 0x37: GC05A2 chip id (expect 05 a2)"; timeout 10 i2ctransfer -f -y "$FRONT" w2@0x37 0x03 0xf0 r2
  echo "--- the devices that answer on the rear bus, 16-bit addressed read of 8 bytes"
  timeout 10 i2ctransfer -f -y "$REAR" w2@0x50 0x00 0x00 r8; timeout 10 i2ctransfer -f -y "$REAR" w2@0x58 0x00 0x00 r8
}

echo "tlmm=$TLMM"
load; detect; bind
echo "sensors:${devs:- NONE}  buses=$buses"
[ -n "$devs" ] || { echo "no sensor devices: CCI or DT problem, see the dmesg tail"; }
power; echo "== rails/clocks after power-up"; rails; mclk
echo "== scan, powered"; scan
# Does an ACK belong to the camera module? With power/control=auto the client runtime-suspends, the rails drop to
# use=0, and anything on the module goes silent. (2026-11-01: 0x50/0x58 do, so the module is powered and on the bus.)
for d in $devs; do echo auto > $d/power/control; done; sleep 4
echo "== rails and scan, module power off"; rails; scan
power; echo "== scan, powered again"; scan
ids
echo "== lines (2,6 = standby, 3,15 = reset)"; gpioinfo -c ${TLMM:-gpiochip6} 2>/dev/null | grep -E "line +(2|3|6|15):"
echo "== pins"; grep -hE "pin (2|3|6|15|64|68) " /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null | tail -6
echo "== cci/sensor messages"; dmesg | grep -iE "cci|gc05a2|cam_cc" | tail -12

case "${1:-}" in
  load) load; echo "loaded";;
  unload) unload; echo "unloaded";;
  detect) detect; echo "buses=$buses";;
  on) power; rails; mclk;;
  off) for d in $devs; do echo auto > $d/power/control; done; sleep 2; rails;;
  scan) power; scan;;
  rails) rails;;
  mclk) mclk;;
  ids) ids;;
  bind) bind; echo bound;;
  unbind) unbind; echo unbound;;
  *) echo "===== $0 rails mclk detect load unload scan ids bind unbind on off";;
esac
