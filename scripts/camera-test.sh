#!/usr/bin/env bash
# Camera bring-up check, run ON the tablet after RAM-booting a camera dev image (issue #4, NOTES 2026-11-01).
# Loads the camera modules, powers both sensor slots, scans both CCI buses, and shows rails/clocks/pin mux.
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
  devs=""
  for d in /sys/bus/i2c/devices/*-*; do
    case "$(readlink $d/of_node 2>/dev/null)" in *cci0*/i2c-bus@*/camera@*) devs="$devs $d" ;; esac
  done
  buses=$(for d in $devs; do basename $d | cut -d- -f1; done | sort -u | tr '\n' ' ')
}
power() { for d in $devs; do echo on > $d/power/control; done; sleep 1; }
scan() { for b in $buses; do printf "  bus %s:" $b
  for a in $ADDR; do i2ctransfer -f -y $b w0@$a 2>/dev/null && printf " ACK@%s" $a; done; echo; done; }
rails() { grep "pm8010m_l[1-5] " /sys/kernel/debug/regulator/regulator_summary | awk '{print $1" use="$2" "$5}'; }
mclk() { grep -E "cam_cc_mclk[04]_clk " /sys/kernel/debug/clk/clk_summary | awk '{print $1" en="$3" "$5}'; }

echo "tlmm=$TLMM"
load; detect
echo "sensors:${devs:- NONE}  buses=$buses"
[ -n "$devs" ] || { echo "no sensor devices: CCI or DT problem, see the dmesg tail"; }
power; echo "== rails/clocks after power-up"; rails; mclk
echo "== scan, powered"; scan
# Does an ACK belong to the camera module? With power/control=auto the client runtime-suspends, the rails drop to
# use=0, and anything on the module goes silent. (2026-11-01: 0x50/0x58 do, so the module is powered and on the bus.)
for d in $devs; do echo auto > $d/power/control; done; sleep 4
echo "== rails and scan, module power off"; rails; scan
power; echo "== scan, powered again"; scan
echo "== lines (2,6 = standby, 3,15 = reset)"; gpioinfo -c ${TLMM:-gpiochip6} 2>/dev/null | grep -E "line +(2|3|6|15):"
echo "== pins"; grep -hE "pin (2|3|6|15|64|68) " /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null | tail -6
echo "== cci/sensor messages"; dmesg | grep -iE "cci|gc05a2|cam_cc" | tail -12
