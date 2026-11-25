#!/usr/bin/env bash
# Build a kernel tree on the NixOS host with Nix's unwrapped clang, for when the aosp container is not usable. Used for the 7.4-rc4 port (src/k74).
#   scripts/build-kernel-nix.sh <kernel tree> [make targets, default "Image.gz modules"]
# The tree needs its .config in place (copy kernel/u880-7.4.config), LOCALVERSION is pinned to -u880e. Compiler is clang 21.1.8, not the Android r574158 (both 21.x, same ABI options).
# certs/extract-cert needs an x86_64 libcrypto at run time: picked below by reading the ELF header (a 32-bit openssl also lives in the store).
set -euo pipefail
T=$(cd "${1:?kernel tree}" && pwd); TARGETS=${2:-Image.gz modules}
L=$(ls -d /nix/store/*-openssl-3*/lib 2>/dev/null | while read -r d; do f=$(readlink -f "$d/libcrypto.so.3" 2>/dev/null) || continue; [ -e "$f" ] && python3 -I -c "import sys;h=open(sys.argv[1],'rb').read(20);sys.exit(0 if h[4]==2 and h[18]==0x3e else 1)" "$f" && echo "$d"; done | head -1)
[ -n "$L" ] || { echo "no x86_64 openssl lib in /nix/store (nix-shell -p openssl first)"; exit 1; }
M="LLVM=1 HOSTCC=gcc HOSTCXX=g++ HOSTLD=ld ARCH=arm64 LOCALVERSION=-u880e"
nix-shell -p llvmPackages.clang-unwrapped llvmPackages.lld llvmPackages.llvm gcc gnumake flex bison bc openssl perl elfutils zlib cpio python3 kmod --run "export LD_LIBRARY_PATH=$L; cd $T && make $M -j\$(nproc) $TARGETS"
