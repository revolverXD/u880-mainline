#!/usr/bin/env bash
# Does a CCI master really drive its pads? (re-proof for FINDINGS F37/F38)
# Polls the TLMM pad registers and reads the CAMCC branch twice: bus idle, then while the bus carries traffic.
# The traffic must be transactions that actually COMPLETE - a write to an address that NACKs makes the CCI log
# "queue 0 timeout", and no waveform may be observable (measured 2026-11-02: with the module unpowered, a probe
# loop over unpopulated addresses times out on BOTH masters and the pads stay static, which proves nothing). Use
# addresses that ACK, and power the module first (echo on > .../power/control). The traffic is a pointer-write +
# read, so it never scribbles on an unknown device.
# Needs a RAM-booted DEV kernel (/dev/mem) and scripts/mclk-check.py copied to /root/mclk-check.py.
# usage: scripts/rssh.sh 'bash -s <bus> <sda_pin> <scl_pin> [addr ...]' < scripts/cci-traffic-check.sh
set -u
B=${1:-6} SDA=${2:-70} SCL=${3:-71}; shift 3 2>/dev/null
ADDRS="${*:-0x0c 0x50 0x58}"
[ -e /dev/mem ] || { echo "need a DEV kernel (/dev/mem)"; exit 1; }
[ -f /root/mclk-check.py ] || { echo "copy scripts/mclk-check.py to /root/mclk-check.py first"; exit 1; }
command -v i2ctransfer >/dev/null || { echo "need i2c-tools"; exit 1; }
to() { dmesg | grep -cE 'queue 0 timeout'; }

show() { python3 /root/mclk-check.py 2>/dev/null | grep -E 'cam_cc_cci'; python3 /root/mclk-check.py "$SDA" "$SCL"; }

N0=$(to)
echo "== idle: no traffic on bus $B"; show
( n=0; ok=0; nack=0; end=$((SECONDS + 25)); while [ $SECONDS -lt $end ]; do
    for a in $ADDRS; do r=$(i2ctransfer -f -y "$B" "w1@$a" 0x00 "r1@$a" 2>&1); n=$((n + 1))
      case "$r" in *"Remote I/O error"*) nack=$((nack + 1));; ?*) ok=$((ok + 1));; esac
    done
  done; echo "$n $ok $nack" > /tmp/cci-traffic-n ) &
TRAFFIC=$!
sleep 2
echo "== during traffic on bus $B (addresses $ADDRS)"; show
wait $TRAFFIC
set -- $(cat /tmp/cci-traffic-n)
echo "transfers attempted: $1, completed (read data or NACK-free): $2, NACKed: $3"
echo "queue-timeout lines added during the loop: $(( $(to) - N0 ))   # >0 means the bus never completed anything (unpowered/floating module), not 'no device'"
echo done
