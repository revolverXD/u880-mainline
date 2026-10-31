#!/usr/bin/env bash
# Rebuild the kernel from the pristine tarball + kernel/u880-kernel-delta.patch + kernel/u880_defconfig, and compare with linux-7.3.1/. Run inside the aosp container.
# usage: clean-rebuild.sh [work dir=/tmp/clean]
set -euo pipefail
M=/home/USER/External/work/src/mainline; W=${1:-/tmp/clean}
CL=/home/USER/External/work/src/LineageOS/prebuilts/clang/host/linux-x86/clang-r574158/bin
rm -rf $W; mkdir -p $W; tar -xf $M/linux-7.3.1.tar.xz -C $W; cd $W/linux-7.3.1
patch -p1 -s < $M/kernel/u880-kernel-delta.patch
cp $M/kernel/u880_defconfig arch/arm64/configs/u880_defconfig
make LLVM=$CL/ ARCH=arm64 u880_defconfig >/dev/null
diff -q .config $M/kernel/u880.config && echo "config identical to kernel/u880.config"
export KBUILD_BUILD_USER=USER KBUILD_BUILD_HOST=nixos
make LLVM=$CL/ ARCH=arm64 LOCALVERSION=-u880c -j$(nproc) Image modules
sha256sum arch/arm64/boot/Image $M/linux-7.3.1/arch/arm64/boot/Image | cut -c1-16
