#!/usr/bin/env bash
# Rebuild the kernel from the pristine tarball + our delta and compare with a working tree: proves that the delta in git is complete.
# usage: [KVER=7.4-rc4|7.3.1] [CL=<clang bin dir>] clean-rebuild.sh [work dir=/tmp/clean]
#   7.4-rc4 (default): linux-7.4-rc4.tar.gz + kernel/u880-kernel-delta-7.4.patch + kernel/u880-7.4.config, release 7.4.0-rc4-u880e
#   7.3.1            : linux-7.3.1.tar.xz   + kernel/u880-kernel-delta.patch      + kernel/u880.config,     release 7.3.1-u880e
# The tarball is looked up in the repo root (README step 3). Run inside the aosp container (or set CL= to your clang, LLVM=1 style).
set -euo pipefail
M=$(cd "$(dirname "$0")/.." && pwd); W=${1:-/tmp/clean}; KVER=${KVER:-7.4-rc4}
CL=${CL:-$M/../LineageOS/prebuilts/clang/host/linux-x86/clang-r574158/bin}
SUF=${KVER%-rc*}     # 7.4-rc4 -> 7.4: the files are named by the base version, the tarball by the full one
case $KVER in
  7.3.1) DELTA=$M/kernel/u880-kernel-delta.patch; CFG=$M/kernel/u880.config ;;
  *)     DELTA=$M/kernel/u880-kernel-delta-$SUF.patch; CFG=$M/kernel/u880-$SUF.config ;;
esac
T=$(ls $M/linux-$KVER.tar.* | head -1)
rm -rf "$W"; mkdir -p "$W"; tar -xf "$T" -C "$W"; cd "$W/linux-$KVER"
patch -p1 -s < "$DELTA"
cp "$CFG" .config
make LLVM=$CL/ ARCH=arm64 LOCALVERSION=-u880e olddefconfig >/dev/null
# CONFIG_OPENSSL_SUPPORTS_ML_DSA depends on the host OpenSSL (3.5+), so it may differ without meaning anything
if diff <(grep -v OPENSSL_SUPPORTS_ML_DSA .config) <(grep -v OPENSSL_SUPPORTS_ML_DSA "$CFG") >/dev/null; then echo "config identical to $(basename "$CFG") (ML_DSA line ignored)"; else echo "CONFIG DIFFERS from $(basename "$CFG")"; diff .config "$CFG" | head; exit 1; fi
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-host}
make LLVM=$CL/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image modules
[ -d "$M/linux-$KVER" ] && sha256sum arch/arm64/boot/Image "$M/linux-$KVER/arch/arm64/boot/Image" | cut -c1-16
