# CLAUDE.md: rebuilding and maintaining the U880 mainline port

You are helping someone rebuild or extend a mainline Linux 7.4-rc4 (or the previous 7.3.1) + Arch Linux ARM + Plasma Mobile system for the **Alldocube iPlay 70 mini Ultra (U880, SM7675 "Cliffs")**.
Read `README.md` first (what works, repo map, the 10 build steps), then the header comment of the script you are about to run.
Open problems are listed in the tables of `README.md`.

## Rules that override everything else

1. **Ask the user before any action that wipes the tablet or writes a partition** (`dd` to `boot_a`/`boot_b`, formatting `userdata`, anything over EDL). Show the exact command, the target device and the backup you will take first.
2. **Never** use QFIL/EDL "Erase all before download", never write `abl`, `xbl`, `vendor_boot`, `dtbo` or `vbmeta` from Linux, never flash stock images one at a time in fastboot (the only exception is the `vbmeta`/`vbmeta_system` and `vbmeta_b`/`vbmeta_system_b` flashes of README step 1.6), never let the tablet take a stock OTA (firmware 3.0L.4+ adds ABL anti-tamper; the XDA thread reports an L.4 unlock with another ABL package, README step 0, untested here). Recovery is only the full-stock EDL XMLs.
3. Never commit, upload or print private keys, signing keys or passwords. The tablet SSH key is `alarm/ssh/id_ed25519` (git-ignored). Default image passwords `alarm`/`root` must be changed on a new install.
4. Vendor firmware, stock images, `abl.elf` unlock files and the Linux source tree are **not** in git (`.gitignore` is a whitelist). Do not add them.
5. Report outcomes truthfully: if a test fails or you skipped a step, say so with the output.

## Environment and paths

- Older scripts hard-code `M=/home/USER/External/work/src/mainline` and the AOSP pieces under `.../src/LineageOS/` (clang `prebuilts/clang/host/linux-x86/clang-r574158/`, `system/tools/mkbootimg`); newer ones find their own directory. If the repo is elsewhere, use the two `sed` lines of README "Paths" (mainline prefix first, then the `src` prefix) and put mkbootimg and clang under `$SRC/LineageOS/`.
- Kernel builds: on NixOS use `scripts/build-kernel-nix.sh` (README step 3 recipe B); the Ubuntu 24.04 distrobox `aosp` (README step 2) has no clang 21, so it needs the AOSP prebuilt clang r574158 under `$SRC/LineageOS/` (recipe A): `distrobox enter aosp -- bash scripts/<script>.sh`. Host tools needed outside it: `dtc`, `fastboot` and `adb` (android-tools), `e2fsprogs`, `mtools`, `unzip`, `libarchive` (bsdtar), `cpio`, `python3` and `bkerler/edl` (README step 2).
- Reaching the tablet: Wi-Fi (`U880_HOST=<ip> scripts/rssh.sh '<cmd>'`, root, project key) or the USB gadget (`172.16.42.2`, PC side `172.16.42.1/24`). The gadget interface name on the PC changes between boots; the
  NetworkManager profile `u880-usb` must have an empty `connection.interface-name` **and** `match.interface-name enp*u*` (`nmcli connection modify u880-usb connection.interface-name "" match.interface-name 'enp*u*'`): without the match it is a `shared` profile for any ethernet device and takes over the PC's wired NIC, serving DHCP onto the LAN. IPv6 link-local ssh works too: `ssh root@fe80::<tablet>%<iface>`.
  The USB link does not survive suspend; after a reboot it needs the cable plugged in the PC's USB port, not behind a hub or with a hub/dongle on the tablet port.
- Do not run `btmgmt` subcommands that wait for input over ssh (it hangs); use `timeout`. Do not `pkill -f <pattern>` with a pattern that appears in your own command line.

## Rebuild recipes (details in README)

