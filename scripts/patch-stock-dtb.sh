#!/usr/bin/env bash
# Stage 1b: stock Cliffs7P SoC DTB (so ABL's dtbo overlay still applies) + fixed ramoops + splash simple-framebuffer.
set -e
M=/home/USER/External/work/src/mainline
O=$M/stage1/dtb2-patched.dtb
cp $M/stock-dt/dtb2.dtb $O
R=/reserved-memory/ramoops_region
fdtput -d $O $R alloc-ranges
fdtput -d $O $R size
fdtput -t x $O $R reg 0xa 0xfe600000 0x0 0x200000
fdtput -t x $O $R pmsg-size 0
fdtput -t x $O $R record-size 0
fdtput -t x $O $R console-size 0x200000
fdtput -t x $O $R ecc-size 0
fdtput -t x $O $R mem-type 0
F=/chosen/framebuffer@e3940000
fdtput -c $O $F
fdtput -t s $O $F compatible simple-framebuffer
fdtput -t x $O $F reg 0x0 0xe3940000 0x0 0xfa0000
fdtput -t u $O $F width 1600
fdtput -t u $O $F height 2560
fdtput -t u $O $F stride 6400
fdtput -t s $O $F format a8r8g8b8
fdtget -t x $O $R reg; fdtget -t s $O $F compatible
