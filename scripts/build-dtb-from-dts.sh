#!/usr/bin/env bash
# Compile dts/u880.dts (the production DTB as one source file) to a DTB. Replaces the stock-DTB patching pipeline (build-stock-disabled.sh) for the installed config.
# usage: build-dtb-from-dts.sh [out.dtb=stage1/dtb2-from-dts.dtb]     run: nix-shell -p dtc --run "bash scripts/build-dtb-from-dts.sh"
# dts/u880.dts was made with `dtc -I dtb -O dts` from stage1/dtb2-native-stats-20261022.dtb; the compile is semantically identical (not byte identical: dtc re-lays the blob).
set -euo pipefail
M=/home/USER/External/work/src/mainline
dtc -q -I dts -O dtb -o "${1:-$M/stage1/dtb2-from-dts.dtb}" $M/dts/u880.dts 2>/dev/null
