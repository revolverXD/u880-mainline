#!/usr/bin/env bash
# Stage 1c DTB: stock dtb2, all devices disabled except GIC/timer/PSCI, + fixed console ramoops + splash simplefb.
# Run on host: nix-shell -p dtc --run "bash scripts/build-stock-disabled.sh"
set -e
M=/home/USER/External/work/src/mainline; S=$M/stage1
python3 -I $M/scripts/disable-stock-dts.py $M/stock-dt/dtb2.dts $S/dtb2-disabled.dts ${ALLOW:-}
dtc -q -I dts -O dtb $S/dtb2-disabled.dts -o $S/dtb2-disabled.dtb
# Optional GPU overlay (GPU=1): uke Adreno 732 nodes on top of the stock GPU/GMU/SMMU nodes (sets them okay)
if [ "${GPU:-0}" = 1 ]; then
  K=$M/linux-7.2.9; U=$M/ref/senemos-uke-kernel-mainline/src/boot
  cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $K/include -I $U $S/gpu-overlay.dtso > $S/gpu-overlay.pp.dts
  dtc -q -@ -I dts -O dtb -o $S/gpu-overlay.dtbo $S/gpu-overlay.pp.dts
  fdtoverlay -i $S/dtb2-disabled.dtb -o $S/dtb2-disabled.gpu.dtb $S/gpu-overlay.dtbo && mv $S/dtb2-disabled.gpu.dtb $S/dtb2-disabled.dtb
  echo "GPU overlay applied"
