#!/usr/bin/env bash
# Wi-Fi throughput of the tablet, driven FROM THE PC (the PC's firewall blocks the tablet from connecting to it, so the iperf3 server runs on the tablet).
#   U880_HOST=<tablet ip> scripts/bench-wifi.sh
# Both radios share the medium: the PC's own Wi-Fi limits the result as much as the tablet's.
set -e
H=${U880_HOST:?set U880_HOST to the tablet Wi-Fi address}
M=$(cd "$(dirname "$0")/.." && pwd)
ssh() { command ssh -i "$M/alarm/ssh/id_ed25519" -o StrictHostKeyChecking=no "root@$H" "$@"; }
for dir in "PC -> tablet" "tablet -> PC"; do
  ssh 'pkill -x iperf3; iperf3 -s -1 -D' ; sleep 1
  [ "$dir" = "tablet -> PC" ] && R=-R || R=
  v=$(nix-shell -p iperf3 --run "iperf3 -c $H -t 10 -f m $R" 2>&1 | awk '/receiver/{for(i=1;i<=NF;i++) if($i=="Mbits/sec") v=$(i-1)} END{print v}')
  echo "$dir: $v Mbit/s"
done
echo "tablet power_save: $(ssh 'iw dev wlan0 get power_save' | awk '{print $NF}'), link: $(ssh 'iw dev wlan0 link' | awk '/signal|tx bitrate/{printf "%s ", $0}' | tr -s ' \t' ' ')"
echo "ping: $(ping -c 20 -i 0.2 -q $H | awk -F/ '/rtt/{print "avg " $5 " ms, max " $6 " ms"}')"
