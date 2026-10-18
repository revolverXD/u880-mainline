#!/usr/bin/env bash
# Stage 1 kernel: arm64 defconfig + simplefb console + pstore/ramoops built in. Run inside distrobox "aosp".
set -e
M=/home/USER/External/work/src/mainline
CL=/home/USER/External/work/src/LineageOS/prebuilts/clang/host/linux-x86/clang-r574158/bin
K=$M/linux-6.17.11
[ -d $K ] || tar xf /home/USER/External/work/src/root/guest-kernel/linux-6.17.11.tar.xz -C $M
cd $K
make LLVM=$CL/ ARCH=arm64 defconfig >/dev/null
./scripts/config -e FB -e FB_SIMPLE -e FRAMEBUFFER_CONSOLE -e FRAMEBUFFER_CONSOLE_DETECT_PRIMARY \
  -e FONT_TER16x32 -e FONTS \
  -e PSTORE -e PSTORE_RAM -e PSTORE_PMSG -e PSTORE_CONSOLE \
  -e USB_LIBCOMPOSITE -e USB_G_SERIAL -e USB_U_SERIAL -e USB_F_ACM -e USB_F_SERIAL -e USB_F_OBEX \
  -d DRM_SIMPLEDRM -d SYSFB_SIMPLEFB -e PRINTK_TIME -e MAGIC_SYSRQ -e BLK_DEV_INITRD -e DEVTMPFS -e DEVTMPFS_MOUNT
make LLVM=$CL/ ARCH=arm64 olddefconfig >/dev/null
./scripts/config -k -e FONT_TER16x32; make LLVM=$CL/ ARCH=arm64 olddefconfig >/dev/null
for o in FB_SIMPLE FRAMEBUFFER_CONSOLE PSTORE_RAM PSTORE_PMSG FONT_TER16x32 USB_DWC3 USB_LIBCOMPOSITE USB_G_SERIAL; do grep -E "^CONFIG_$o=y" .config || echo "MISSING $o"; done
make LLVM=$CL/ ARCH=arm64 -j$(nproc) Image
ls -la arch/arm64/boot/Image
