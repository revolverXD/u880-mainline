#!/usr/bin/env bash
# Build a TEST boot image that differs from the one installed in boot_b only in the kernel Image and the three UFS modules of the ramdisk
# (they must come from the same build as the kernel or boot hangs before the root mount). DTB, ramdisk init and cmdline are taken from what is installed.
#   U880_HOST=<tablet ip> scripts/make-test-boot-image.sh <kernel build dir> <out.img>
#   e.g.  scripts/make-test-boot-image.sh ../k74/linux-7.4-rc4 ../k74/img/boot-test.img      (needs arch/arm64/boot/Image and the .ko files)
# Reads boot_b over ssh (read-only), writes nothing to the tablet. Flash afterwards with scripts/flash-boot-b-dd.sh (needs the user's go).
set -euo pipefail
M=$(cd "$(dirname "$0")/.." && pwd)
K=$(cd "${1:?kernel build dir}" && pwd); OUT=${2:?out.img}
MKB=/home/USER/External/work/src/LineageOS/system/tools/mkbootimg
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
for f in arch/arm64/boot/Image drivers/ufs/host/ufs-qcom.ko drivers/soc/qcom/qcom_ice.ko drivers/phy/qualcomm/phy-qcom-qmp-ufs.ko; do [ -s "$K/$f" ] || { echo "missing $K/$f"; exit 2; }; done
REL=$(cat "$K/include/config/kernel.release")
# 1. the installed image (boot_b), first 56 MB is enough for kernel+ramdisk+dtb
"$M/scripts/rssh.sh" 'dd if=/dev/disk/by-partlabel/boot_b bs=4M count=14 2>/dev/null' > "$W/boot_b.img"
python3 -I "$MKB/unpack_bootimg.py" --boot_img "$W/boot_b.img" --out "$W/u" > "$W/unpack.txt"
CMD=$(sed -n 's/^command line args: //p' "$W/unpack.txt")
# 2. ramdisk: installed one with the three UFS modules replaced
mkdir "$W/rd" && (cd "$W/rd" && gzip -dc ../u/ramdisk | cpio -id --quiet)
cp "$K/drivers/ufs/host/ufs-qcom.ko" "$K/drivers/soc/qcom/qcom_ice.ko" "$K/drivers/phy/qualcomm/phy-qcom-qmp-ufs.ko" "$W/rd/lib/modules-ufs/"
for m in ufs-qcom qcom_ice phy-qcom-qmp-ufs; do [ "$(strings -a "$W/rd/lib/modules-ufs/$m.ko" | grep -c "^vermagic=$REL ")" = 1 ] || { echo "$m.ko is not release $REL"; exit 3; }; done
(cd "$W/rd" && find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > "$W/ramdisk.cpio.gz")
# 3. pack with the installed parameters (python3 without -I: mkbootimg imports its own directory)
python3 "$MKB/mkbootimg.py" --header_version 2 --os_version 14.0.0 --os_patch_level 2024-03 --kernel "$K/arch/arm64/boot/Image" --ramdisk "$W/ramdisk.cpio.gz" \
  --dtb "$W/u/dtb" --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 --cmdline "$CMD" -o "$OUT"
python3 -I - "$OUT" "$W/boot_b.img" <<'EOF'
import os, struct, sys
out, ref = sys.argv[1:3]; T = 100663296; n = os.path.getsize(out); assert n <= T, "image larger than boot_b"
open(out, "ab").write(b"\0" * (T - n))
a, b = open(out, "rb").read(4096), open(ref, "rb").read(4096)
d = [i for i in range(4096) if a[i] != b[i]]
allowed = set(range(8, 12)) | set(range(16, 20)) | set(range(576, 596))     # kernel_size, ramdisk_size, id hash
assert set(d) <= allowed, f"header differs outside size fields/id: {d}"
print("header ok: only kernel/ramdisk size and id differ; padded to", T)
EOF
echo "release $REL -> $OUT"; sha256sum "$OUT"