- **Kernel** (README step 3 has both recipes): 7.4-rc4 = pristine `linux-7.4-rc4.tar.gz` + `kernel/u880-kernel-delta-7.4.patch` + `kernel/u880-7.4.config` (release `7.4.0-rc4-u880e`, the current one); 7.3.1 = pristine `linux-7.3.1.tar.xz` + `kernel/u880-kernel-delta.patch` + `kernel/u880_defconfig`, `LOCALVERSION=-u880e` **always pinned** (since 2026-10-29; a different release makes every module and the initramfs UFS modules refuse to load; the display never probes). Options that change `struct module` (e.g. `KPROBES`) need a NEW release name and a separate `/usr/lib/modules/<release>` directory, or no installed module loads. Build `Image Image.gz modules` (`scripts/make-boot-image.sh` packs `Image.gz` by default; the uncompressed `Image` boots as well).
  `scripts/clean-rebuild.sh` proves the delta is complete.
- **After editing anything under the kernel tree** regenerate the delta, or the change is not in git: 7.3.1: `python3 scripts/snapshot-kernel-delta.py <pristine linux-7.3.1> linux-7.3.1` and commit `kernel/u880-kernel-delta.patch`; 7.4-rc4: `SUFFIX=-7.4 python3 scripts/snapshot-kernel-delta.py <pristine linux-7.4-rc4> linux-7.4-rc4` and commit `kernel/u880-kernel-delta-7.4.patch` + `kernel/u880-7.4.config`.
  Built-in code (msm DRM, clk, genpd, pmdomain) needs a new boot image; modules (`dispcc-sm8550.ko`, `pm8xxx-vibrator.ko`, ...) are copied to `/usr/lib/modules/<release>/` + `depmod` and need only a reboot.
- **DTB**: `dts/u880.dts` -> `dtc -I dts -O dtb`; check the roundtrip with `dtc -I dtb -O dts` before flashing (a thermal change was verified as "1011 lines added, none changed").
- **Boot image**: kernel `Image.gz` (or the uncompressed `Image`, both boot) + initramfs (with `lib/modules-ufs/{qcom_ice,phy-qcom-qmp-ufs,ufs-qcom}.ko` of the **same** build) + DTB + the cmdline in `scripts/make-boot-image.sh`; header v2, offsets as in README step 6.
  To change only the DTB or kernel of the installed image, unpack it with `unpack_bootimg.py --format=mkbootimg` and repack with the same parameters.
- **Flash**: back up the target slot, `dd` the image to `boot_b` (`/dev/sde40` on the reference tablet: confirm with `/dev/disk/by-partlabel/`), `blockdev --setrw` first and `--setro` after, verify the sha256 of the written bytes, then reboot. If you `set_active`, rerun `scripts/gpt-mark-successful.py`. `boot_a` is flagged unbootable, so a bad image needs the USB cable and a PC.
- **Userspace**: edit the mirror in `tablet-rootfs/` and push with `scripts/tablet-config.sh push`; `status` shows drift, `pull` captures the tablet into the mirror. Keep `tablet-rootfs/` and the tablet in sync, and commit both effects.

## Verification checklist after a kernel or DT change

`uname -r` = `7.4.0-rc4-u880e` (or `7.3.1-u880e` on the old build); `/sys/class/drm/card1-DSI-1` exists; `dmesg | grep "UBWC programmed"` = `STATIC=0x103e CTRL_2=0x2 PRED=0x1`; scanout modifier in `/sys/kernel/debug/dri/1/state` is `0x500000000000001` (needs debugfs: production images boot with `debugfs=off` and have no `/dev/mem`, so flash a `DEV=1 scripts/make-boot-image.sh` image for this check and for the debugfs/regdump scripts and flash the production image back afterwards (there is no RAM boot)) and the picture is crisp (photograph it, see below);
four modes in `modetest -M msm -p`; `scripts/dpms-fuzz.sh 100 200 4000` clean; thermal zones have trips and `cdev` (`ls /sys/class/thermal/thermal_zone*/`); `bluetoothctl show` prints the tablet's own factory address (not `00:00:00:00:00:00`) and `btmgmt info` lists `connectable`; sensors and audio sinks present; no `stuck at`/`frame done timeout`/`gpu fault` bursts in `dmesg`.
Judge the display with a **camera**, not only screenshots: compositor screenshots can be clean while the panel shows corruption (`scripts/cam.sh`).

