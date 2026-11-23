#!/bin/bash
# #13: which userspace client keeps the ADSP (and with it AOSD/CXSD/DDR) awake in s2idle? Runs ON the tablet (DEV image: needs debugfs qcom_stats),
# one 40 s s2idle per variant with sleepstat.sh, services stopped only for that variant and started again after. Never stops a remoteproc.
# usage (detached): setsid nohup bash /root/adsp-sleep-variants.sh >/root/adsp-variants.out 2>&1 &
U="runuser -u USER -- env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus"
SENS="iio-sensor-proxy hexagonrpcd-adsp-sensorspd"
AUD="pipewire-pulse.socket pipewire.socket pipewire-pulse pipewire wireplumber"
stop_s() { systemctl stop $SENS; }; start_s() { systemctl start hexagonrpcd-adsp-sensorspd iio-sensor-proxy; }
stop_a() { $U systemctl --user stop $AUD; }; start_a() { $U systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber; }
stop_b() { systemctl stop bluetooth; }; start_b() { systemctl start bluetooth; }
run() { # name stop-fns...
  n=$1; shift; for f in "$@"; do $f; done; sleep 3
  rm -f /root/adsp-$n.log; /root/sleepstat.sh 40 /root/adsp-$n.log
  echo "== $n: $(grep -E '^(aosd|cxsd|ddr|apss|adsp|wpss):' /root/adsp-$n.log | tr '\n' ' ')"
  for f in "$@"; do ${f/stop_/start_}; done; sleep 8
}
run base
run sensors stop_s
run audio stop_a
run bt stop_b
run all stop_s stop_a stop_b
echo ALLDONE
