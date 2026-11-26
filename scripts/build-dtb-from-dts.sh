#!/usr/bin/env bash
# Compile dts/u880.dts (the production DTB as one source file) to a DTB. Replaces the stock-DTB patching pipeline (build-stock-disabled.sh) for the installed config.
# usage: build-dtb-from-dts.sh [out.dtb=stage1/dtb2-u880.dtb]     run: nix-shell -p dtc --run "bash scripts/build-dtb-from-dts.sh"
# dts/u880.dts was made with `dtc -I dtb -O dts` from stage1/dtb2-native-stats-20261022.dtb; since 2026-11-26 the compile is BYTE-identical to the DTB of the tested image (cmp clean, 504107 bytes).
set -euo pipefail
M=$(cd "$(dirname "$0")/.." && pwd)
dtc -q -I dts -O dtb -o "${1:-$M/stage1/dtb2-u880.dtb}" $M/dts/u880.dts 2>/dev/null
