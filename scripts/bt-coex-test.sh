#!/bin/bash
# One continuous 6 min test tone sequence to the Bluetooth sink (no restarts). Phase A 120 s idle Wi-Fi, phase B 150 s with 4 parallel 25 MB downloads in a loop.
U="sudo -u USER XDG_RUNTIME_DIR=/run/user/1001"
SINK=$($U pactl list short sinks | awk '/bluez_output/ {print $2; exit}')
python3 - <<PY
import wave, struct, math
sr=48000; w=wave.open("/tmp/coex-long.wav","wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
notes=[440,554,659,880,659,554]; frames=bytearray()
for rep in range(40):
    for f in notes:
        n=int(sr*0.25)
        for i in range(n):
            env=min(1,i/400)*min(1,(n-i)/400)
            v=int(9000*env*(math.sin(2*math.pi*f*i/sr)+0.4*math.sin(2*math.pi*2*f*i/sr)))
            frames += struct.pack("<hh", v, v)
for _ in range(6): w.writeframes(bytes(frames))
w.close()
PY
$U pactl set-sink-volume $SINK 75%
LOG=/root/coex4.out; : > $LOG
log() { echo "$(date +%T) $*" >> $LOG; }
rxb() { iw dev wlan0 station dump | awk '/rx bytes/ {print $3; exit}'; }
$U pw-play --target $SINK /tmp/coex-long.wav &
PLAY=$!
sleep 3
log "PHASE A start (music only) rx=$(rxb)"
for i in $(seq 1 12); do sleep 10; log "A rx=$(rxb)"; done
log "PHASE B start (music + wifi load) rx=$(rxb)"
rm -f /tmp/dl4-*.txt /tmp/coex-stop
( while [ ! -f /tmp/coex-stop ]; do for n in 1 2 3 4; do curl -s -o /dev/null -m 40 "https://speed.cloudflare.com/__down?bytes=25000000" -w "%{speed_download}\n" >> /tmp/dl4-$n.txt & done; wait; done ) &
r0=$(rxb)
for i in $(seq 1 15); do sleep 10; r1=$(rxb); log "B rx=$r1 rate=$(( (r1-r0)*8/10000000 )) Mbit/s wifi=$(iw dev wlan0 link | awk '/signal/ {print $2}')dBm retries=$(iw dev wlan0 station dump | awk '/tx retries/ {print $3}')"; r0=$r1; done
touch /tmp/coex-stop
log "PHASE B end"
sleep 8
kill $PLAY 2>/dev/null; pkill -u USER -f "pw-play --target"
log "done"
