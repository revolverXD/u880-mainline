# Mainline Linux + Plasma Mobile on the Alldocube iPlay 70 mini Ultra (U880)

A mainline Linux 7.3.1 port for one tablet: **Alldocube iPlay 70 mini Ultra, Global model, codename U880**
(Qualcomm Snapdragon 7+ Gen 3, SM7675 "Cliffs", 12 GB RAM, UFS 3.1, 8.8" 1600x2560 144 Hz panel). It runs Arch Linux ARM with
KDE Plasma Mobile (and the Denial shell), native ARM64 Steam and Proton, with the GPU, display, touch, Wi-Fi, Bluetooth,
audio, sensors, USB-C (host, DisplayPort, PD), battery and thermal control working.
Android was removed from the internal storage; Linux boots from the internal UFS.

This repository is everything needed to rebuild that system **for the same tablet**, plus the notes that explain why each piece exists.
It does **not** contain the Linux source tree, vendor firmware or any keys (see [What is not in this repo](#what-is-not-in-this-repo)).

> **Read this first.** This is a hobby port done on one unit. Unlocking the bootloader of this model needs a modified ABL written over
> Qualcomm EDL, and some actions on this model have bricked it (see [Safety rules](#safety-rules)). A step-by-step run from an empty
> machine has **not** been done end to end; the pieces below were each verified (see [How much of this is verified](#how-much-of-this-is-verified)).
> Do it on a tablet you can afford to lose.

## What works

Tested on kernel `7.3.1-u880e`, boot slot B, Plasma Mobile 6.8.

| Area | Status |
|---|---|
| CPU, cpufreq, cpuidle, thermal (DT cooling maps + userspace guard) | works |
| GPU Adreno 735 (msm DRM, Mesa freedreno/turnip, GL 4.6, Vulkan 1.4) | works (non-fatal page-fault messages in games, issue #2) |
| Display: native DPU + dual DSI, DSC, UBWC, 144/120/90/60 Hz, DPMS, backlight, auto-brightness | works (the MDSS power-domain wedge is fixed, issue #1; touch reports are best at 144 Hz) |
| Touch (Novatek NT36523N, 10 points) | works; the IC publishes only ~31-47 frames/s and about 1 in 5 light taps is lost (IC firmware, FINDINGS/NOTES 2026-11-24) |
| Wi-Fi 6 (ath11k WCN6750) | works |
| Bluetooth 5.4 (A2DP incl. LDAC, HID, BLE central and peripheral, factory address) | works; LE Audio untested |
| Audio: 2 speakers (AW88261), DisplayPort audio, PipeWire | works; microphones missing (issue #3) |
| Sensors: accelerometer, ambient light, gyroscope, compass via ADSP | works |
| USB-C: host, USB 3 SuperSpeed, DisplayPort alt mode, PD charging, gadget for ssh | works |
| Battery gauge and charging (via ADSP, PMIC GLINK) | works |
| Suspend: s2idle (power key), deep suspend | works (about 0.5-0.7 W asleep; SoC deep states not reached, issue #13) |
| Vibration motor | works (no haptics service yet) |
| Steam ARM64 + Proton Experimental ARM64 (games run) | works |
| Cameras | **not working** (no Cliffs CAMSS, issue #4) |
| Microphones | **not working** (no capture path, issue #3) |
| Fingerprint, NFC, SIM, GNSS | not present or not stated on this model |

Open work is tracked in the GitHub issues; the full engineering log is `NOTES.md`, the durable verified facts are `FINDINGS.md`.

## Performance (measured on the reference tablet)

Kernel 7.3.1-u880e, Mesa 26.3.1, on battery, cooler fitted, `scripts/bench.sh` (full output and raw logs in `tools/profiles/20261125-bench-7.3.1-baseline/`):

| Test | Result |
|---|---|
| GPU, glmark2 (Wayland, default scenes) | **1204** (Adreno 735 / "FD735", Turnip/freedreno, Mesa 26.3.1) |
| CPU, 1 thread, prime core (Cortex-X4 class, up to 2.8 GHz) | 45.2 stress-ng matrixprod bogo ops/s; OpenSSL AES-256-CBC 1.58 GB/s, SHA-256 1.04 GB/s |
| CPU, 1 thread, little core (1.9 GHz) | 18.9 matrixprod bogo ops/s (prime core is 2.4x faster) |
| CPU, all 8 cores, 60 s | 303.8 matrixprod bogo ops/s; OpenSSL AES-256-CBC 8.8 GB/s, SHA-256 11.7 GB/s; SoC at 78 C at the end of 60 s with the cooler |
| Memory | 1257 memcpy bogo ops/s (8 workers) |
| Storage (UFS, ext4, direct I/O) | 986 MB/s sequential write, 1.2 GB/s sequential read, 6478 random 4 KiB reads/s at queue depth 1 |
| Wi-Fi (Wi-Fi 6, 5 GHz, 80 MHz, 2x2) | 182 Mbit/s PC to tablet, 170 Mbit/s tablet to PC (the PC's own Wi-Fi is the limit; tablet link 576 Mbit/s at -74 dBm) |
| Games | Borderlands 2 (32-bit DX9 game, Proton Experimental ARM64): 40-60 FPS on the DXVK HUD at 1024x768 with effects reduced (FXAA, ambient occlusion, bloom, depth of field and motion blur off, detail mode 2); about 47 min of play without an out-of-memory kill, with zram (`NOTES.md` 2026-11-25) |

These are bogo-op and synthetic numbers meant for before/after comparisons on this tablet, not cross-device rankings. Repeat runs of the same test were within a few percent (single-thread 44.9 vs 45.2, glmark2 1159 vs 1204).

## Hardware and firmware this was built for

- Tablet: iPlay 70 mini Ultra **Global**, board `U880`, stock firmware **`U880_B14_V3.0L.1_0311`**. Newer stock firmware (3.0L.4, 2026-03) adds ABL
  anti-tamper and the unlock method below fails on it. **Never let the tablet take a stock OTA.**
- SoC `qcom,cliffs` (SM7675, soc_id 643); the downstream platform is the `pineapple` (SM8650) family.
- Boot chain: Qualcomm ABL (Android bootloader), A/B slots, Virtual A/B, boot header v2.
- The kernel base and many drivers come from the [senemos-uke-kernel-mainline](https://github.com/MCC45TR/senemos-uke-kernel-mainline) series (MIT) for
  the Xiaomi Pad 7 / POCO Pad X1, which has the same SoC. Our delta on top of vanilla Linux 7.3.1 is `kernel/u880-kernel-delta.patch`.

## Repository map

| Path | What |
|---|---|
| `kernel/` | `u880-kernel-delta.patch` (every source change vs vanilla 7.3.1), `u880_defconfig`, `u880.config` |
| `dts/u880.dts` | the production device tree as one source file (decompiled from the working DTB, plus our additions) |
| `stage1/*.dtso`, `stage1/initramfs/` | DT overlays used while bringing the board up; the rescue/boot initramfs source (busybox, `init`) |
| `stock-dt/` | parsers for the device trees in the stock firmware (`dtbo.py`, `vb.py`). The decompiled vendor trees (`dtb2` = SoC DT, `o25` = board overlay) are **not published**: regenerate them from your own `vendor_boot`/`dtbo` |
| `topology/`, `ucm/` | AudioReach topology source and ALSA UCM profiles (speakers `HiFi`, DisplayPort `HDMI`) |
| `tablet-rootfs/` | mirror of every file on the tablet's root filesystem that we changed (units, udev rules, configs, scripts); pushed with `scripts/tablet-config.sh` |
| `power/`, `usb/`, `sensors/` | extra tablet config grouped by area, with their own notes |
| `steam/` | native ARM64 Steam, gamescope and Proton recipe and launchers (`README-arm64.md`) |
| `scripts/` | build, flash, test and measurement scripts (each starts with a comment explaining it) |
| `tools/` | small helpers: BLE test server, audio dropout analyser, rumble tool, profiles of test runs |
| `NOTES.md`, `FINDINGS.md` | engineering log; durable facts with status and a reproduce command each |

**Paths:** the scripts were written for the repo living at `/home/USER/External/work/src/mainline` and the Android clang in
`/home/USER/External/work/src/LineageOS/prebuilts/...`. On another machine either clone to those paths or rewrite them once:

```
grep -rIl '/home/USER/External/work/src/mainline' scripts tools tablet-rootfs steam | xargs sed -i "s#/home/USER/External/work/src/mainline#$PWD#g"
# then point CL= (clang) and the mkbootimg.py path in scripts/*.sh at your own copies
```

## Safety rules

These come from mistakes and a brick on this exact model:

1. **Never use QFIL/EDL "Erase all before download".** It has bricked this model.
2. Never write `abl`, `xbl`, `vendor_boot`, `dtbo` or `vbmeta` from Linux. Only `boot_a`/`boot_b` are written by the scripts here.
3. Never flash stock images one partition at a time in fastboot; use the EDL XMLs of the full stock firmware for recovery.
4. Keep the original ABL: `abl_a`/`abl_b` backups are the only copies of the original Global ABL.
5. Back up everything you can read before touching anything (`persist`, `modemst*`, `fsg`, `devinfo`, the GPT of every LUN).
6. Boot images are tested with `fastboot boot` (RAM only) where possible; a bad image written to the active slot needs the USB cable and a PC to recover.
7. This project removed Android's userdata (`sda11` is now the Linux root). There is no going back without a factory reset and the stock images.

## How to recreate the system

You need: a Linux PC, the tablet on stock firmware `U880_B14_V3.0L.1_0311` (stock images for EDL recovery), a USB-C cable, about 100 GB of disk and several hours
for the first kernel build. The steps are in the order they were done; each says where the details are.
**Reading this as an LLM agent:** start with `CLAUDE.md` (the rules that override everything), then do steps 0 to 10 in order; steps 7b, 8a and 8b are the route that was actually run end to end, with the errors you will see and what they mean. Every flash or format needs the user's explicit go, with the exact command, the target device and the backup shown first.

### 0. Back up and get recovery material

Download the full stock `U880_B14_V3.0L.1_0311` firmware (EDL "flat build": `rawprogram*.xml`, `patch0.xml`, `prog_firehose_ddr.elf`). Read every partition you can
with `bkerler/edl` (`edl rl`). Keep a copy of the stock `boot_a`, `abl_a`, `abl_b`. Recovery recipe if the system does not boot and fastboot is gone: enter EDL (`adb reboot edl`, or power off, hold Vol+ Vol- Power, release at the brief logo flash and plug in),
then flash the full stock firmware with `rawprogram_all.xml` + `patch0.xml` and `prog_firehose_ddr.elf`, memory type UFS (`bkerler/edl` on Linux, QPST/QFIL or `QSaharaServer` + `fh_loader` on Windows).
That XML leaves `persist`, `modemst*`, `fsg`, `devinfo`, `frp` and all `_b` partitions alone. Afterwards redo the unlock below. **Never tick "Erase all before download".**
If only the system fails to boot but fastboot works, reflash a known-good boot image to the slot (README step 9).

### 1. Unlock the bootloader (model specific, risky)

The Global ABL refuses `fastboot flashing unlock`. The method used here (from an XDA guide for this model): write a modified Chinese-model `abl.elf` to
`abl_a` only over EDL (`rawprogram` for LUN 4, start sector 95238, 256 sectors of 4096 B), then run `fastboot flashing unlock` (this wipes the tablet).
The Chinese `abl.elf` and the unlock `rawprogram` XML are **not** in this repo; follow the XDA thread for your firmware. Verify afterwards that `fastboot` works and
`androidboot.verifiedbootstate=orange`.

### 2. Build environment

The project host is NixOS; everything that needs a normal Linux userland runs in an Ubuntu 24.04 container:

```
distrobox create -Y -n aosp -i docker.io/library/ubuntu:24.04 --additional-packages "git git-lfs gnupg flex bison build-essential zip unzip curl zlib1g-dev libc6-dev-i386 libssl-dev bc lz4 zstd squashfs-tools libncurses6 pngcrush schedtool lzop imagemagick python3 python-is-python3 openjdk-17-jdk ccache rsync cpio xz-utils"
```

On the PC (outside the container) you also need `dtc`, `fastboot`, `e2fsprogs`, `cpio`, `python3`. The kernel is built with the **Android prebuilt clang r574158**
(`prebuilts/clang/host/linux-x86/clang-r574158`) and boot images are packed with AOSP's `mkbootimg.py` (`system/tools/mkbootimg`): fetch both from AOSP. Other clang versions are untested.

### 3. Build the kernel

```
curl -LO https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz      # keep it in the repo root, it is git-ignored
tar -xf linux-7.3.1.tar.xz
cd linux-7.3.1
patch -p1 < ../kernel/u880-kernel-delta.patch                                   # all our changes (about 220 files)
cp ../kernel/u880_defconfig arch/arm64/configs/
make LLVM=<clang>/bin/ ARCH=arm64 u880_defconfig                                # must equal kernel/u880.config
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image.gz modules
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e INSTALL_MOD_PATH=$PWD/../modules-out INSTALL_MOD_STRIP=1 modules_install
```

`LOCALVERSION` **must stay pinned** (`-u880e`): the initramfs and the rootfs carry modules for that exact release and the display driver silently never probes otherwise
(FINDINGS F7). `scripts/clean-rebuild.sh` does the pristine-tarball rebuild and compares the result with a working tree (used to prove the delta is complete).
After you change anything under `linux-7.3.1/`, regenerate the delta: `python3 scripts/snapshot-kernel-delta.py <pristine linux-7.3.1 dir> linux-7.3.1`.

### 4. Device tree

`dts/u880.dts` is the production DTB as source (it is the stock SoC DTB with our nodes: cooling maps, vibrator, audio, DP, display, thermal, ...). Compile it:

```
dtc -q -I dts -O dtb -o stage1/dtb2-u880.dtb dts/u880.dts        # scripts/build-dtb-from-dts.sh does the same
```

The ABL only accepts a DTB that contains the stock SoC structure (it applies the board overlay `dtbo` itself), which is why we start from the stock DT instead of a
minimal one (FINDINGS, `scripts/abl-oracle.sh`). Porting to a sibling tablet means extracting its own `dtb`/`dtbo` from its `vendor_boot` and `dtbo` partitions (`stock-dt/` shows how)
and re-applying our additions with `scripts/build-stock-disabled.sh` and the overlays in `stage1/*.dtso`.

### 5. Initramfs

`stage1/initramfs/` holds a busybox rescue `init` (v10). With `u880root=ufs` on the kernel command line it loads the UFS modules from `lib/modules-ufs/`, mounts the partition named
`userdata` (ext4, label `u880root`) and `switch_root`s; otherwise it is meant to give a rescue shell on the USB serial gadget (`usb0` 172.16.42.2). **On the 7.3/7.4 kernels this rescue is dead** (tested 2026-11-25): the USB PHY (`phy-qcom-qmp-combo`), `qcom_pmic_glink`, the eUSB2 repeater and the display clock (`dispcc-sm8550`) are modules that only the real root filesystem loads, so a rescue boot shows kernel text and then a black screen and never appears on the PC's USB. It has no `mkfs` or GNU `tar` either. Do not flash a rescue image unless those modules are in the initramfs.

```
mkdir -p stage1/initramfs/lib/modules-ufs
cp <ufs-qcom.ko qcom_ice.ko phy-qcom-qmp-ufs.ko built above> stage1/initramfs/lib/modules-ufs/
# put the Adreno firmware extracted from your tablet (see step 7) in stage1/initramfs/lib/firmware/qcom/
bash scripts/build-initramfs.sh          # -> stage1/initramfs.cpio.gz
```

The three UFS modules must come from the same build/release as the kernel (a mismatch hangs at boot before the root mount: blue screen, no network).

### 6. Boot image

```
python3 <aosp>/system/tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 14.0.0 --os_patch_level 2024-03 \
  --kernel linux-7.3.1/arch/arm64/boot/Image.gz --ramdisk stage1/initramfs.cpio.gz --dtb stage1/dtb2-u880.dtb \
  --pagesize 0x1000 --base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --second_offset 0 --tags_offset 0x100 --dtb_offset 0x1f00000 \
  --cmdline 'console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=ufs cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=0x0 msm.u880_dbg2=0 fw_devlink.sync_state=timeout' \
  -o stage1/u880-boot.img
```

`scripts/make-boot-image.sh` wraps this. Test first without writing anything: `fastboot boot stage1/u880-boot.img` (the ABL refuses `fastboot boot` while slot B is active:
`fastboot set_active a; fastboot reboot bootloader` first, see FINDINGS F18).

### 7. Firmware you must extract yourself

Vendor firmware is not redistributable and is **not** in this repo. Extract it from your own tablet's stock `vendor`/`odm`/`modem` images (they are ext4/erofs; `debugfs -R "cat ..."` works read-only), never from someone else's copy:

- Adreno 735: `gen71100_sqe.fw`, `gen71100_gmu.bin`, `gen71100_zap.mbn` -> `/lib/firmware/qcom/` on the root filesystem, and also into `stage1/initramfs/lib/firmware/qcom/` (the initramfs build `scripts/build-initramfs.sh` stops with a message if they are missing).
  SHA-256 of the files of the reference tablet (stock firmware `U880_B14_V3.0L.1_0311`), to check you extracted the right ones:
  `435c7bac9a328b8a100df930b84b65b4d579e42be44785d0e60e3729291bb864 gen71100_gmu.bin`, `b6df660d109504dbea5a266910b037a33d893a11c6de52f524a5fd112008c401 gen71100_sqe.fw`,
  `966d2984e1ac7a86f9a25c66fab3fd660423396f1375baf4432db0f1d80f9485 gen71100_zap.mbn` (other firmware versions may differ).
- ADSP (battery/charging, sensors, audio): the `adsp2*` set -> `/lib/firmware/qcom/u880/`, plus the sensor registry service (`hexagonrpcd`, see `sensors/README.md`).
- Wi-Fi: `ath11k/WCN6750/hw1.0/regdb.bin` and a `board-2.bin` built from the vendor `bdwlan.elf` with `scripts/make-ath11k-board2.py`; WPSS `qca6750/wpss.*` (the whole `qca6750/` directory, including `wpss.mdt` and the `wpss.bNN` parts, goes to `/lib/firmware/qca6750/`; without it `ath11k` fails with `Direct firmware load for qca6750/wpss.mdt failed with error -2` and there is no `wlan0`; the base tarball also lacks `wireless-regdb`, so install it too).
- Bluetooth: `qca/msbtfw12.mbn`, `qca/msnv12.bin` (+ `.tlv`).
- Speaker amps: `aw882xx_acf.bin`.
- The AudioReach topology is built from `topology/U880.m4` into `/lib/firmware/qcom/u880/U880-tplg.bin`.

`tablet-rootfs/BLOBS` lists the files and `BLOBS.sha256` pins the hashes of the ones installed on the reference tablet.

### 7b. Networking while you install: Ethernet over USB through the PC

The tablet has one USB-C port and, in the first hours of an install, no Wi-Fi (no firmware, no NetworkManager yet), so **everything in steps 8a to 10 happens over a USB cable to the PC**.
The kernel's built-in `g_cdc` gadget turns the cable into an Ethernet link (plus a serial port, `/dev/ttyACM0` on the PC, which has no login on it):

| | address | where it comes from |
|---|---|---|
| tablet, `usb0` | `172.16.42.2/24`, gateway `172.16.42.1`, DNS 9.9.9.9 (route metric 2000, a fallback behind Wi-Fi) | `tablet-rootfs/etc/systemd/network/usb0.network`, installed into the image by `scripts/build-rootfs-image.sh` |
| PC | `172.16.42.1/24` | a NetworkManager profile named `u880-usb`, method `shared`: it also NATs, which is how the tablet reaches the internet for `pacman` |

Create the PC side once (the interface name, `enpUSB3`/`enpUSB5`..., changes between plugs, so the profile matches on the pattern; **without the `match` a `shared` profile grabs your wired NIC and serves DHCP onto your LAN**):

```
nmcli connection add type ethernet con-name u880-usb ipv4.method shared ipv4.addresses 172.16.42.1/24 ipv6.method ignore
nmcli connection modify u880-usb connection.interface-name "" match.interface-name 'enp*u*'
```

Rules learned the hard way: the cable goes **straight into a PC port** (no hub, no dongle on the tablet); the link does not survive suspend; the same port is the DisplayPort output, so a monitor and the cable cannot be connected at the same time (use Wi-Fi ssh then).
Check it with `ping 172.16.42.2` and `ssh root@172.16.42.2`. The tablet has **no battery-backed clock**: set it from the PC after every cold boot (`ssh root@172.16.42.2 date -s @$(date +%s)`), or `pacman` rejects signatures and certificates.
A fresh system has a new SSH host key. Use a separate `UserKnownHostsFile` for the new install (an old entry for `172.16.42.2` makes ssh refuse with `REMOTE HOST IDENTIFICATION HAS CHANGED`; that is expected after a re-install, not an attack).

### 8a. Root filesystem: build the image on the PC and boot it from an SD card (the tested route, 2026-11-25)

Why this route: the rescue initramfs has no `mkfs` and no GNU `tar` (busybox `tar` drops xattrs and file capabilities), and **its rescue shell is dead on the 7.3/7.4 kernels** (step 5), so nothing can be formatted or unpacked on the tablet before Linux runs. Everything is therefore built on the PC, written to an SD card, and the first boot comes from the card. The internal storage (Android or an older Linux) is not touched until you decide to move.
You need: an SD card of 16 GB or more (a SanDisk or Samsung UHS-I card; see the card notes below), a card reader on the PC, root on the PC, and the files from steps 3 to 7.

1. **Tarball.** Download `ArchLinuxARM-aarch64-latest.tar.gz` and its `.sig` from `os.archlinuxarm.org`, verify with `gpg --verify` (key `68B3537F39A313B3E574D06777193F152BDBE6A6`).
2. **Firmware overlay (`FWDIR`).** A directory laid out like `/` that holds **only** the vendor files of step 7 (the paths in `tablet-rootfs/BLOBS`, the `u880/adsp2.*` set, `qca6750/` as a whole directory). **Do not copy whole directories of distro-owned firmware** (`qca/`, `ath11k/`): `pacman -Syu` later stops with `linux-firmware-atheros: /usr/lib/firmware/qca/... exists in filesystem`.
3. **Image.** As root, with `bsdtar` (libarchive) installed so that file capabilities (`ping`, `newuidmap`) survive; GNU `tar` prints `Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.security.capability'` and drops them:
   ```
   sudo TARBALL=ArchLinuxARM-aarch64-latest.tar.gz MODULES=<modules_install dir>/lib/modules/<release> FWDIR=<overlay> \
        SSH_PUBKEY=~/.ssh/id_ed25519.pub ROOT_LABEL=u880root scripts/build-rootfs-image.sh rootfs.img
   ```
   (on NixOS: `sudo nix-shell -p libarchive --run '...'` with absolute paths; `$HOME` becomes `/root` under sudo.) It unpacks the tarball, installs the modules and runs `depmod`, copies the overlay, installs everything listed in `tablet-rootfs/PATHS` (the offline equivalent of `tablet-config.sh push`; the mirror's home directory becomes `/home/alarm`), enables the project's units and a first-boot `u880-growfs.service`, and writes a 10 GB sparse ext4 image. Use another `ROOT_LABEL` (for example `u880sdtest`) when the tablet still has another root labelled `u880root`: fstab, growfs and the read-only udev rule all key on it. The tarball's default logins `alarm/alarm` and `root/root` stay: change them before the tablet joins a network.
4. **Shrink it** (the card is the slow part): `cp --sparse=always rootfs.img min.img; e2fsck -f min.img; resize2fs -M min.img; truncate -s $((BLOCKS*4096)) min.img` (`BLOCKS` from `dumpe2fs -h`). A 10 GiB image shrinks to about 3.6 GB.
5. **Write the card on the PC** (not in the tablet, whose slot wrote a slow card at 1 to 2 MB/s where the PC reader did 13 MB/s): `sudo bash scripts/write-sd-image.sh min.img /dev/sdX`. It refuses non-removable or mounted devices, partitions the card, writes the image, compares the sha256 of the written bytes, runs `e2fsck` and grows the filesystem to the whole card.
6. **Boot image that tries the card first.** `scripts/make-boot-image.sh` with `CMDLINE='... u880root=sd,ufs ...'` (the default cmdline of the script with `u880root=ufs` replaced). `u880root=sd,ufs` makes `init` v12 mount `mmcblk1p1` first and fall back to the internal root when that fails, so a bad card cannot strand the tablet in the dead rescue. **Do not make the SD wait longer than a few seconds in `init`**: with no card the internal root then mounted 21 s late, `dispcc` (a module of the root filesystem) came after `fw_devlink.sync_state=timeout`, and the display never probed (black screen, ssh fine). Flash it as in step 9.
7. **Card notes.** A card that fails with `mmc1: tuning execution failed: -110` / `DLL failed to LOCK` / `error -110 whilst initialising SD card` cannot do the 200 MHz mode on this board (two of three cards tried). Mask the fast modes in the SD node of the DTB and it runs at high speed (about 24 MB/s read): `fdtput -t x dtb /soc/sdhci@8804000 sdhci-caps-mask 3 0` (`<0x3 0x0>`: SDR50 and SDR104 off). **The mask applies to every card**, also fast ones, so remove it again when your card does not need it.

### 8b. First boot of the fresh system, and the install that needs a reboot in the middle

Boot with the card in. About 6 s of `init`, then Arch Linux ARM: display, USB networking and `sshd` are up (the very first boot can take minutes on a slow card). Then, over USB (step 7b):

1. `ssh root@172.16.42.2` (key from `SSH_PUBKEY`, or `alarm/alarm`), set the date (step 7b).
2. **Wi-Fi firmware and clock.** Without `/lib/firmware/qca6750/` (`wpss.mdt`, `wpss.bNN`, `wpss.qdb`, `regdb.bin`) the log says `remoteproc0: Direct firmware load for qca6750/wpss.mdt failed with error -2`, `ath11k ... probe with driver ath11k failed with error -2`, and there is no `wlan0`. If you copied the files after boot: `echo start > /sys/class/remoteproc/remoteproc0/state`, or reboot.
3. `pacman-key --init && pacman-key --populate archlinuxarm`.
4. **System upgrade, then reboot immediately:** `pacman -Syu --noconfirm --disable-download-timeout` (add `--overwrite '/usr/lib/firmware/qca/*'` etc. if step 8a.2 was not followed). It replaces `systemd`, `glibc`, `openssl` and `openssh` under the running system: afterwards new ssh sessions are reset before the banner (`kex_exchange_identification: Connection reset by peer`), the console shows `udev socket overridden while running` and `failed to send WATCHDOG=1 notification`. **Wait until the post-transaction hooks have finished (the log ends with the hooks list, and `pgrep pacman` is empty), then reboot.** Rebooting earlier leaves `/var/lib/pacman/db.lck` and half-run hooks (the log stops at `running '20-systemd-sysusers.hook'...`); repair with `rm /var/lib/pacman/db.lck; systemd-sysusers; systemd-tmpfiles --create; systemd-hwdb update; ldconfig; update-ca-trust`.
5. **Packages:** the list of step 8.6 plus `wireless-regdb` and `sddm`: about 660 packages, 800 MB to download, 3.8 GB installed. Run it detached (`systemd-run --unit=pkgs --property=StandardOutput=append:/root/pkg.log /root/script.sh`), because the connection can drop and the card can be slow. Do not reboot while it runs.
6. Continue with step 8 (passwords, `tablet-config.sh push` is already done by the image build, session flags), step 9 and step 10.

**Not tested yet:** moving the system from the card to the internal storage, installing without any SD card (for someone coming from Android: `fastboot flash userdata rootfs.img` is the obvious route, but this bootloader may not accept it and it destroys Android's data), and everything after the package install (Wi-Fi after a reboot, Bluetooth, audio, GPU, sensors, step 10).

### 8. Root filesystem (details, and the older route onto the internal partition)

1. Download `ArchLinuxARM-aarch64-latest.tar.gz` and verify the signature (key `68B3537F39A313B3E574D06777193F152BDBE6A6`).
2. **This destroys Android's userdata.** Format the UFS `userdata` partition as ext4 with label `u880root` and extract the tarball into it (as root, with xattrs, ACLs, numeric owners).
   The history of how this was done (via an SD card first) is in `NOTES.md`, section 15 "Android removed, Linux root on internal UFS".
   Every UFS partition except `userdata` is made read-only by `/etc/udev/rules.d/99-u880-ufs-readonly.rules`; keep it.
3. Install the kernel modules into `/usr/lib/modules/7.3.1-u880e/` and run `depmod`.
4. Change the default passwords (`alarm`/`alarm`, `root`/`root`) before putting the tablet on a network, and generate your own SSH key (the scripts expect a project key in `alarm/ssh/`, which is not in git).
5. Push our configs: `U880_HOST=<ip> scripts/tablet-config.sh push` (units, udev rules, sleep hook, UCM, thermal guard, Bluetooth and display services, Denial settings, `~/.bash_profile` session
   switch). `scripts/tablet-config.sh status` shows differences, `pull` captures them back.
6. Packages (Arch Linux ARM): `plasma-mobile plasma-keyboard plasma-settings systemsettings bluedevil kscreen kinfocenter dolphin konsole kclock kalk plasma-systemmonitor angelfish gwenview spectacle phosh squeekboard
   pipewire-audio wireplumber bluez bluez-utils iio-sensor-proxy libssc hunspell-en_us stress-ng lm_sensors rrdtool gamescope`, plus Mesa (freedreno/turnip) from the distribution. Steam and Proton: `steam/README-arm64.md`.
7. Session selection is done by flag files read by `~/.bash_profile`: `touch ~/.u880-plasma` for Plasma Mobile (default shell of this project), none for Denial. Important KDE settings are recorded in `NOTES.md`
   (on-screen keyboard: `kwinrc [Wayland] InputMethod=org.kde.plasma.keyboard.desktop`, `VirtualKeyboardMode=1`).
8. Flatpak (Flathub has `aarch64` builds; `flatpak bubblewrap xdg-desktop-portal`) needs two one-time steps, and apps must be started from the tablet's desktop session (from an ssh shell GTK finds no display):
   - **AppArmor:** the stock `flatpak` profile moves `bwrap` into a child profile where it fails with `bwrap: setting up uid map: Permission denied` / `ldconfig failed`. `tablet-config.sh push` installs
     `/etc/apparmor.d/local/flatpak` (`/usr/bin/bwrap Ux,`); then reload the profile once: `apparmor_parser -r /etc/apparmor.d/flatpak` (details: `NOTES.md`, 2026-11-25).
   - **QtWebEngine app (QtWebEngine):** the browser engine's own sandbox aborts (`bwrap: creation of new user namespaces was not disabled as requested`, then `FATAL ... zygote_host_impl_linux.cc`) and QtWebEngine app stays alive with no window.
     `flatpak override --user --env=QTWEBENGINE_DISABLE_SANDBOX=1 net.example.App` (mirrored in `tablet-rootfs/`) turns off Chromium's inner sandbox for QtWebEngine app only; Flatpak's sandbox stays. Reset: `flatpak override --user --reset net.example.App`.
   - **Wallet:** apps that store passwords (Komikku, for example) crash with `No such object path '/org/freedesktop/secrets/aliases/default'` until a default wallet exists. KDE does not create one by itself, and the KWallet
     settings page shows no prompt. Create it once on the tablet (as the desktop user, in the session); a dialog asks for the wallet password, which is your choice and is not stored in this repo:
     ```
     busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service CreateCollection 'a{sv}s' 1 org.freedesktop.Secret.Collection.Label s Default default
     busctl --user call org.freedesktop.secrets /org/freedesktop/secrets/prompt/p0 org.freedesktop.Secret.Prompt Prompt s ""   # use the prompt path the first command printed
     ```
     Check: `busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service ReadAlias s default` no longer returns `"/"`.

### 9. Flash and boot

From the running tablet (or from Android's fastboot once, for the very first image), write the boot image to the **inactive/target slot** and keep a backup of what you replace:

```
cat stage1/u880-boot.img | ssh root@<tablet> 'cat > /root/boot.img'
ssh root@<tablet> 'dd if=/dev/sde40 of=/root/u880-backup/boot_b-before.img bs=4M;            # sde40 = boot_b on the reference tablet
   blockdev --setrw /dev/sde /dev/sde40; dd if=/root/boot.img of=/dev/sde40 bs=4M conv=fsync; sync;
   blockdev --setro /dev/sde40 /dev/sde; head -c $(stat -c %s /root/boot.img) /dev/sde40 | sha256sum'
```

Check the hash against the image, then reboot. `scripts/gpt-mark-successful.py` marks a slot successful after `set_active` (see FINDINGS F13/F18). The partition names/devices are those of the reference
tablet: check yours with `ls -l /dev/disk/by-partlabel/` before writing anything. `scripts/flash-boot-b.sh` automates the first flash through an Android detour.

### 10. Verify

On the tablet: `uname -r` is `7.3.1-u880e`; `ls /sys/class/drm` shows `card1-DSI-1`; `dmesg | grep "UBWC programmed"` shows `STATIC=0x103e CTRL_2=0x2 PRED=0x1`;
`modetest -M msm -p` lists the four refresh modes; thermal zones show the cooling maps (`ls /sys/class/thermal/thermal_zone*/trip_point_*_temp`); `bluetoothctl show` has the factory address;
`iio-sensor-proxy` sees accelerometer and light; `pactl list short sinks` has `HiFi__Speaker__sink`; `scripts/dpms-fuzz.sh 100 200 4000` finishes without a wedge. Stress and game checks: `scripts/stress-run.sh`, `scripts/game-profile.sh`.

## Porting to another tablet

Mostly the kernel delta and the userspace are SoC-generic for SM7675/SM8650-class parts; the device-specific parts are the DT (`dts/u880.dts`: panel, touch, backlight PWM, speakers,
vibrator, USB-C wiring, regulators), the audio topology/UCM, the firmware set, partition names and the unlock method. Expect to redo: extract your stock DT, redo the panel init sequence
from your stock `qcom,mdss-dsi-*` nodes (`scripts/decode-panel-cmds.py`), and the display handoff quirks (FINDINGS F1-F9, F19-F20).

## What is not in this repo

- The Linux source tree (download 7.3.1 from kernel.org; our delta is `kernel/u880-kernel-delta.patch`).
- Vendor firmware and the stock images (extract from your own tablet), the Chinese `abl.elf` unlock files, the AOSP clang and `mkbootimg`.
- Any keys or passwords: the tablet's SSH key lives in `alarm/ssh/` (git-ignored). Default passwords of the Arch Linux ARM image must be changed.
- Build outputs and boot images (`stage1/*.img`, `.ko`, ...). They are rebuilt from the sources above.

## How much of this is verified

- `scripts/clean-rebuild.sh` rebuilds the kernel from the pristine tarball + delta + defconfig and gets an identical `Image` (apart from the build counter).
- The boot image was rebuilt with `mkbootimg` from the same inputs and verified bit for bit against the installed one; the thermal and UBWC images were produced and flashed with the commands above.
- Each feature in the table was tested on the reference tablet (measurements and logs in `NOTES.md`, `tools/profiles/`).
- Not done: a complete run of steps 0-10 on a clean machine and a second tablet. Expect to adapt paths and to hit gaps in the vendor-firmware extraction step.

## Credits and licences

Linux (GPL-2.0), the [senemos-uke-kernel-mainline](https://github.com/MCC45TR/senemos-uke-kernel-mainline) series (MIT) and the uke drivers it carries, Qualcomm's AudioReach topology and UCM
conventions, Arch Linux ARM, KDE Plasma Mobile, Mesa, gamescope, Valve's Steam/Proton for ARM64, bkerler/edl. Our own files in this repo (scripts, notes, DT additions, overlays) are published under the
GPL-2.0-only (see `LICENSE`). Vendor firmware and stock images are not part of this repository and keep their own licences.
