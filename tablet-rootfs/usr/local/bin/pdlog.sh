#!/bin/sh
# U880: log charger/battery/Type-C state every 2 s (usage: pdlog.sh <seconds> > file)
end=$(( $(date +%s) + ${1:-240} ))
U=/sys/class/power_supply/qcom-battmgr-usb; B=/sys/class/power_supply/qcom-battmgr-bat; T=/sys/class/typec/port0
while [ $(date +%s) -lt $end ]; do
  echo "$(date +%T) usb_online=$(cat $U/online) type=$(sed 's/.*\[\(.*\)\].*/\1/' $U/usb_type) vbus=$(cat $U/voltage_now) vmax=$(cat $U/voltage_max) ibus=$(cat $U/current_now) imax=$(cat $U/current_max) icl=$(cat $U/input_current_limit) | bat i=$(cat $B/current_now) v=$(cat $B/voltage_now) cap=$(cat $B/capacity) st=$(cat $B/status) | pwrrole=$(cat $T/power_role 2>/dev/null) mode=$(cat $T/power_operation_mode 2>/dev/null) partner=$(ls -d $T/port0-partner 2>/dev/null | wc -l) pd=$(cat $T/port0-partner/usb_power_delivery_revision 2>/dev/null)"
  sleep 2
done
