#!/usr/bin/env bash
# Camera bring-up DTB (NOTES 2026-11-01): turn the vendor CCI0 node of a built DTB into a mainline qcom,sm8650-cci node WITHOUT renaming it
# or touching its labels. A DTB with the node renamed to cci@ac15000 never booted: the bootloader dropped back to fastboot with no kernel log.
# usage: nix-shell -p dtc --run "bash scripts/camera-cci-dtb.sh <in.dtb> <out.dtb>"
set -euo pipefail
I=${1:?in.dtb}; O=${2:?out.dtb}; cp "$I" "$O"
N=/soc/qcom,cci0@ac15000
p() { fdtput "$O" "$@"; }
p -t s $N status okay
p -t s $N compatible qcom,sm8650-cci qcom,msm8996-cci
p -t x $N power-domains 0x154 0x0
p -t x $N clocks 0x154 0x5 0x154 0x11 0x154 0xa
p -t s $N clock-names camnoc_axi cpas_ahb cci
p -t x $N assigned-clocks 0x154 0xa
p -t x $N assigned-clock-rates 0x23c3460
p -t x $N pinctrl-0 0x460 0x461 0x464 0x465
p -t x $N pinctrl-1 0x462 0x463 0x466 0x467
p -t s $N pinctrl-names default sleep
p -t x $N '#address-cells' 1
p -t x $N '#size-cells' 0
for c in qcom,i2c_standard_mode qcom,i2c_fast_mode qcom,i2c_custom_mode qcom,i2c_fast_plus_mode; do p -t s $N/$c status disabled; done
for b in 0 1; do
  # clock-frequency is the only knob mainline uses (the vendor qcom,i2c_*_mode children are disabled above); a sensor that
  # only answers at 100 kHz is a real possibility, so it is selectable per port: CLKFREQ0/CLKFREQ1.
  cf=CLKFREQ$b; p -c $N/i2c-bus@$b; p -t x $N/i2c-bus@$b reg $b; p -t x $N/i2c-bus@$b clock-frequency ${!cf:-400000}
  p -t x $N/i2c-bus@$b '#address-cells' 1; p -t x $N/i2c-bus@$b '#size-cells' 0
done