fi
O=$S/dtb2-disabled.dtb; R=/reserved-memory/ramoops_region
fdtput -d $O $R alloc-ranges; fdtput -d $O $R size
fdtput -t x $O $R reg 0xa 0xfe600000 0x0 0x200000
fdtput -t x $O $R pmsg-size 0; fdtput -t x $O $R record-size 0; fdtput -t x $O $R console-size 0x200000
fdtput -t x $O $R ecc-size 0; fdtput -t x $O $R mem-type 0
# splash buffer must be no-map, otherwise simplefb can't ioremap it (overlay adds splash_region without no-map)
fdtput -c $O /reserved-memory/splash_region; fdtput -t x $O /reserved-memory/splash_region reg 0x0 0xe3940000 0x0 0x2b00000
fdtput -t s $O /reserved-memory/splash_region label cont_splash_region; fdtput $O /reserved-memory/splash_region no-map ""
# framebuffer lives at the root: under /chosen ABL-rewritten cells/ranges left simplefb with "No memory resource"
F=/framebuffer@e3940000; fdtput -c $O $F
fdtput -t s $O $F compatible simple-framebuffer; fdtput -t x $O $F reg 0x0 0xe3940000 0x0 0xfa0000
fdtput -t u $O $F width 1600; fdtput -t u $O $F height 2560; fdtput -t u $O $F stride 6400; fdtput -t s $O $F format a8r8g8b8
fdtoverlay -i $O -o $S/dtb2-disabled.merged.dtb $M/stock-dt/o25.dtb && echo "overlay applies"
ls -la $O
# USB: flattened dwc3-qcom ("qcom,snps-dwc3") in peripheral mode, no clocks/resets/PHY drivers (relies on ABL leaving
# USB powered). The qcom glue sets the QSCRATCH VBUS/session override; bare snps,dwc3 bound but never connected.
# No dma-coherent: with it, events read back as zeros ("unknown endpoint event 0") - CPU saw stale cache.
# Stock /soc/ssusb stays disabled.
U=/usb@a600000; fdtput -c $O $U
fdtput -t s $O $U compatible qcom,snps-dwc3; fdtput -t x $O $U reg 0x0 0xa600000 0x0 0xfc100
fdtput -t x $O $U interrupts 0x0 0x85 0x4; fdtput -t s $O $U interrupt-names dwc_usb3
fdtput -t s $O $U dr_mode peripheral; fdtput -t s $O $U maximum-speed high-speed
for p in snps,dis_u2_susphy_quirk snps,dis_enblslpm_quirk snps,dis-u1-entry-quirk snps,dis-u2-entry-quirk snps,usb2-gadget-lpm-disable; do fdtput $O $U $p ""; done
# TLMM: secure (TZ-owned) GPIOs must never be touched, or the SoC resets on an access violation (from uke tree)
fdtput -t u $O /soc/pinctrl@f000000 gpio-reserved-ranges 8 4 56 5
# microSD (sdhc_2): mainline mmc core wants vmmc/vqmmc; stock only has vdd/vdd-io (L13B 0x34e, L23B 0x355 in dtb2)
fdtput -t x $O /soc/sdhci@8804000 vmmc-supply 0x34e
fdtput -t x $O /soc/sdhci@8804000 vqmmc-supply 0x355
# uke qnoc driver has no SDCC2 path ("error finding src node") -> no bandwidth votes for SD for now
fdtput -d $O /soc/sdhci@8804000 interconnects
fdtput -d $O /soc/sdhci@8804000 interconnect-names
# stock SD OPP table is bandwidth-only (no opp-hz) -> invalid without icc; dma-coherent breaks DMA like on USB
fdtput -d $O /soc/sdhci@8804000 operating-points-v2
fdtput -d $O /soc/sdhci@8804000 dma-coherent
# microSD rails via MAINLINE qcom-rpmh-regulator (PMXR2230 == pm7550 table): the uke driver has no voltage tables,
# so mmc core can't build an OCR mask ("1.8/3V not supported for vqmmc", "Invalid vdd").
# ldob13/ldob23 stay out of the uke driver's allowlist so the two drivers never vote on the same rail.
R=/soc/rsc@17a00000/drv@2/regulators-u880-sd
fdtput -c $O $R
fdtput -t s $O $R compatible qcom,pm7550-rpmh-regulators; fdtput -t s $O $R qcom,pmic-id b
fdtput -c $O $R/ldo13; fdtput -t s $O $R/ldo13 regulator-name u880_sd_vdd
fdtput -t u $O $R/ldo13 regulator-min-microvolt 2960000; fdtput -t u $O $R/ldo13 regulator-max-microvolt 2960000
fdtput -t u $O $R/ldo13 regulator-initial-mode 3; fdtput -t x $O $R/ldo13 phandle 0x7f000013
fdtput -c $O $R/ldo23; fdtput -t s $O $R/ldo23 regulator-name u880_sd_vddio
fdtput -t u $O $R/ldo23 regulator-min-microvolt 1800000; fdtput -t u $O $R/ldo23 regulator-max-microvolt 2960000
fdtput -t u $O $R/ldo23 regulator-initial-mode 3; fdtput -t x $O $R/ldo23 phandle 0x7f000023
fdtput -t x $O /soc/sdhci@8804000 vmmc-supply 0x7f000013
fdtput -t x $O /soc/sdhci@8804000 vqmmc-supply 0x7f000023
# ABL's o25 overlay re-adds vdd(-io)-supply = <&L13B>/<&L23B> after us, so instead disable those stock regulator
# nodes: fw_devlink ignores disabled suppliers, and mainline sdhci-msm only uses vmmc/vqmmc.
fdtput -t s $O /soc/rsc@17a00000/drv@2/rpmh-regulator-ldob13 status disabled
fdtput -t s $O /soc/rsc@17a00000/drv@2/rpmh-regulator-ldob23 status disabled
# Root compatible: ubwc_config (msm GPU) matches "qcom,sm7675" (uke patch); keep the stock strings after it
fdtput -t s $O / compatible alldocube,u880 qcom,sm7675 qcom,cliffsp qcom,cliffs
# Touch I2C (QUP0 SE4): no GPI DMA (disabled) -> FIFO mode; no QUP interconnect paths in the uke qnoc driver
for p in dmas dma-names interconnects interconnect-names; do
  fdtput -d $O /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a90000 $p
