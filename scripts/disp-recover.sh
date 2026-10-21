#!/usr/bin/env bash
# Is the display lottery per boot or per enable? Boot an image N times; photo the screen, then blank/unblank fb0
# (that runs the panel off+on sequence again without rebooting) and photo again. If "after" is good where
# "before" was bad, the fix is an in-driver retry of the enable sequence instead of a reboot.
# usage: N=3 U880_HOST=172.16.42.2 scripts/disp-recover.sh stage1/u880-boot-disp4-0x4110cf80-d2_0xa.img
# Output: $OUT/{before,after}-<n>.jpg and $OUT/montage.jpg (pairs: before,after per row).
set -uo pipefail
M=/home/USER/External/work/src/mainline; cd $M
OUT=${OUT:-/tmp/disp-recover}; mkdir -p $OUT
export U880_HOST=${U880_HOST:-172.16.42.2}
N=${N:-3}
img=${1:?boot image}
for n in $(seq 1 $N); do
  timeout 20 scripts/rssh.sh 'pkill -x modetest; sync; reboot bootloader' >/dev/null 2>&1
  for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done; sleep 2
  timeout 60 fastboot boot $img >/dev/null 2>&1
  ok=0; for i in $(seq 1 50); do timeout 10 scripts/rssh.sh true 2>/dev/null && { ok=1; break; }; sleep 3; done
  [ $ok = 0 ] && { echo "#$n HANG"; exit 1; }
  sleep 28
  # keep the console lit so a blanked screen is not mistaken for the black failure mode
  timeout 20 scripts/rssh.sh 'echo 0 > /sys/class/graphics/fb0/blank' 2>/dev/null
  sleep 2
  timeout 20 scripts/rssh.sh 'dmesg | grep -E "lockstep|band cal"' > $OUT/$n.dmesg 2>/dev/null
  p=$(bash scripts/cam.sh $OUT/raw-before-$n.jpg | tail -1) || { echo "#$n CAM_FAIL"; exit 1; }
  # 4 = FB_BLANK_POWERDOWN; 1 (NORMAL) is a no-op in drm_fb_helper_blank. dpms must read Off in the middle.
  timeout 30 scripts/rssh.sh 'echo 4 > /sys/class/graphics/fb0/blank; sleep 4; cat /sys/class/drm/card1-DSI-1/dpms; echo 0 > /sys/class/graphics/fb0/blank' 2>/dev/null | tee $OUT/$n.dpms
  sleep 3
  q=$(bash scripts/cam.sh $OUT/raw-after-$n.jpg | tail -1) || { echo "#$n CAM_FAIL"; exit 1; }
  nix-shell -p imagemagick --run "magick $p -crop 62%x50%+150+170 +repage -resize 430x $OUT/before-$n.jpg; magick $q -crop 62%x50%+150+170 +repage -resize 430x $OUT/after-$n.jpg" >/dev/null 2>&1 || exit 1
  echo "#$n done: $OUT/before-$n.jpg $OUT/after-$n.jpg $(grep -m1 'lockstep-ON' $OUT/$n.dmesg | grep -o '0x0a=[0-9a-f:]*')"
done
l=""
for n in $(seq 1 $N); do l="$l -label before-$n $OUT/before-$n.jpg -label after-$n $OUT/after-$n.jpg"; done
nix-shell -p imagemagick --run "magick montage $l -tile 2x -geometry +4+4 $OUT/montage.jpg"
echo "montage: $OUT/montage.jpg"
