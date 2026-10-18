#!/usr/bin/env bash
# Generic ABL bisect. usage: bisect-ops.sh <base.dtb> <ops.txt> <workdir>
# ops.txt: one op per line, "stub <path>" (delete all props except phandle) or "rm <path>" (remove subtree).
# Finds ops that make ABL REJECT, appends them to <workdir>/needed.txt, repeats until all-other-ops ACCEPT.
# Run under: nix-shell -p dtc --run "bash scripts/bisect-ops.sh ..."
set -u
M=/home/USER/External/work/src/mainline; BASE=$1; OPS=$2; W=$3; mkdir -p $W; NEEDED=$W/needed.txt; touch $NEEDED
apply() { local t=$1 op=$2 p=$3
  case $op in
    rm) fdtput -r $t "$p" 2>/dev/null ;;
    stub) for pr in $(fdtget -p $t "$p" 2>/dev/null); do case $pr in phandle|linux,phandle) ;; *) fdtput -d $t "$p" "$pr";; esac; done ;;
  esac; }
[ -f $W/base.dts ] || dtc -I dtb -O dts $BASE -o $W/base.dts 2>/dev/null
build() { grep -vxF -f $NEEDED $OPS > $W/ops-active.txt || true
  python3 -I $M/scripts/stub-dts.py $W/base.dts $W/t.dts $W/ops-active.txt $1
  dtc -q -I dts -O dtb $W/t.dts -o $W/t.dtb; wc -l < $W/ops-active.txt; }
while true; do
  N=$(build 0); build $N >/dev/null; r=$($M/scripts/abl-oracle.sh $W/t.dtb)
  echo "$(date +%T) all ops minus $(wc -l <$NEEDED) needed: $r"
  [ "$r" = ACCEPT ] && { echo DONE; cp $W/t.dtb $W/accepted.dtb; break; }
  [ "$r" = REJECT ] || { echo "oracle error: $r"; exit 1; }
  lo=0; hi=$N
  while (( hi-lo > 1 )); do
    mid=$(( (lo+hi)/2 )); build $mid >/dev/null; r=$($M/scripts/abl-oracle.sh $W/t.dtb)
    echo "$(date +%T)   first $mid ops: $r"
    case $r in ACCEPT) lo=$mid;; REJECT) hi=$mid;; *) echo "oracle error: $r"; exit 1;; esac
  done
  mapfile -t L < <(grep -vxF -f $NEEDED $OPS); echo "NEEDED: ${L[$((hi-1))]}"; echo "${L[$((hi-1))]}" >> $NEEDED
done
