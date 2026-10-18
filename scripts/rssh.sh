#!/usr/bin/env bash
# Root ssh to Arch on the U880 with the project key (alarm/ssh/id_ed25519). usage: rssh.sh '<cmd>'   (no args = shell)
# U880_HOST=<ip> to use Wi-Fi instead of the USB link (standalone boot has no USB gadget).
M=/home/USER/External/work/src/mainline
exec ssh -i $M/alarm/ssh/id_ed25519 -o UserKnownHostsFile=$M/alarm/known_hosts -o ConnectTimeout=8 root@${U880_HOST:-172.16.42.2} "$@"
