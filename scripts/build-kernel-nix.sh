#!/usr/bin/env bash
# Build a kernel tree on the NixOS host with Nix's unwrapped clang, for when the aosp container is not usable. Used for the 7.4-rc4 port (src/k74).
#   [MODULES_OUT=<dir>] scripts/build-kernel-nix.sh <kernel tree> [make targets, default "Image Image.gz modules"]
# MODULES_OUT: also run modules_install into <dir> (lib/modules/<release>/ there is what build-rootfs-image.sh wants as MODULES). The boot image uses arch/arm64/boot/Image (uncompressed).
# The tree needs its .config in place (copy kernel/u880-7.4.config), LOCALVERSION is pinned to -u880e. Compiler is clang 21.1.8, not the Android r574158 (both 21.x, same ABI options).
# certs/extract-cert needs an x86_64 libcrypto at run time: picked below by reading the ELF header (a 32-bit openssl also lives in the store).
set -euo pipefail
T=$(cd "${1:?kernel tree}" && pwd); TARGETS=${2:-Image Image.gz modules}
L=""
for d in /nix/store/*-openssl-3*/lib; do   # a for loop, not "ls | while | head -1": under pipefail head closing the pipe killed the script with exit 141
  f=$(readlink -f "$d/libcrypto.so.3" 2>/dev/null) || continue
  [ -e "$f" ] && python3 -I -c "import sys;h=open(sys.argv[1],'rb').read(20);sys.exit(0 if h[4]==2 and h[18]==0x3e else 1)" "$f" && { L=$d; break; }
done
if [ -z "$L" ]; then P=$(nix-build '<nixpkgs>' -A openssl.out --no-out-link 2>/dev/null) && [ -e "$P/lib/libcrypto.so.3" ] && L=$P/lib; fi   # a clean store has none yet: build/fetch it
[ -n "$L" ] || { echo "no x86_64 openssl lib in /nix/store and nix-build of nixpkgs#openssl failed"; exit 1; }
M="LLVM=1 HOSTCC=gcc HOSTCXX=g++ HOSTLD=ld ARCH=arm64 LOCALVERSION=-u880e"
nix-shell -p llvmPackages.clang-unwrapped llvmPackages.lld llvmPackages.llvm gcc gnumake flex bison bc openssl perl elfutils zlib cpio python3 kmod --run "export LD_LIBRARY_PATH=$L; cd $T && make $M -j\$(nproc) $TARGETS"
if [ -n "${MODULES_OUT:-}" ]; then
  nix-shell -p llvmPackages.clang-unwrapped llvmPackages.lld llvmPackages.llvm gcc gnumake flex bison bc openssl perl elfutils zlib cpio python3 kmod --run "export LD_LIBRARY_PATH=$L; cd $T && make $M INSTALL_MOD_PATH=$(mkdir -p "$MODULES_OUT" && cd "$MODULES_OUT" && pwd) INSTALL_MOD_STRIP=1 modules_install"
fi
