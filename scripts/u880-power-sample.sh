#!/bin/sh
# Average battery discharge power over N seconds (default 60). Run on the tablet with no charger attached.
# qcom-battmgr-bat current_now is negative while discharging (U880 firmware), uA; voltage_now in uV.
n=${1:-60}; b=/sys/class/power_supply/qcom-battmgr-bat
[ "$(cat /sys/class/power_supply/qcom-battmgr-usb/online)" = 0 ] || { echo "charger attached"; exit 1; }
i=0; sum=0
while [ $i -lt "$n" ]; do
	sum=$(awk -v s="$sum" -v c="$(cat $b/current_now)" -v v="$(cat $b/voltage_now)" 'BEGIN { printf "%.0f", s - c * v / 1e9 }')
	i=$((i + 1)); sleep 1
done
awk -v s="$sum" -v n="$n" 'BEGIN { printf "avg %.0f mW over %d s\n", s / n, n }'
