# CLAUDE.md: rebuilding and maintaining the U880 mainline port

You are helping someone rebuild or extend a mainline Linux 7.2.9 + Arch Linux ARM + Plasma Mobile system for the **Alldocube iPlay 70 mini Ultra (U880, SM7675 "Cliffs")**.
Read `README.md` first (what works, repo map, the 10 build steps), then `FINDINGS.md` (verified facts, one per topic), then search `NOTES.md` (chronological log, 2600+ lines) with `grep` for the area you touch.
Open problems are the GitHub issues of this repository.

## Rules that override everything else

1. **Ask the user before any action that wipes the tablet or writes a partition** (`dd` to `boot_a`/`boot_b`, formatting `userdata`, anything over EDL). Show the exact command, the target device and the backup you will take first.
2. **Never** use QFIL/EDL "Erase all before download", never write `abl`, `xbl`, `vendor_boot`, `dtbo` or `vbmeta` from Linux, never flash stock images one at a time in fastboot, never let the tablet take a stock OTA (firmware 3.0L.4+ adds ABL anti-tamper). Recovery is only the full-stock EDL XMLs.
3. Never commit, upload or print private keys, signing keys or passwords. The tablet SSH key is `alarm/ssh/id_ed25519` (git-ignored). Default image passwords `alarm`/`root` must be changed on a new install.
4. Vendor firmware, stock images, `abl.elf` unlock files and the Linux source tree are **not** in git (`.gitignore` is a whitelist). Do not add them.
5. Report outcomes truthfully: if a test fails or you skipped a step, say so with the output.

## Environment and paths

- The scripts hard-code `M=/home/USER/External/work/src/mainline` and the Android clang under `.../LineageOS/prebuilts/clang/host/linux-x86/clang-r574158/`. If the repo is elsewhere, rewrite once:
  `grep -rIl '/home/USER/External/work/src/mainline' scripts tools tablet-rootfs steam | xargs sed -i "s#/home/USER/External/work/src/mainline#$PWD#g"` and fix `CL=` and the `mkbootimg.py` path.
- Kernel builds run in an Ubuntu 24.04 distrobox called `aosp` (recipe in `README.md` step 2): `distrobox enter aosp -- bash scripts/<script>.sh`. Host tools needed outside it: `dtc`, `fastboot`, `e2fsprogs`, `cpio`, `python3`.
- Reaching the tablet: Wi-Fi (`U880_HOST=<ip> scripts/rssh.sh '<cmd>'`, root, project key) or the USB gadget (`172.16.42.2`, PC side `172.16.42.1/24`). The gadget interface name on the PC changes between boots; the
  NetworkManager profile `u880-usb` must have an empty `connection.interface-name` (`nmcli connection modify u880-usb connection.interface-name ""`). IPv6 link-local ssh works too: `ssh root@fe80::<tablet>%<iface>`.
  The USB link does not survive suspend; after a reboot it needs the cable plugged in the PC's USB port, not behind a hub or with a hub/dongle on the tablet port.
- Do not run `btmgmt` subcommands that wait for input over ssh (it hangs); use `timeout`. Do not `pkill -f <pattern>` with a pattern that appears in your own command line.

## Rebuild recipes (details in README)

- **Kernel**: pristine `linux-7.2.9.tar.xz` + `kernel/u880-kernel-delta.patch` + `kernel/u880_defconfig`, `LOCALVERSION=-u880e` **always pinned** (since 2026-10-29; a different release makes every module and the initramfs UFS modules refuse to load; the display never probes: FINDINGS F7). Options that change `struct module` (e.g. `KPROBES`) need a NEW release name and a separate `/usr/lib/modules/<release>` directory, or no installed module loads (NOTES 2026-10-29 late). Build `Image.gz modules`.
  `scripts/clean-rebuild.sh` proves the delta is complete.
- **After editing anything under `linux-7.2.9/`** regenerate the delta, or the change is not in git: `python3 scripts/snapshot-kernel-delta.py <pristine linux-7.2.9> linux-7.2.9` and commit `kernel/u880-kernel-delta.patch`.
  Built-in code (msm DRM, clk, genpd, pmdomain) needs a new boot image; modules (`dispcc-sm8550.ko`, `pm8xxx-vibrator.ko`, ...) are copied to `/usr/lib/modules/7.2.9-u880e/` + `depmod` and need only a reboot.
- **DTB**: `dts/u880.dts` -> `dtc -I dts -O dtb`; check the roundtrip with `dtc -I dtb -O dts` before flashing (a thermal change was verified as "1011 lines added, none changed").
- **Boot image**: kernel `Image.gz` + initramfs (with `lib/modules-ufs/{qcom_ice,phy-qcom-qmp-ufs,ufs-qcom}.ko` of the **same** build) + DTB + the cmdline in `scripts/make-boot-image.sh`; header v2, offsets as in README step 6.
  To change only the DTB or kernel of the installed image, unpack it with `unpack_bootimg.py --format=mkbootimg` and repack with the same parameters.
