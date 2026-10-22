#!/usr/bin/env bash
# N real display off/on cycles (panel unprepare + prepare) driven from KMS, with one camera photo per cycle.
# A: modetest -a -w <crtc>:ACTIVE:0  -> CRTC off. B: modetest -r -d -> CRTC on with modetest's test pattern,
# so the photo says straight away whether the panel displays. CRTC/connector ids come from `modetest -c` (stable
# for a given kernel build; the current u880c build uses connector 36, crtc 79).
# usage: N=5 scripts/dpms-ab.sh [outdir]   (U880_HOST as usual)
M=/home/USER/External/work/src/mainline
cd $M || exit 1
N=${N:-5}
CRTC=${CRTC:-79}
OUT=${1:-/tmp/dpms-ab}
mkdir -p $OUT
for i in $(seq 1 $N); do
  scripts/rssh.sh "modetest -D /dev/dri/card1 -M msm -a -w $CRTC:ACTIVE:0 >/dev/null 2>&1; sleep 3"
  scripts/rssh.sh "modetest -D /dev/dri/card1 -M msm -r -d >/dev/null 2>&1; sleep 3"
  n=$(scripts/rssh.sh 'dmesg | grep -c "panel on sequence"' 2>/dev/null)
  bash scripts/cam.sh $OUT/full-$i.jpg >/dev/null || { echo "cycle $i: CAM_FAIL"; exit 1; }
  nix-shell -p imagemagick --run "magick $OUT/full-$i.jpg -crop 62%x50%+150+170 +repage -resize 430x $OUT/c$i.jpg" >/dev/null || exit 1
  echo "cycle $i: prepares=$n" | tee -a $OUT/summary.log
done
echo "photos: $OUT/c*.jpg  montage: nix-shell -p imagemagick --run 'magick montage $OUT/c*.jpg -tile 3x -geometry +4+4 $OUT/montage.jpg'"