## Pitfalls that cost days (do not re-learn them)

- **LOCALVERSION** pinned. The initramfs UFS modules must match the kernel release or boot hangs at a blue screen with no network.
- **Build the kernel from the committed config** (`kernel/u880-7.4.config`, or `kernel/u880.config`, the full .config that `u880_defconfig` yields, for 7.3.1) (2026-11-23): a leftover `.config` with `CONFIG_DEVMEM=y` from a debug build ended up in a flashed Image (found by `ls /dev/mem` on the tablet). Before flashing: `grep DEVMEM <kernel tree>/.config` must say `# CONFIG_DEVMEM is not set`.
- **Never hand-pack a boot image** (cost an evening, 2026-11-02): a hand-typed `mkbootimg` command silently carried a made-up `arm-smmu.disable-smmu=0` instead of `arm-smmu.disable_bypass=0`, and the tablet boot-looped at the vendor logo with no log anywhere. Build with `scripts/make-boot-image.sh`, and before flashing, diff the built image's 4096-byte header against the installed one (`unpack_bootimg.py` or a byte compare) and expect only the size fields, the id hash and the ramdisk to differ.
- **The fastboot the key combo gives is XBL's**: `boot`/`flash`/`erase`/`setvar` are all refused, so a bad boot cannot be repaired by RAM-booting a rescue image. Slot getvars work, and GPT A/B attributes can be read and written over EDL; the reference unit has **no `misc` partition** after our repartitioning (the stock GPT has a 1 MiB `misc` on LUN 0, so a stranger's tablet has one) and its `uefivarstore`/`xbl_sc_logs` are empty, so a cold failed boot leaves no record except the host's `journalctl -k`.
- **Take every EDL sector from the GPT, not from notes** (cost a week, 2026-11-02): `boot_b` is LBA 454422, a write at 454673 overflowed into `vbmeta_b`/`dtbo_b` and the tablet stopped booting. `edl setactiveslot` is broken here: use `scripts/u880-ab.py` and `edl setbootablestoragedrive 1|2`.
- **`/dev/mem` and debugfs are off in production.** The kernel has `CONFIG_DEVMEM=n` and the production boot image carries `debugfs=off`. The debugfs scripts (`disp-test.sh`, `dpms-grim.sh`, `sleepstat.sh`, `genpd-cycle.sh`, ...) work on the same kernel with an image built by `DEV=1 scripts/make-boot-image.sh` (flash it only for the measurement, with the production image and a backup at hand; there is no RAM boot). `reg-rw.py` and `regdump-mem.py` also need `/dev/mem`: build a kernel with `kernel/dev-devmem.config` merged (`DEVMEM=y`) and flash that only for the measurement.
- **Never read the display PP/DSC blocks or the DISPCC block through `/dev/mem` or regmap debugfs while unclocked/unpowered**: it resets the SoC. Reading `MDSS` UBWC registers (`0xae00144`...) while the display is up is fine; **writing** them live breaks the picture.
- **Display wedge** (`mdss_gdsc status stuck at`) is fixed (2026-11-23): MMCX proxy vote around the GDSC toggles in `u880_mdss_pd_on/off` (dispcc module) + 500 ms autosuspend in `msm_mdss`; the always-on udev rule is gone. `scripts/dpms-fuzz.sh 300` must stay clean; re-test it after any dispcc/msm_mdss change, and the UBWC programming still depends on the runtime resume path.
- **Garbled fine detail only on the panel** = UBWC decoder registers not programmed; `FD_MESA_DEBUG=noubwc` is the emergency workaround.
- **Session restarts**: `loginctl terminate-user` + `systemctl restart getty@tty1` races with the autologin respawn and leaves KWin with zero screens. Reboot instead.
- **Bluetooth**: the controller comes up unconfigured: `u880-bt-addr.service` sets the factory address from `persist/nv/macbt` (read-only mount) and `u880-bt-connectable.service` turns page scan on. Changing the address means re-pairing every device. `Experimental`/`KernelExperimental` in `/etc/bluetooth/main.conf` are set for LE Audio.
- **Wi-Fi off/on from the desktop menu or `rfkill`/`remoteproc` fiddling can leave `wlan0` missing until reboot.** Never stop `remoteproc0` by hand.
- **Thermal**: the die heats 2.5-5 C/s. The DT cooling maps and `u880-thermal-guard` must both stay; do not load-test without them.
- **Audio**: do not put a DisplayPort PCM in the same UCM verb as the speakers (the profile is dropped when it fails to open). WirePlumber remembers a saved `pro-audio` profile in `~/.local/state/wireplumber/`.
- **Android caches BLE GATT tables**: refresh/forget the device in nRF Connect after changing a GATT server. Do not loop a fixed-length audio file with repeated player runs when measuring dropouts (each restart is a gap).
- **Forgetting `SUFFIX=-7.4` overwrites the 7.3.1 files** (2026-11-27): the snapshot script without it wrote the 7.4 tree into `kernel/u880-kernel-delta.patch` and `kernel/u880.config`, while the real 7.4 delta missed the camera, video, CDSP, touch and GPU changes. Check after every snapshot: `git diff --stat kernel/` must touch only the `-7.4` files and `head -3 kernel/u880.config` of the old file must still say `7.3.1`. A release with the same name (`7.4.0-rc4-u880e`) can hold very different kernels: the delta, not the name, says which.
- **Never start a camera with the screen off**: the RPMh `MM0` vote times out and `apps_rsc` wedges until a forced reboot.
- **Git does not keep empty directories**: the initramfs needs `dev proc sys newroot tmp`, which `scripts/build-initramfs.sh` creates; a ramdisk packed by hand from a fresh clone cannot boot (found by the third cold-read test, 2026-11-26). Whenever a build uses a directory tree from git, check what an empty directory would break.
- **Steam shader pre-caching** replays about 1 M pipelines (hours, all cores): turn it off in Steam settings.