done
# Touch I2C: downstream "qcom,i2c-geni"/"se-clk" -> mainline "qcom,geni-i2c"/"se" (clock IDs stay: uke gcc uses downstream IDs)
fdtput -t s $O /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a90000 compatible qcom,geni-i2c
fdtput -t s $O /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a90000 clock-names se
# Touchscreen: NT36523N on QUP0 SE4 I2C, FW address 0x01, IRQ GPIO129 rising, reset GPIO128 active-low (tlmm phandle 0x16c)
T=/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a90000/touchscreen@1
fdtput -c $O $T
fdtput -t s $O $T compatible novatek,nt36523n-ts
fdtput -t x $O $T reg 0x1
fdtput -t x $O $T interrupts-extended 0x16c 0x81 0x1   # GPIO 129 rising (-t x = hex!)
fdtput -t x $O $T reset-gpios 0x16c 0x80 0x1   # GPIO 128 active-low
# Touch IRQ line needs pull-up (stock ts_active), else it idles pulled-down and never edges. Config-only state for GPIO129:
# muxing GPIO128 too would block the driver's reset-gpios request (msm pinctrl is strict).
S2=/soc/pinctrl@f000000/u880-ts-int-state
fdtput -c $O $S2
fdtput -t s $O $S2 pins gpio129
fdtput -t x $O $S2 bias-pull-up 0x1
fdtput -t x $O $S2 drive-strength 0x8
fdtput -t x $O $S2 phandle 0x7f000129
fdtput -t s $O $T pinctrl-names default
fdtput -t x $O $T pinctrl-0 0x7f000129
# GPU SMMU: stock dma-coherent (coherent page-table walk) suspected wrong like on USB/SD -> 16px "cache line" dashes
# in the composited framebuffer. Test without it.
fdtput -d $O /soc/kgsl-smmu@3da0000 dma-coherent
# Backlight: LCD backlight = PMXR2230 (SPMI SID 1) LPG channel 0xeb00 (index 3), 100 us period, out on PMIC GPIO9 (func1,
# already muxed by firmware). New node names under the overlay's PMIC node (o25 would overwrite pwms@e800 props).
P=/soc/qcom,spmi@c42d000/qcom,pmxr2230@1
fdtput -p -c $O $P/u880-lpg   # -p: the PMIC node itself only exists after the ABL overlay; it merges into this
fdtput -t s $O $P/u880-lpg compatible qcom,pmxr2230-pwm
fdtput -t u $O $P/u880-lpg '#pwm-cells' 2
fdtput -t x $O $P/u880-lpg phandle 0x7f000200
B=/u880-backlight
fdtput -c $O $B
fdtput -t s $O $B compatible pwm-backlight
fdtput -t x $O $B pwms 0x7f000200 3 100000
fdtput -t u $O $B brightness-levels 0 4095
fdtput -t u $O $B num-interpolated-steps 4095
fdtput -t u $O $B default-brightness-level 1500
# Backlight pin: firmware leaves PMXR2230 GPIO9 as plain "out high" (full brightness, PWM not routed).
# Mux it to func1 (LPG out) like the stock lcd_backlight_pwm_default state.
G=$P/pinctrl@8800/u880-bl-pwm
fdtput -p -c $O $G
fdtput -t s $O $G pins gpio9
fdtput -t s $O $G function func1
fdtput $O $G output-low ""
fdtput $O $G bias-disable ""
fdtput $O $G input-disable ""
fdtput -t u $O $G power-source 0
fdtput -t u $O $G qcom,drive-strength 3
fdtput -t x $O $G phandle 0x7f000201
fdtput -t s $O $B pinctrl-names default
fdtput -t x $O $B pinctrl-0 0x7f000201

# 4a charging: battery-only PMIC GLINK client (uke driver data: battmgr only, no UCSI/altmode;
# the stock /soc/qcom,pmic_glink children don't follow the upstream connector binding and stay disabled).
fdtput -p -t s $O /pmic-glink compatible xiaomi,uke-pmic-glink
fdtput -t s $O /pmic-glink status okay
# Same images Android's adsp-loader picks (stock /soc/qcom,msm-adsp-loader: adsp2 + adsp2_dtb), installed under qcom/u880/.
fdtput -t s $O /soc/remoteproc-adsp@03000000 firmware-name qcom/u880/adsp2.mdt qcom/u880/adsp2_dtb.mdt

