#!/usr/bin/env bash
# RAM-boot a boot image (fastboot boot, nothing flashed), run the 45 s s2idle test with qcom_stats counters, print the deltas.
# usage: U880_HOST=<wifi ip> ram-boot-sleeptest.sh <img> <label> [seconds] [PRE-command]   (PC USB cable to the tablet's port needed for fastboot)
# After the test the tablet stays in the RAM-booted system; a normal reboot returns to boot_b.
set -uo pipefail
M=/home/USER/External/work/src/mainline; IMG=${1:?img}; LBL=${2:?label}; SEC=${3:-45}; PRE=${4:-}
H=${U880_HOST:-192.168.X.Y}
r() { U880_HOST=$H timeout "${T:-60}" $M/scripts/rssh.sh "$@"; }
# fastboot boot is rejected while slot B is active (NOTES 4c): run `fastboot set_active a` once first; return with `fastboot set_active b` and re-mark B successful.
if [ "${ALREADY_BOOTED:-0}" != 1 ]; then
echo "[$LBL] rebooting to the bootloader"
U880_HOST=$H timeout 20 $M/scripts/rssh.sh 'sync; reboot bootloader' >/dev/null 2>&1
for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
timeout 5 fastboot devices | grep -q fastboot || { echo "[$LBL] no fastboot (is the PC cable connected?)"; exit 3; }
sleep 2; timeout 90 fastboot boot $IMG >/dev/null 2>&1 || { echo "[$LBL] fastboot boot failed (slot B active? see above)"; exit 4; }
fi
ok=0; for i in $(seq 1 60); do r true 2>/dev/null && { ok=1; break; }; sleep 4; done
[ $ok = 1 ] || { echo "[$LBL] no ssh after boot (hang? power-button restart needed)"; exit 5; }
sleep 40
r "pgrep -x deniald >/dev/null && echo denial-up; ls /sys/class/ieee80211 | head -1; tr ' ' '\n' < /proc/cmdline | grep -cE 'ignore_unused' | sed 's/^/ignore_unused flags: /'"
cat $M/scripts/sleepstat.sh | r "cat > /root/sleepstat.sh; chmod +x /root/sleepstat.sh; rm -f /root/sleepstat-$LBL.log; (PRE='$PRE' POST='${POST:-}' DIRECT='${DIRECT:-}' setsid nohup /root/sleepstat.sh $SEC /root/sleepstat-$LBL.log >/dev/null 2>&1 &); echo test started"
sleep $((SEC+25))
for i in $(seq 1 40); do T=8 r "tail -1 /root/sleepstat-$LBL.log" 2>/dev/null | grep -q DONE && break; sleep 5; done
T=30 r "grep -E '^== (before|after)|aosd:|cxsd:|^ddr:|apss:|adsp:|wpss:|ddrlpm: count \+[1-9]|^success|failed_resume' /root/sleepstat-$LBL.log" | sed "s/^/[$LBL] /"
