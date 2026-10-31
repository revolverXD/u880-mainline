#!/usr/bin/env bash
# RAM-boot the DISP=4 test kernel with msm.u880_dbg=<mask>, photograph the screen, print DPU/DSI status.
# usage: scripts/disp-test.sh <mask> <tag>   (slot A must be active; tablet in Linux, Android or fastboot)
set -u
M=/home/USER/External/work/src/mainline; cd $M
mask=$1; tag=$2
if timeout 5 fastboot devices 2>/dev/null | grep -q .; then :
elif timeout 5 adb devices 2>/dev/null | grep -q 'device$'; then :
else timeout 15 scripts/rssh.sh 'sync; reboot bootloader' >/dev/null 2>&1
     for i in $(seq 1 40); do timeout 5 fastboot devices 2>/dev/null | grep -q . && break; sleep 3; done; fi
DISP=4 MORE="msm.u880_dbg=$mask" KIMG=linux-7.3.1/arch/arm64/boot/Image scripts/boot-alarm.sh stage1/dtb2-disabled.dtb 2>&1 | tail -1
sleep 25
scripts/cam.sh photos/dbg-$tag.jpg
timeout 30 scripts/rssh.sh 'cat /sys/module/msm/parameters/u880_dbg; cat /sys/kernel/debug/dri/1/encoder-0/status | head -1;
  echo recov=$(journalctl -k -b --no-pager | grep -c "links recovered") dsierr=$(journalctl -k -b --no-pager | grep -c "dsi[01] error");
  grep -E "^0ae9(4|6)0(04|0c|a8) " /sys/kernel/debug/u880-display/live | tr "\n" " "; echo'