# 4b Wi-Fi. Apps SMMU via uke's QSMMUv500 handoff driver (keeps the firmware display streams 0x1c00/2, stock
# qcom,handoff-smrs); WCN6750 via ath11k AHB (uke compat adds the three RF rails), WPSS remoteproc, MSA region.
fdtput -t s $O /soc/apps-smmu@15000000 compatible qcom,sm7675-boot-smmu qcom,sm7675-usb-smmu
fdtput -t s $O /soc/apps-smmu@15000000 status okay
# USB DMA must be translated once the SMMU is live (uke stream 0x40); dwc3 is our only link to the PC.
fdtput -t x $O /usb@a600000 iommus 0x12a 0x40 0x0
# The WCN6750 node comes from the o25 overlay (its properties win over ours): ath11k accepts the stock
# qcom,wcn6750 node directly (kernel patch 0008).

# 4c Bluetooth: WCN6750 on QUP1 SE10 UART (downstream qcom,msm-geni-serial-hs -> mainline geni-uart, FIFO mode, no icc,
# only the GIC irq - the second stock irq is the GPIO43 wake line). hci_qca drives power itself (enable-gpios): rails
# S3B/S1B/S2B/L7B/S3E (S3E needs kernel patch 0010) + BT_EN GPIO156 + SW_CTRL GPIO80. vddasd has no stock rail: fixed stub.
U=/soc/qcom,qupv3_1_geni_se@8c0000/qcom,qup_uart@888000
fdtput -t s $O $U compatible qcom,geni-uart
fdtput -t s $O $U clock-names se
for p in interconnects interconnect-names qcom,wakeup-byte; do fdtput -d $O $U $p; done
fdtput -t x $O $U interrupts-extended 0x1 0x0 0x248 0x4
fdtput -t s $O $U pinctrl-names default sleep
fdtput -t x $O $U pinctrl-0 0x23f 0x240 0x241 0x242
fdtput -t x $O $U pinctrl-1 0x23f 0x240 0x241 0x23e
fdtput -d $O $U pinctrl-2; fdtput -d $O $U pinctrl-3
fdtput -t s $O $U status okay
V=/u880-bt-vddasd
fdtput -c $O $V
fdtput -t s $O $V compatible regulator-fixed; fdtput -t s $O $V regulator-name u880_bt_vddasd
fdtput -t u $O $V regulator-min-microvolt 1800000; fdtput -t u $O $V regulator-max-microvolt 1800000
fdtput $O $V regulator-always-on; fdtput -t x $O $V phandle 0x7f000400
BT=$U/bluetooth
fdtput -c $O $BT
fdtput -t s $O $BT compatible qcom,wcn6750-bt
fdtput -t u $O $BT max-speed 3200000
fdtput -t x $O $BT enable-gpios 0x16c 0x9c 0x0
fdtput -t x $O $BT swctrl-gpios 0x16c 0x50 0x0
fdtput -t x $O $BT vddio-supply 0x1e1
for s in vddaon vddbtcxmx vddrfacmn vddrfa0p8; do fdtput -t x $O $BT $s-supply 0x347; done
fdtput -t x $O $BT vddrfa1p7-supply 0x345
fdtput -t x $O $BT vddrfa1p2-supply 0x346
fdtput -t x $O $BT vddrfa2p2-supply 0x344
fdtput -t x $O $BT vddasd-supply 0x7f000400
# The overlay's downstream btpower node (/soc/bt_wcn6750) names the same GPIOs (156/80/35): gpiolib-shared turned them into
# proxies and the real BT_EN pin (an "egpio", TZ-owned until muxed to gpio) was never claimed. Pre-create it disabled (overlay merges).
fdtput -p -c $O /soc/bt_wcn6750; fdtput -t s $O /soc/bt_wcn6750 status disabled

# 4d Sound step 1: the two Awinic smart PAs sit on QUP1 SE11 I2C (0x34/0x35). Same conversion as the touch I2C (FIFO mode, no icc).
I=/soc/qcom,qupv3_1_geni_se@8c0000/i2c@88c000
for p in dmas dma-names interconnects interconnect-names; do fdtput -d $O $I $p; done
fdtput -t s $O $I compatible qcom,geni-i2c; fdtput -t s $O $I clock-names se
fdtput -t s $O $I status okay