- **Flash**: back up the target slot, `dd` the image to `boot_b` (`/dev/sde40` on the reference tablet: confirm with `/dev/disk/by-partlabel/`), `blockdev --setrw` first and `--setro` after, verify the sha256 of the written bytes, then reboot. If you `set_active`, rerun `scripts/gpt-mark-successful.py`. `boot_a` is flagged unbootable, so a bad image needs the USB cable and a PC.
- **Userspace**: edit the mirror in `tablet-rootfs/` and push with `scripts/tablet-config.sh push`; `status` shows drift, `pull` captures the tablet into the mirror. Keep `tablet-rootfs/` and the tablet in sync, and commit both effects.

## Verification checklist after a kernel or DT change

`uname -r` = `7.2.9-u880e`; `/sys/class/drm/card1-DSI-1` exists; `dmesg | grep "UBWC programmed"` = `STATIC=0x103e CTRL_2=0x2 PRED=0x1`; scanout modifier in `/sys/kernel/debug/dri/1/state` is `0x500000000000001` and the picture is crisp (photograph it, see below);
four modes in `modetest -M msm -p`; `scripts/dpms-fuzz.sh 100 200 4000` clean; thermal zones have trips and `cdev` (`ls /sys/class/thermal/thermal_zone*/`); `bluetoothctl show` address `00:11:22:33:44:55`-style factory address and `btmgmt info` lists `connectable`; sensors and audio sinks present; no `stuck at`/`frame done timeout`/`gpu fault` bursts in `dmesg`.
Judge the display with a **camera**, not only screenshots: compositor screenshots can be clean while the panel shows corruption (`scripts/cam.sh`).

## Pitfalls that cost days (do not re-learn them)

- **LOCALVERSION** pinned (F7). The initramfs UFS modules must match the kernel release or boot hangs at a blue screen with no network.
- **Never read the display PP/DSC blocks or the DISPCC block through `/dev/mem` or regmap debugfs while unclocked/unpowered**: it resets the SoC (F8). Reading `MDSS` UBWC registers (`0xae00144`...) while the display is up is fine; **writing** them live breaks the picture.
- **Display wedge** (`mdss_gdsc status stuck at`): worked around by `/etc/udev/rules.d/90-u880-display-pm.rules` (`power/control=on`). That workaround is why UBWC registers are programmed at the end of the MDSS handoff (commit `msm_mdss: program UBWC...`). Do not remove one without re-testing both (FINDINGS F19/F20).
- **Garbled fine detail only on the panel** = UBWC decoder registers not programmed; `FD_MESA_DEBUG=noubwc` is the emergency workaround.
- **Session restarts**: `loginctl terminate-user` + `systemctl restart getty@tty1` races with the autologin respawn and leaves KWin with zero screens. Reboot instead.
- **Bluetooth**: the controller comes up unconfigured: `u880-bt-addr.service` sets the factory address from `persist/nv/macbt` (read-only mount) and `u880-bt-connectable.service` turns page scan on. Changing the address means re-pairing every device. `Experimental`/`KernelExperimental` in `/etc/bluetooth/main.conf` are set for LE Audio.
- **Wi-Fi off/on from the desktop menu or `rfkill`/`remoteproc` fiddling can leave `wlan0` missing until reboot.** Never stop `remoteproc0` by hand.
- **Thermal**: the die heats 2.5-5 C/s. The DT cooling maps and `u880-thermal-guard` must both stay; do not load-test without them.
- **Audio**: do not put a DisplayPort PCM in the same UCM verb as the speakers (the profile is dropped when it fails to open). WirePlumber remembers a saved `pro-audio` profile in `~/.local/state/wireplumber/`.
- **Android caches BLE GATT tables**: refresh/forget the device in nRF Connect after changing a GATT server. Do not loop a fixed-length audio file with repeated player runs when measuring dropouts (each restart is a gap).
- **Steam shader pre-caching** replays about 1 M pipelines (hours, all cores): turn it off in Steam settings.

## Style of work in this repo

- Small commits, each explaining the why; update `NOTES.md` (dated entry) for what you did and `FINDINGS.md` for facts that stay true across a kernel upgrade (status + evidence + a command that re-proves it).
- Measure before claiming: keep logs under `tools/profiles/` (tracked) or `logs/` (ignored). Say what you did not test.
- Prefer RAM boot tests and reversible changes; keep the previous boot image and module files in `/root/u880-backup/` on the tablet.