# sensor identities, read out of the stock module config (vendor.img:/lib64/camera/com.qti.sensormodule.c2_ov13b10.bin and .c2_gc05a2.bin: the
# sensorDriverData "Default" block carries an 8-bit I2C SID and the chip-ID register/value): rear OV13B10-family SID 0x20 -> 7-bit 0x10, chip id
# 0x300a/0x300b = 0d 42; front GC05A2 SID 0x6e -> 7-bit 0x37, chip id 0x03f0 = 05 a2. Stock slot map: cam-sensor1 = cci-master 0 = rear, cam-sensor4 = 1 = front. phandles: 0x16c tlmm, 0x154 camcc,
# 0x361/0x363/0x365 = L1M/L3M/L5M (rear dvdd/avdd/dovdd), L2M/L4M/L5M for the front are looked up by label below.
# COMPAT0/COMPAT1 override the driver matched by the slot. "u880,cam-probe" binds nothing at boot (the client still exists with all its DT supplies,
# pinctrl and reset gpio; bind it later with camera-test.sh's `bind`), which is how to tell a bad boot apart from a bad driver probe: a client at 0x10
# with gc05a2 bound stopped the boot at ~11 s with no panic and no DWC3 (pstore console-ramoops, 2026-11-01), the same node at 0x36 booted.
sensor() { # node reg compat mclk-idx rate reset-gpio mclk-pin rst-pin pwd-pin dovdd avdd dvdd lanes linkfreq
  local n=$1; local b=${n##*i2c-bus@}; b=${b%%/*}   # which CCI port this slot is on (selects the env knobs)
  local rf=RESET_FLAG$b
  p -c $n; p -t x $n reg $2; p -t s $n compatible "$3"
  p -t x $n clocks 0x154 $4; p -t x $n assigned-clocks 0x154 $4; p -t x $n assigned-clock-rates $5
  # pinctrl-0 must contain all three stock states (mclk, reset, standby) like the vendor node does: without cam_sensor_active_rst0/rst4 the reset pin
  # is never muxed to "gpio", so driving it changes nothing on the pad and the sensor stays unreachable (NOTES 2026-11-01 "gpio reads out low func1").
  p -t x $n reset-gpios 0x16c $6 ${!rf:-1}; p -t s $n pinctrl-names default; p -t x $n pinctrl-0 $7 $8 $9
  p -t x $n dovdd-supply ${10}; p -t x $n avdd-supply ${11}; p -t x $n dvdd-supply ${12}
  p -t x $n power-domains 0x154 0x0   # stock: cam_clk-supply = cam_cc_titan_top_gdsc; MCLK stays "stuck at off" without it
  p -c $n/port; p -c $n/port/endpoint; p -t x $n/port/endpoint data-lanes ${13}; p -t x $n/port/endpoint link-frequencies 0 ${14}
}
# ov13b10 in 7.3.1 is ACPI-only (no OF match), so the rear slot borrows the gc05a2 driver: it powers the module and reads 0x03f0, an ACK (not -ENXIO)
# and a "unexpected sensor id" line prove the address and the rails. Ports need a remote endpoint in an *available* node or the drivers refuse to probe.
# phandles in our own base DTB: 0x482/0x48e/0x490 = cam_sensor_mclk0_active/active_rst0/active_pwd0 (gpio64 cam_mclk, gpio15, gpio6),
# 0x48a/0x498/0x49a = the same for sensor4 (gpio68, gpio3, gpio2). Rails: L1M/L3M/L5M rear, L2M/L4M/L5M front (the stock o25 overlay's cam_vdig/vana/vio).
# ADDR0/ADDR1: the I2C client address per port. The *true* rear address is 0x10 (see the identity comment above), but an OF I2C client at 0x10 on this CCI
# adapter hangs our boot - the kernel stops producing output at ~11 s (fw_devlink sync_state timeout), no panic, no USB gadget, and the tablet has to be
# power-cycled; tested with the node renamed, and with a compatible that binds no driver, while the identical DTB with reg=<0x36> boots fine (2026-11-01).
# So the default is the address that boots, and 0x10 stays behind the knob until that hang is understood. The raw probe at 0x10 was already done and NACKed
# (camera-test.sh scans it), which is why the wrong default does not hide the sensor.
A0=${ADDR0:-36}; A1=${ADDR1:-37}
N0=$N/i2c-bus@0/camera@$A0; N1=$N/i2c-bus@1/camera@$A1
sensor $N0 0x$A0 ${COMPAT0:-galaxycore,gc05a2} 0x60 0x16e3600 0xf 0x482 0x48e 0x490 0x365 0x363 0x361 "1 2" 0x1ab3f000
sensor $N1 0x$A1 ${COMPAT1:-galaxycore,gc05a2} 0x68 0x16e3600 0x3 0x48a 0x498 0x49a 0x365 0x364 0x362 "1 2" 0x1ab3f000
p -t x $N0/port/endpoint phandle 0x7001; p -t x $N1/port/endpoint phandle 0x7003
p -t x $N0/port/endpoint remote-endpoint 0x7002; p -t x $N1/port/endpoint remote-endpoint 0x7004
p -c /soc/cam-dummy-csiphy; p -t s /soc/cam-dummy-csiphy status okay
for k in 0 1; do
  P=/soc/cam-dummy-csiphy/port@$k; p -c $P; p -t x $P reg $k; p -c $P/endpoint
  p -t x $P/endpoint phandle $(printf 0x%x $((0x7002 + 2*k))); p -t x $P/endpoint remote-endpoint $(printf 0x%x $((0x7001 + 2*k)))
done

# The stock "standby" pins (rear gpio6, front gpio2) are only muxed as GPIO in the active state, never driven: the vendor driver set them low
# (gpio-req-tbl-flags 0 = OUT_INIT_LOW). Without a level the sensors NACK every address (bus 7/8 scans, NOTES 2026-11-01).
for s in cam_sensor_active_pwd0 cam_sensor_active_pwd4; do p /soc/pinctrl@f000000/$s/config output-low ""; done

# VAF_RAILS=1: switch on the two module rails no mainline node ever requests. The stock config uses
# cam_vaf = L7M (rear) / L6M (front), 2.8 V; they are registered but off, so a module that needs them is
# missing a supply. Always-on is enough for a bring-up test.
if [ "${VAF_RAILS:-0}" = 1 ]; then
  for r in 6 7; do p /soc/rsc@17a00000/drv@2/rpmh-regulator-ldom$r/regulator-pm8010m-l$r regulator-always-on ""; done
fi

# NOTE: the stock vendor sensor/actuator nodes under the CCI are NOT in this DTB: the bootloader applies the stock dtbo overlay (labels/paths of cam_cci0
# are its targets, which is why renaming the node made the bootloader refuse to boot).
