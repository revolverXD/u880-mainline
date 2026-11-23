#!/bin/sh
# #15 / F14: does the USB gadget survive s2idle, and what brings it back? Runs ON the tablet, detached; the ssh link dies during the suspend,
# so everything goes to /root/s2idle15.log (read it after the tablet is reachable again; the PC's `journalctl -k` shows the host side).
# usage on the tablet: setsid nohup sh /root/usb-s2idle-test.sh [seconds] [freeze|suspend] >/dev/null 2>&1 &   (suspend = through logind and the system-sleep hooks, like the power button)
S=${1:-30}; L=/root/s2idle15.log; U=$(ls /sys/class/udc | head -1)
log() { echo "$(date +%T) $*" >> $L; }
snap() { log "$1 udc=$U state=$(cat /sys/class/udc/$U/state) speed=$(cat /sys/class/udc/$U/current_speed) role=$(cat /sys/class/usb_role/*/role 2>/dev/null | tr '\n' ' ') typec=$(cat /sys/class/typec/port0/data_role 2>/dev/null)"; }
: > $L; snap before; dmesg > /root/s2idle15-dmesg-before.txt; N=$(wc -l < /root/s2idle15-dmesg-before.txt)
sync; sleep 3
if [ "${2:-freeze}" = suspend ]; then rtcwake -m no -s $S >> $L 2>&1; systemctl suspend >> $L 2>&1; log "systemctl suspend returned rc=$?"; else rtcwake -m freeze -s $S >> $L 2>&1; log "rtcwake returned rc=$?"; fi
snap after-resume; sleep 5; snap resume+5s
dmesg | tail -n +$N | grep -iE "dwc3|udc|usb|xhci|typec|ucsi|g_cdc|cdc|pmic_glink|eusb2|qmp|phy" >> $L
if [ "$(cat /sys/class/udc/$U/state)" != configured ]; then
	log "gadget not configured: try soft_connect toggle"; echo disconnect > /sys/class/udc/$U/soft_connect; sleep 1; echo connect > /sys/class/udc/$U/soft_connect; sleep 8; snap after-soft-connect
fi
if [ "$(cat /sys/class/udc/$U/state)" != configured ]; then
	log "still not configured: unbind/bind dwc3 $U"; echo $U > /sys/bus/platform/drivers/dwc3/unbind; sleep 2; echo $U > /sys/bus/platform/drivers/dwc3/bind; sleep 10; snap after-rebind
fi
dmesg | tail -n +$N | grep -iE "dwc3|udc|usb|xhci|typec|ucsi|g_cdc|cdc|pmic_glink|eusb2|qmp|phy" > /root/s2idle15-dmesg-usb.txt
log done
