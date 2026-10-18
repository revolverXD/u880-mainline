#!/usr/bin/env bash
# Find which stock-dtb2 subtrees ABL needs. Uses stage1/trim-all.removed (list of removable subtrees).
# Run under: nix-shell -p dtc --run "bash scripts/bisect-abl.sh"
set -u
M=/home/USER/External/work/src/mainline; S=$M/stage1; B=$S/bisect; mkdir -p $B
mapfile -t ALL < $S/trim-all.removed
NEEDED=$B/needed.txt; touch $NEEDED
build() { # $1 = n : remove first n of the (ALL minus needed) list
  mapfile -t L < <(grep -vxF -f $NEEDED <(printf '%s\n' "${ALL[@]}") || true)
  cp $M/stock-dt/dtb2.dtb $B/t.dtb
  for ((i=0;i<$1;i++)); do fdtput -r $B/t.dtb "${L[$i]}"; done
  echo ${#L[@]}
}
while true; do
  N=$(build 0); build $N >/dev/null; r=$($M/scripts/abl-oracle.sh $B/t.dtb)
  echo "$(date +%T) full trim minus $(wc -l <$NEEDED) needed: $r"
  [ "$r" = ACCEPT ] && { echo DONE; cp $B/t.dtb $B/accepted-trim.dtb; break; }
  [ "$r" = REJECT ] || { echo "oracle error: $r"; exit 1; }
  lo=0; hi=$N   # f(lo)=ACCEPT, f(hi)=REJECT
  while (( hi-lo > 1 )); do
    mid=$(( (lo+hi)/2 )); build $mid >/dev/null; r=$($M/scripts/abl-oracle.sh $B/t.dtb)
    echo "$(date +%T)   remove first $mid: $r"
    case $r in ACCEPT) lo=$mid;; REJECT) hi=$mid;; *) echo "oracle error: $r"; exit 1;; esac
  done
  mapfile -t L < <(grep -vxF -f $NEEDED <(printf '%s\n' "${ALL[@]}"))
  echo "NEEDED: ${L[$((hi-1))]}"; echo "${L[$((hi-1))]}" >> $NEEDED
done
