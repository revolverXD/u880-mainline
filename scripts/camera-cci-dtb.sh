#!/usr/bin/env bash
# Camera bring-up DTB (NOTES 2026-11-01): turn the vendor CCI0 node of a built DTB into a mainline qcom,sm8650-cci node WITHOUT renaming it
# or touching its labels. A DTB with the node renamed to cci@ac15000 never booted: the bootloader dropped back to fastboot with no kernel log.
# usage: nix-shell -p dtc --run "bash scripts/camera-cci-dtb.sh <in.dtb> <out.dtb>"
set -euo pipefail
I=${1:?in.dtb}; O=${2:?out.dtb}; cp "$I" "$O"
N=/soc/qcom,cci0@ac15000
p() { fdtput "$O" "$@"; }
# CCI1CLK=1: i2c-qcom-cci.c enables exactly the clocks the DT lists (devm_clk_bulk_get_all), and this node has only ever
# listed master 0's. The controller's second master (i2c-bus@1, GPIO_72/73 - its pinctrl states 0x464/0x465 are already in
# pinctrl-0) has never had a clock here, which is the leading suspect for its "master 1 queue 0 timeout". Stock runs that
# RCG at 37.5 MHz like master 0's.
c1=""; c1n=""; a1=""
if [ "${CCI1CLK:-0}" = 1 ]; then c1="0x154 0xd 0x154 0xc"; c1n="cci_1_clk_src cci_1_clk"; a1="0x154 0xd"; fi
p -t s $N status okay
p -t s $N compatible qcom,sm8650-cci qcom,msm8996-cci
p -t x $N power-domains 0x154 0x0
p -t x $N clocks 0x154 0x5 0x154 0x11 0x154 0xa $c1
p -t s $N clock-names camnoc_axi cpas_ahb cci $c1n
p -t x $N assigned-clocks 0x154 0xa $a1
p -t x $N assigned-clock-rates 0x23c3460 ${a1:+0x23c3460}
p -t x $N pinctrl-0 0x460 0x461 0x464 0x465
p -t x $N pinctrl-1 0x462 0x463 0x466 0x467
p -t s $N pinctrl-names default sleep
p -t x $N '#address-cells' 1
p -t x $N '#size-cells' 0
for c in qcom,i2c_standard_mode qcom,i2c_fast_mode qcom,i2c_custom_mode qcom,i2c_fast_plus_mode; do p -t s $N/$c status disabled; done
for b in 0 1; do
  # clock-frequency is the only knob mainline uses (the vendor qcom,i2c_*_mode children are disabled above). fdtput -t x reads its argument as HEX, so a
  # decimal knob has to be converted: before that, "400000" written 0x400000 = 4194304 matched none of the driver's exact compares (i2c-qcom-cci.c:554
  # accepts only 100000/400000/1000000) and the bus silently stayed I2C_MODE_STANDARD - every CCI test here ran at 100 kHz (NOTES 2026-11-02).
  cf=CLKFREQ$b; p -c $N/i2c-bus@$b; p -t x $N/i2c-bus@$b reg $b; p -t x $N/i2c-bus@$b clock-frequency $(printf 0x%x ${!cf:-400000})
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
# missing a supply. Always-on is enough for a bring-up test. VAF_REAR=1 does only L7M, VAF_FRONT=1 only L6M: the boot with both of them always-on never
# reported back (F28), so they have to be tried one at a time.
if [ "${VAF_RAILS:-0}" = 1 ] || [ "${VAF_REAR:-0}" = 1 ] || [ "${VAF_FRONT:-0}" = 1 ]; then
  rails=""; [ "${VAF_RAILS:-0}" = 1 ] && rails="6 7"; [ "${VAF_REAR:-0}" = 1 ] && rails="$rails 7"; [ "${VAF_FRONT:-0}" = 1 ] && rails="$rails 6"
  for r in $rails; do p /soc/rsc@17a00000/drv@2/rpmh-regulator-ldom$r/regulator-pm8010m-l$r regulator-always-on ""; done
fi

