#!/usr/bin/env bash
# Emit inert stub nodes for every label the stock board overlay (o25) references, so ABL can apply it to our minimal DT.
# The stubs live under /stubs (no compatible, not a bus), so Linux never creates devices for them.
set -e
M=/home/USER/External/work/src/mainline
OWN="reserved_memory intc cpu0 cpu1 cpu2 cpu3 cpu4 cpu5 cpu6 cpu7"
echo "/ {"; echo "	stubs {"
for l in $(fdtget -p $M/stock-dt/o25.dtb /__fixups__); do
  case " $OWN " in *" $l "*) continue;; esac
  echo "		$l: ${l//_/-} { };"
done
echo "	};"; echo "};"
