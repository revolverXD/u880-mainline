#!/usr/bin/env bash
# Repeatable benchmark for the U880. Run ON the tablet as root, logged in to the desktop session, screen on, on the SAME power/cooling setup every time:
#   scripts/bench.sh [outdir]      (Wi-Fi throughput is measured separately from the PC: scripts/bench-wifi.sh)
# Writes <outdir>/results.txt (+ raw logs). Tools that are missing are skipped, never installed. Takes about 6-8 minutes and heats the SoC:
# it waits for a cool start (< 45 C) and stops a phase early above 97 C. u880-thermal-guard stays active.
OUT=${1:-/root/bench-$(uname -r)-$(date +%Y%m%d-%H%M)}; mkdir -p "$OUT"; R=$OUT/results.txt; : > "$R"
UENV="XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus"
have() { command -v "$1" >/dev/null 2>&1; }
temp() { cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1 | awk '{printf "%.0f", $1/1000}'; }
freqs() { echo "cpu0=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)/1000 ))MHz cpu7=$(( $(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq)/1000 ))MHz"; }
say() { echo "$*" | tee -a "$R"; }
phase() { say ""; say "## $1  (start ${2:-}  T=$(temp)C)"; }
cool() { for i in $(seq 1 60); do [ "$(temp)" -lt 45 ] && return; sleep 5; done; say "(cool-down gave up at $(temp)C)"; }
yaml() { awk -F': ' '/bogo-ops-per-second-real-time/ {printf "%.1f", $2; exit}' "$1"; }

# keep the screen on and unlocked for the whole run (a lock mid-run breaks the on-screen GPU phase); 15 min is longer than the run
su USER -c "export $UENV; nohup kde-inhibit --power --screenSaver sleep 900 >/dev/null 2>&1 &"
trap 'pkill -f "kde-inhibit --power --screenSaver sleep 9[0]0"' EXIT
say "# U880 benchmark  $(date -Is)"
say "kernel=$(uname -r)  cores=$(nproc)  mem=$(free -m | awk '/Mem:/{print $2}')MB  governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
say "cpu0 max=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)/1000 ))MHz  cpu7 max=$(( $(cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_max_freq)/1000 ))MHz"
say "battery=$(cat /sys/class/power_supply/qcom-battmgr-bat/capacity 2>/dev/null)% $(cat /sys/class/power_supply/qcom-battmgr-bat/status 2>/dev/null)  wifi=$(iw dev wlan0 link 2>/dev/null | awk '/SSID|signal/{printf "%s ", $0}' | tr -s ' \t' ' ')"
say "boot: $(systemd-analyze 2>/dev/null | head -1)"
cool

# clock sampling DURING a test (reading it afterwards shows the idle clock): sample <cpu> <file> ... avgf <file>
sample() { ( while :; do cat /sys/devices/system/cpu/cpu$1/cpufreq/scaling_cur_freq; sleep 1; done > "$2" ) & SPID=$!; }
avgf() { kill $SPID 2>/dev/null; wait $SPID 2>/dev/null; awk '{s+=$1;n++} END{printf "%d", n ? s/n/1000 : 0}' "$1"; }
for c in 7 0; do   # core 7 = prime (2803 MHz max), core 0 = little (1900 MHz max)
  [ $c = 7 ] && kind=prime || kind=little
  phase "CPU single thread on core $c ($kind): stress-ng matrixprod 30 s, openssl 3 s per algorithm (higher is better)" "$(freqs)"
  have stress-ng && { sample $c "$OUT/f$c.txt"; taskset -c $c stress-ng --cpu 1 --cpu-method matrixprod -t 30 --metrics --yaml "$OUT/cpu1-$c.yaml" >"$OUT/cpu1-$c.log" 2>&1; say "matrixprod core $c: $(yaml "$OUT/cpu1-$c.yaml") bogo ops/s   sampled clock avg (indicative only, the prime core hops 480/1459/2803 MHz under load) $(avgf "$OUT/f$c.txt")MHz   end T=$(temp)C"; }
  have openssl && { taskset -c $c openssl speed -seconds 3 -evp sha256 aes-256-cbc >"$OUT/openssl1-$c.log" 2>&1; say "openssl core $c, 16 KiB blocks: $(awk '/^(sha256|aes-256-cbc) /{printf "%s %s  ", $1, $NF}' "$OUT/openssl1-$c.log")"; }
  cool