# 4d Sound step A: AudioReach (q6apm/q6prm) on the stock GPR channel; the stock downstream children (spf_core, audio-pkt, q6prm) go,
# the overlay adds the mainline services + LPASS LPI pinctrl. Amps: mainline aw88261 matches the stock compatible (kernel patch 0011);
# the ABL overlay re-adds the stock aw882xx nodes/properties afterwards, so we only add what it does not define.
G=/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr
for c in spf_core audio-pkt q6prm; do fdtput -d $O $G/$c; done
fdtput -d $O $G reg
V=/u880-aw-dvdd
fdtput -c $O $V
fdtput -t s $O $V compatible regulator-fixed; fdtput -t s $O $V regulator-name u880_aw_dvdd
fdtput -t u $O $V regulator-min-microvolt 1800000; fdtput -t u $O $V regulator-max-microvolt 1800000
fdtput $O $V regulator-always-on; fdtput -t x $O $V phandle 0x7f000402
for a in 34 35; do
  N=$I/aw882xx_smartpa@$a
  fdtput -p -c $O $N
  fdtput -t x $O $N reg 0x$a
  fdtput -t x $O $N dvdd-supply 0x7f000402
  fdtput -t s $O $N firmware-name aw882xx_acf.bin
  fdtput -t u $O $N '#sound-dai-cells' 0
done
fdtput -t s $O $I/aw882xx_smartpa@34 sound-name-prefix Right
fdtput -t s $O $I/aw882xx_smartpa@35 sound-name-prefix Left
fdtput -t x $O $I/aw882xx_smartpa@34 phandle 0x7f000410
fdtput -t x $O $I/aw882xx_smartpa@35 phandle 0x7f000411
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $M/linux-7.2.9/include $S/audio-overlay.dtso > $S/audio-overlay.pp.dts
dtc -q -@ -I dts -O dtb -o $S/audio-overlay.dtbo $S/audio-overlay.pp.dts
fdtoverlay -i $O -o $S/dtb2-disabled.aud.dtb $S/audio-overlay.dtbo && mv $S/dtb2-disabled.aud.dtb $O && echo "audio overlay applied"

# 5 UFS (internal storage), read-only first. Overlay from stage1/ufs-overlay.dtso (uke-derived), then drop what the generic host cannot use.
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $M/linux-7.2.9/include $S/ufs-overlay.dtso > $S/ufs-overlay.pp.dts
dtc -q -@ -I dts -O dtb -o $S/ufs-overlay.dtbo $S/ufs-overlay.pp.dts
fdtoverlay -i $O -o $S/dtb2-disabled.ufs.dtb $S/ufs-overlay.dtbo && mv $S/dtb2-disabled.ufs.dtb $O && echo "ufs overlay applied"
for property in msi-parent shared-ice-cfg; do fdtput -d $O /soc/ufshc@1d84000 $property; done
# Reboot to bootloader from Linux (dev loop without buttons): the ABL overlay's downstream /soc/reboot_reason node + SDAM cell; kernel patch 0017
# lets nvmem-reboot-mode drive it. Values are the stock qcom-reboot-reason ones (as in the uke tree).
RR=/soc/reboot_reason
fdtput -p -c $O $RR
fdtput -t x $O $RR mode-normal 0x20
fdtput -t x $O $RR mode-recovery 0x01
fdtput -t x $O $RR mode-bootloader 0x02

# 6 USB-C step 1: USB2 peripheral through the uke DWC3 glue (stage1/usb-overlay.dtso), replacing the fastboot-dependent flattened node above.
fdtput -r $O /usb@a600000
for p in dmas dma-names interconnects interconnect-names; do fdtput -d $O /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000 $p; done
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $M/linux-7.2.9/include $S/usb-overlay.dtso > $S/usb-overlay.pp.dts
dtc -q -@ -I dts -O dtb -o $S/usb-overlay.dtbo $S/usb-overlay.pp.dts
fdtoverlay -i $O -o $S/dtb2-disabled.usb.dtb $S/usb-overlay.dtbo && mv $S/dtb2-disabled.usb.dtb $O && echo "usb overlay applied"
for property in interrupts-extended extcon usb-role-switch; do
  nix_dummy=1; fdtput -d $O /soc/ssusb@a600000 $property 2>/dev/null || true
