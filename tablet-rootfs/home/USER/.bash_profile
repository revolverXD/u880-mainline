if [ -e /home/USER/u880-test/weston.ini ]&& [ -e /home/USER/.u880-weston ] && [ "$(tty)" = /dev/tty1 ]; then exec /usr/bin/weston --config=/home/USER/u880-test/weston.ini --tty=/dev/tty1 >/home/USER/u880-test/weston.log 2>&1; fi
# U880: start Denial (mobile profile) on the console login. Scanout: the native msm card (has a DSI connector) if present,
# else simpledrm card0. Rendering: Adreno render node.
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
  # U880: wait (max 30 s) for the msm render node and the DSI connector; started too early the session exits at once
  # ("render device is not a character device") and the autologin getty hits its start limit.
  for i in $(seq 1 60); do
    [ -c /dev/dri/renderD128 ] && ls /sys/class/drm/card*-DSI-* >/dev/null 2>&1 && break
    sleep 0.5
  done
  # simpledrm card number varies (it waits for its interconnect vote); use its stable by-path link
  card=$(readlink -f /dev/dri/by-path/platform-e3940000.framebuffer-card 2>/dev/null || echo /dev/dri/card0)
  for c in /sys/class/drm/card*-DSI-*; do [ -e "$c" ] && card=/dev/dri/${c##*/}; card=${card%%-*}; break; done
  export DENIAL_SHELL_PROFILE=mobile DENIAL_DRM_DEVICE=$card DENIAL_RENDER_DEVICE=/dev/dri/renderD128
  # U880: wait (max 20 s) for the accelerometer (ADSP sensors core -> hexagonrpcd -> iio-sensor-proxy) so Denial
  # claims it at start and auto-rotates; continue without it if it never shows up.
  for i in $(seq 1 40); do
    busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer 2>/dev/null | grep -q true && break
    sleep 0.5
  done
  exec denial-session > "$HOME/.denial-session.log" 2>&1
fi