done
phase "CPU all cores (stress-ng matrixprod, 60 s, 8 workers)" "$(freqs)"
have stress-ng && { sample 7 "$OUT/f7a.txt"; stress-ng --cpu 8 --cpu-method matrixprod -t 60 --metrics --yaml "$OUT/cpu8.yaml" >"$OUT/cpu8.log" 2>&1; say "matrixprod 8 threads: $(yaml "$OUT/cpu8.yaml") bogo ops/s   sampled prime-core clock avg (indicative only) $(avgf "$OUT/f7a.txt")MHz   end T=$(temp)C"; }
have openssl && { openssl speed -seconds 3 -multi 8 -evp sha256 aes-256-cbc >"$OUT/openssl8.log" 2>&1; say "openssl 8 procs, 16 KiB blocks: $(awk '/^(sha256|aes-256-cbc) /{printf "%s %s  ", $1, $NF}' "$OUT/openssl8.log")"; }
cool
phase "Memory bandwidth (stress-ng memcpy, 8 workers, 20 s)"
have stress-ng && { stress-ng --memcpy 8 -t 20 --metrics --yaml "$OUT/mem.yaml" >"$OUT/mem.log" 2>&1; say "memcpy 8 workers: $(yaml "$OUT/mem.yaml") bogo ops/s"; }

phase "Storage (UFS, ext4 root, O_DIRECT, 1 GiB file)"
F=/var/tmp/u880-bench.dat
w=$(dd if=/dev/zero of=$F bs=1M count=1024 oflag=direct conv=fsync 2>&1 | grep -oE '[0-9.]+ [MG]B/s' | tail -1); say "sequential write 1 MiB: $w"
r=$(dd if=$F of=/dev/null bs=1M iflag=direct 2>&1 | grep -oE '[0-9.]+ [MG]B/s' | tail -1); say "sequential read 1 MiB:  $r"
have python3 && say "random read 4 KiB QD1: $(python3 - "$F" <<'EOF'
import os, mmap, random, sys, time
f = os.open(sys.argv[1], os.O_RDONLY | os.O_DIRECT); n = os.fstat(f).st_size // 4096
buf = mmap.mmap(-1, 4096); t = time.time(); c = 0
while time.time() - t < 10:
    os.preadv(f, [buf], random.randrange(n) * 4096); c += 1
print("%d IOPS (%.1f MB/s)" % (c / 10, c / 10 * 4096 / 1e6))
EOF
)"
rm -f $F

phase "GPU (glmark2-wayland, default scenes, on screen)"
if have glmark2-wayland; then
  su USER -c "export $UENV; glmark2-wayland" >"$OUT/glmark2.log" 2>&1
  say "glmark2 score: $(awk '/glmark2 Score/{print $NF}' "$OUT/glmark2.log")   $(grep -E 'GL_RENDERER|GL_VERSION' "$OUT/glmark2.log" | tr -s ' ' | tr '\n' ';')   end T=$(temp)C"
fi

say ""; say "## Wi-Fi throughput: run scripts/bench-wifi.sh from the PC (the PC firewall blocks the tablet from connecting to it)"

say ""; say "# end  $(date -Is)  T=$(temp)C  throttle: $(journalctl -u u880-thermal-guard -n 1 --no-pager 2>/dev/null | grep -oE 'throttle=[0-9.]+' | tail -1)"
echo "results: $R"