done

# 6b USB role: USB_MODE=otg (default: roles from UCSI) | peripheral (PC link only) | host (fixed host, test build; same as USB_HOST=1) | otg (roles from UCSI over pmic-glink, or sysfs).
USB_MODE=${USB_MODE:-otg}; [ "${USB_HOST:-0}" = 1 ] && USB_MODE=host
case $USB_MODE in
host)
  fdtput -t s $O /soc/ssusb@a600000 dr_mode host
  fdtput $O /soc/hsphy@88e3000 qcom,u880-host-mode ;;
otg)
  fdtput -t s $O /soc/ssusb@a600000 dr_mode otg
  # Our root pmic-glink node starts the UCSI client (kernel patch 0020) and carries the Type-C connector; its high-speed port points at a stub
  # endpoint in usb0 (the ABL overlay adds its own port/endpoint towards the stock ucsi node, which we do not use).
  fdtput -t s $O /pmic-glink compatible alldocube,u880-pmic-glink
  fdtput -t u $O /pmic-glink '#address-cells' 1; fdtput -t u $O /pmic-glink '#size-cells' 0
  UP=/soc/ssusb@a600000
  fdtput -c $O $UP/port@1; fdtput -t u $O $UP/port@1 reg 1
  fdtput -c $O $UP/port@1/endpoint; fdtput -t x $O $UP/port@1/endpoint phandle 0x7f000500
  C=/pmic-glink/connector@0
  fdtput -c $O $C; fdtput -t s $O $C compatible usb-c-connector; fdtput -t u $O $C reg 0
  fdtput -t s $O $C power-role dual; fdtput -t s $O $C data-role dual
  fdtput -c $O $C/ports; fdtput -t u $O $C/ports '#address-cells' 1; fdtput -t u $O $C/ports '#size-cells' 0
  fdtput -c $O $C/ports/port@0; fdtput -t u $O $C/ports/port@0 reg 0
  fdtput -c $O $C/ports/port@0/endpoint; fdtput -t x $O $C/ports/port@0/endpoint remote-endpoint 0x7f000500 ;;
esac
echo "USB mode: $USB_MODE"

# 7 Display stage 1 (DISP=1): mainline SM8650-variant dispcc on the stock Cliffs display clock controller (stage1/disp-overlay.dtso).
if [ "${DISP:-0}" -ge 1 ]; then
  cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $M/linux-7.2.9/include $S/disp-overlay.dtso > $S/disp-overlay.pp.dts
  dtc -q -@ -I dts -O dtb -o $S/disp-overlay.dtbo $S/disp-overlay.pp.dts
  fdtoverlay -i $O -o $S/dtb2-disabled.disp.dtb $S/disp-overlay.dtbo && mv $S/dtb2-disabled.disp.dtb $O && echo "disp overlay applied"
  fdtput -d $O /soc/clock-controller@af00000 clock-names vdd_mm-supply vdd_mxa-supply
fi

# 7b Display stage 2 (DISP=2): MDSS + DPU nodes (stage1/disp2-overlay.dtso). Needs kernel patch 0022 and dispcc from stage 1.
if [ "${DISP:-0}" -ge 2 ]; then
  cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $M/linux-7.2.9/include $S/disp2-overlay.dtso > $S/disp2-overlay.pp.dts
  dtc -q -@ -I dts -O dtb -o $S/disp2-overlay.dtbo $S/disp2-overlay.pp.dts
  fdtoverlay -i $O -o $S/dtb2-disabled.disp2.dtb $S/disp2-overlay.dtbo && mv $S/dtb2-disabled.disp2.dtb $O && echo "disp2 overlay applied"
fi