# DW9714=1: the rear module's voice-coil AF as a real driver instead of only the always-on L7M hack. F33: it
# answers at 7-bit 0x0c (not the 0x06 in stock's actuator config) and only while L7M = cam_vaf is on, so keep
# VAF_REAR=1: dw9714_runtime_suspend() disables vcc, so the driver alone would drop the rail again. A sibling of
# the sensor slot needs no port/graph; drivers/media/i2c/dw9714.c is a plain i2c driver (vcc + optional
# powerdown gpio, no chip-id check at probe), and its register model (16-bit writes) is what tells a real VCM
# apart from an address that only ACKs.
if [ "${DW9714:-0}" = 1 ]; then
  AF=${AFADDR:-c}; V=$N/i2c-bus@0/dw9714@$AF
  p -c $V; p -t x $V reg 0x$AF; p -t s $V compatible dongwoon,dw9714
  p -t x $V vcc-supply 0x367   # phandle of /soc/rsc@17a00000/drv@2/rpmh-regulator-ldom7/regulator-pm8010m-l7
fi

# NOTE: the stock vendor sensor/actuator nodes under the CCI are NOT in this DTB: the bootloader applies the stock dtbo overlay (labels/paths of cam_cci0
# are its targets, which is why renaming the node made the bootloader refuse to boot).

# CCI1=1: bring up the SECOND CCI controller of this SoC. It is in the stock DT (`cam_cci1: qcom,cci1@ac16000`, status disabled, own IRQ CCI1), and
# the vendor pin naming numbers the lines across controllers: cci_i2c_sda0/scl0 = GPIO_70/71 and sda1/scl1 = GPIO_72/73 are cci0's two masters,
# **sda2/scl2 = GPIO_74/75 are cci1's master 0** (sda3/scl3 = GPIO_21 is its master 1, unused here). The vendor sensor nodes say only
# `cci-master = <0/1>` and never name a controller, so "front = cci-master 1" does not prove it is cci0's master 1: the front module may sit on a
# controller we never enabled, and driving an unused master port is what "master 1 queue 0 timeout" (F31) looks like. The stock node's clock cells are
# in the *vendor* index space (cci_0 = 0x1f/0x20), not mainline's - use mainline's: CCI_1_CLK 0xc, CCI_1_CLK_SRC 0xd
# (include/dt-bindings/clock/qcom,sm8650-camcc.h), at the same 37.5 MHz as cci0. Pinctrl phandles of this base DTB: 0x468/0x469 =
# cci_i2c_scl2/sda2 active (gpio75/74), 0x46a/0x46b = suspend. Nothing is known about which module is wired to this controller, so the slot reuses the
# front module's power recipe (mclk4, gpio3 reset, L2M/L4M/L5M): if a sensor answers there, that is the front one.
A2=${ADDR2:-37}
if [ "${CCI1:-0}" = 1 ]; then
  C=/soc/qcom,cci1@ac16000; N2=$C/i2c-bus@0/camera@$A2
  p -t s $C status okay
  p -t s $C compatible qcom,sm8650-cci qcom,msm8996-cci
  p -t x $C power-domains 0x154 0x0
  p -t x $C clocks 0x154 0x5 0x154 0x11 0x154 0xc
  p -t s $C clock-names camnoc_axi cpas_ahb cci
  p -t x $C assigned-clocks 0x154 0xd
  p -t x $C assigned-clock-rates 0x23c3460
  p -t x $C pinctrl-0 0x468 0x469; p -t x $C pinctrl-1 0x46a 0x46b; p -t s $C pinctrl-names default sleep
  p -t x $C '#address-cells' 1; p -t x $C '#size-cells' 0
  for c in qcom,i2c_standard_mode qcom,i2c_fast_mode qcom,i2c_custom_mode qcom,i2c_fast_plus_mode; do p -t s $C/$c status disabled; done
  p -c $C/i2c-bus@0; p -t x $C/i2c-bus@0 reg 0; p -t x $C/i2c-bus@0 clock-frequency $(printf 0x%x ${CLKFREQ2:-400000})
  p -t x $C/i2c-bus@0 '#address-cells' 1; p -t x $C/i2c-bus@0 '#size-cells' 0
  sensor $N2 0x$A2 ${COMPAT2:-galaxycore,gc05a2} 0x68 0x16e3600 0x3 0x48a 0x498 0x49a 0x365 0x364 0x362 "1 2" 0x1ab3f000
  # a sensor port needs a remote endpoint in an available node or its driver refuses to probe, so the dummy csiphy gets a third port.
  p -t x $N2/port/endpoint phandle 0x7005; p -t x $N2/port/endpoint remote-endpoint 0x7006
  P2=/soc/cam-dummy-csiphy/port@2; p -c $P2; p -t x $P2 reg 2; p -c $P2/endpoint
  p -t x $P2/endpoint phandle 0x7006; p -t x $P2/endpoint remote-endpoint 0x7005
fi
