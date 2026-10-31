#!/usr/bin/env bash
# Linux 7.2.9 + uke patch series (ref/senemos-uke-kernel-mainline) + U880 overrides. Run inside the aosp container.
set -e
M=/home/USER/External/work/src/mainline
CL=/home/USER/External/work/src/LineageOS/prebuilts/clang/host/linux-x86/clang-r574158/bin
C=$M/ref/senemos-uke-kernel-mainline/configs
cd $M/linux-7.3.1
make LLVM=$CL/ ARCH=arm64 defconfig >/dev/null
KCONFIG_CONFIG=.config ./scripts/kconfig/merge_config.sh -m .config $C/arm64-qcom.config $C/uke.config $M/scripts/u880-7.config >/dev/null
make LLVM=$CL/ ARCH=arm64 olddefconfig >/dev/null
for o in PINCTRL_CLIFFS SM_GCC_CLIFFS SM_GPUCC_CLIFFS DRM_MSM USB_DWC3_QCOM USB_CDC_COMPOSITE DRM_SIMPLEDRM SECURITY_LANDLOCK DRM_PANEL_ALLDOCUBE_U880 TOUCHSCREEN_NOVATEK_NVT_TS GPIO_SHARED_PROXY POWER_RESET_QCOM_PON RTC_DRV_PM8XXX LEDS_QCOM_LPG BACKLIGHT_PWM MMC_SDHCI_MSM FONT_TER16x32; do grep -E "^CONFIG_$o=y" .config || echo "MISSING $o"; done
make LLVM=$CL/ ARCH=arm64 LOCALVERSION=${LV:--u880c} -j$(nproc) Image modules
ls -la arch/arm64/boot/Image
# Modules for ALARM's /usr/lib/modules (ADSP/battery/Wi-Fi/audio stacks load from the SD root with its firmware).
rm -rf $M/modules-out
make LLVM=$CL/ ARCH=arm64 INSTALL_MOD_PATH=$M/modules-out INSTALL_MOD_STRIP=1 modules_install >/dev/null
tar -C $M/modules-out/lib/modules -czf $M/modules-out/modules.tar.gz .
ls -la $M/modules-out/modules.tar.gz