## Style of work in this repo

- Small commits, each explaining the why. Say in the commit message what you did, the evidence, and what you did not test; keep a command that re-proves each fact you rely on.
- Measure before claiming; keep raw logs out of git (`logs/` is ignored): they carry timestamps, hardware names and addresses. Say what you did not test.
- There is no RAM boot: prefer reversible changes, test modules before boot images; keep the previous boot image and module files in `/root/u880-backup/` on the tablet.

## Fresh install on a new tablet (what an agent must know)

- Follow `README.md` steps 0 to 10; the tested route is 7b (USB Ethernet through the PC), 8a (root image built on the PC, written to an SD card on the PC) and 8b (first boot, `pacman -Syu`, **reboot**, then the package set). Nothing can be formatted or unpacked on the tablet before Linux runs: the rescue initramfs is dead on 7.3/7.4 (no USB/display modules, no `mkfs`, no GNU `tar`).
- Never flash a boot image that drops `u880root=` (rescue) unless the initramfs carries the USB/display modules: it ends in a black screen with no USB, and only EDL (README step 0, `boot_b` at the LBA from the GPT) repairs it. Use `u880root=sd,ufs` so that a failed card falls back to the internal root.
- Keep the initramfs fast: any wait before the root mount longer than a few seconds makes the display driver miss `dispcc` (black screen, system otherwise fine).
- The tablet has no RTC: set the date from the PC before `pacman` (`date -s @$(date +%s)`). Use a separate `known_hosts` for a re-installed system.
- After `pacman -Syu` replaces `systemd`, ssh sessions break until reboot: reboot only when `pgrep pacman` is empty and the post-transaction hooks are done, never in the middle (stale `db.lck`).
- Cards: write them on the PC. A card that fails SDR104 tuning (`tuning execution failed: -110`) needs `sdhci-caps-mask <0x3 0x0>` in the DTB (applies to every card). Do not kill a `dd` to a stuck card: it sits in state D until the card or the host goes away.
- Games: `steam/INSTALL.md` (native ARM64 Steam, launchers, extra Proton builds); Easy Anti-Cheat titles did not start on Proton Experimental (ARM64) and a gamescope WSI layer message is open (that file, section 3 and 4).
