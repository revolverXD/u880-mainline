#!/usr/bin/env bash
# ssh to Arch on the U880 as alarm (password auth, tablet-only known_hosts). usage: tssh.sh '<cmd>'
M=/home/USER/External/work/src/mainline
exec nix-shell -p sshpass openssh --run "sshpass -p alarm ssh -o UserKnownHostsFile=$M/alarm/known_hosts -o ConnectTimeout=8 alarm@172.16.42.2 $(printf '%q' "$1")" 2>&1
