#!/usr/bin/env bash
# Rebuild only hid-microsoft.ko (gamepad BT report-descriptor fixup, FINDINGS F44) on the NixOS host, no container:
# Nix clang 21.1.8 (unwrapped) builds it as an external module against a reflink COPY of the built tree, so
# linux-7.3.1/ itself is never touched. CONFIG_MODVERSIONS is off, so only the vermagic (7.3.1-u880e) has to match
# (no LTO/CFI/RANDSTRUCT in u880.config; the Android clang is r574158 = 21.0.0).
# Output: ../hidbuild/ext/hid-microsoft.ko. Install: scp to the tablet's /usr/lib/modules/7.3.1-u880e/kernel/drivers/hid/, depmod, rmmod/modprobe hid_microsoft.
set -e
M=/home/USER/External/work/src/mainline
B=$M/../hidbuild
cmp $M/linux-7.3.1/.config $M/kernel/u880.config || { echo ".config differs from kernel/u880.config, stop"; exit 1; }
grep -q '^# CONFIG_DEVMEM is not set' $M/kernel/u880.config || { echo "DEVMEM set, stop"; exit 1; }
mkdir -p $B/ext
[ -d $B/linux-7.3.1 ] || cp -a --reflink=auto $M/linux-7.3.1 $B/
cp $M/linux-7.3.1/drivers/hid/hid-microsoft.c $B/ext/
printf 'obj-m := hid-microsoft.o\nccflags-y := -I$(srctree)/drivers/hid\n' > $B/ext/Kbuild
cd $B/linux-7.3.1
nix-shell -p llvmPackages.clang-unwrapped llvmPackages.lld llvmPackages.llvm gcc gnumake flex bison bc openssl perl elfutils zlib --run \
  "make LLVM=1 HOSTCC=gcc HOSTCXX=g++ HOSTLD=ld ARCH=arm64 LOCALVERSION=-u880e KBUILD_MODPOST_WARN=1 M=$B/ext modules"
strings -a $B/ext/hid-microsoft.ko | grep -E "^vermagic=|completing truncated"
sha256sum $B/ext/hid-microsoft.ko
