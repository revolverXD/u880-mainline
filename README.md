# Mainline Linux + Plasma Mobile on the Alldocube iPlay 70 mini Ultra (U880)

A mainline Linux 7.3.1 / 7.4-rc4 port for one tablet: **Alldocube iPlay 70 mini Ultra, Global model, codename U880**
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

Tested on kernel `7.4.0-rc4-u880e` (the default since 2026-11-25; every result of the fresh-install test below was measured on it) and on `7.3.1-u880e` (the previous release, kept as the known-good fallback; the benchmark table is 7.3.1), boot slot B, Plasma Mobile 6.8.

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
  the Xiaomi Pad 7 / POCO Pad X1, which has the same SoC. Our delta on top of vanilla Linux is `kernel/u880-kernel-delta-7.4.patch` (7.4-rc4, current) or `kernel/u880-kernel-delta.patch` (7.3.1).

## Repository map

| Path | What |
|---|---|
| `kernel/` | `u880-kernel-delta-7.4.patch` + `u880-7.4.config` (every source change vs vanilla 7.4-rc4, current); `u880-kernel-delta.patch` + `u880_defconfig` + `u880.config` (vs vanilla 7.3.1, previous) |
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

**Paths:** the scripts were written for the repo living at `/home/USER/External/work/src/mainline`, with `LineageOS/` (AOSP `prebuilts/clang/...` and `system/tools/mkbootimg`) next to it in `/home/USER/External/work/src/`. The newer scripts find their own directory; for the older ones rewrite the prefix once (run it in the repo root, it needs `mainline` to be the directory name or the first line to fix it):

```
SRC=$(dirname "$PWD")        # the directory that contains this repo and (for clang and mkbootimg) a LineageOS/ directory
grep -rIl '/home/USER/External/work/src/mainline' scripts tools tablet-rootfs steam | xargs -r sed -i "s#/home/USER/External/work/src/mainline#$PWD#g"
grep -rIl '/home/USER/External/work/src' scripts tools tablet-rootfs steam | xargs -r sed -i "s#/home/USER/External/work/src#$SRC#g"
```

Put the AOSP pieces where the scripts look: `$SRC/LineageOS/system/tools/mkbootimg` (`git clone https://android.googlesource.com/platform/system/tools/mkbootimg`) and, for the Android clang, `$SRC/LineageOS/prebuilts/clang/host/linux-x86/clang-r574158` (from AOSP `platform/prebuilts/clang/host/linux-x86`; pick a branch or tag that contains that directory). `scripts/build-kernel-7.sh` and `scripts/build-kernel.sh` use further paths of the original machine (`root/guest-kernel/...`): they are for the Debian VM and the Android-era build and are not needed for this install.

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

**Starting point.** The reference tablet ran stock firmware `U880_B14_V3.0L.1_0311` and then a LineageOS GSI (an Android system image flashed over the stock `system`, following the XDA guide below) before this port. A GSI changes only the system partitions: the stock `vendor`, `odm` and `modem` firmware that step 7 extracts is still there, so a tablet that runs LineageOS or any other GSI is a valid starting point as long as it is on firmware V3.0L.1 and unlocked. A tablet on a newer firmware is not (see below).

Download the full stock `U880_B14_V3.0L.1_0311` firmware (EDL "flat build": `rawprogram*.xml`, `patch0.xml`, `prog_firehose_ddr.elf`). Read every partition you can
with `bkerler/edl` (the tablet in EDL, programmer `prog_firehose_ddr.elf` from the stock package): for each LUN 0 to 5, `edl --loader=prog_firehose_ddr.elf --memory=ufs --lun=$L printgpt > gpt-lun$L.txt` and `edl --loader=prog_firehose_ddr.elf --memory=ufs --lun=$L rl backup-lun$L`; the partition tables (`gpt-lun*.txt`) are what every later EDL write takes its sectors from (never from notes). Keep a copy of the stock `boot_a`, `abl_a`, `abl_b`. The stock firmware and the unlock files come from the XDA guide for this model, `https://xdaforums.com/t/guide-root-gsi-alldocube-iplay-70-mini-ultra-sd7-gen3-global.4754469/` ("[GUIDE] ROOT + GSI - Alldocube iPlay 70 Mini Ultra (SD7+ Gen3) Global", read on 2026-11-26; it refuses automated fetchers with HTTP 403, so open it in a browser). What it offers: an attachment `U880_root.zip` (76.6 MB: the Qualcomm USB driver and QPST 2.7.496, Google platform-tools, and an `unlock` folder with `prog_firehose_ddr.elf`, `rawprogram_unlock.xml` and `patch0.xml`), a GSI tweaks zip and a low-latency tile apk, and links to stock ROMs hosted by others: an "oldest stock ROM" on MEGA (flashable with QFIL), `U880_B14_V3.0L.3_20250820.7z` (Google Drive, includes a `Flash_both_slots.cmd` for returning to stock) and `U880_B14_V3.0L.4_20260314_v2.1.7z` (Google Drive). The official builds that the thread and its OTA checker name, oldest first: `U880_B14_V3.0L.1_0311` (build of 2025-03-11, the reference firmware of this project; the thread's OTA checker starts its chain there), `V3.0L.2_20250629`, `V3.0L.3_20250820` and `V3.0L.4_20260314` (the March 2026 security update, "version 103"). The "oldest stock ROM" on MEGA is probably L.1 but the page does not say so: check the version after unpacking.
**Firmware L.4 and the unlock** (all reports of other users in the thread, none of it tested here): L.4 changed the signing key and added protection against replacing the ABL (limzei89, 2026-07-10). Replacing the ABL on L.4 gives the AVB red state (`Your device is corrupt. It can't be trusted and will not boot`), but fastboot still works, `fastboot flashing unlock` still works, and after it `fastboot flash boot boot.img` (the stock `boot.img` of that firmware) followed by `fastboot reboot` boots Android again; slakosd (2026-10-17) unlocked and rooted an L.4 tablet that way with a separately provided ABL package (`abl_flash_alldocube.zip`, linked in the thread, Google Drive) and a KernelSU-Next-patched `init_boot`. A tablet that was unlocked on the 2025 firmware can take the 2026 update (texhno04, 2026-07-03; not known for a locked one). A locked L.4 tablet was flashed back to L.1_0311 with the package's `Flash.cmd` (not with QFIL, as the L.4 package says) without bricking, although the rollback index drops from 1772668800 to 1733356800 (limzei89, 2026-07-06). This project's own rule is more cautious: it never lets the tablet take a stock OTA, and it has only ever run on L.1 with the ABL of the unlock package; a custom boot image on top of an L.4 unlock is untested.
Other things the thread says that matter here: flashing is done in **fastbootd** (`adb reboot fastboot`), not in the bootloader (an `unknown command` from `fastboot flash` means the wrong mode); `fastboot flash vbmeta` failing with `Failed to find AVB_MAGIC at offset: 0` means an old platform-tools (a post of 2026-03-20); stock firmware cannot be restored with fastboot commands, only through EDL (QFIL with `rawprogram.xml` and `patch0.xml` of the stock package, or the package's `Flash.cmd`/`Flash_both_slots.cmd`); EDL can be entered even from a bootloop (hold Vol+, Vol- and Power until the ALLDOCUBE logo flashes for about 0.1 s, release, connect the cable at once); a GSI flash that leaves a tablet rebooting every 3 seconds was recovered through that EDL entry (post of 2025-10-30); the Ultra Pad ships an Android 15 base, its GPT differs and its `rawprogram.xml` is not compatible with this tablet (limzei89, 2026-07-05).
The stock package is not redistributed here; use the reference version `U880_B14_V3.0L.1_0311`, never a build newer than V3.0L.1 (V3.0L.4 and later add ABL anti-tamper that defeats the unlock below). Recovery recipe if the system does not boot and fastboot is gone: enter EDL (`adb reboot edl`, or power off, hold Vol+ Vol- Power, release at the brief logo flash and plug in),
then flash the full stock firmware with `rawprogram_all.xml` + `patch0.xml` and `prog_firehose_ddr.elf`, memory type UFS (`bkerler/edl` on Linux, QPST/QFIL or `QSaharaServer` + `fh_loader` on Windows).
That XML leaves `persist`, `modemst*`, `fsg`, `devinfo`, `frp` and all `_b` partitions alone. Afterwards redo the unlock below. **Never tick "Erase all before download".**
If a Linux system that used to boot stops booting, repair `boot_b` over EDL with a known-good image (FINDINGS F41: take the LBA from the GPT, never from notes); the fastboot that the key combination gives is XBL's and cannot flash anything. While Linux still runs, step 9 flashes a new image from the running tablet.

### 1. Unlock the bootloader (model specific, risky)

The Global ABL refuses `fastboot flashing unlock`. The method used here (from an XDA guide for this model): write a modified Chinese-model `abl.elf` to
`abl_a` only over EDL (`rawprogram` for LUN 4; on the reference tablet `abl_a` starts at sector 95238 and is 256 sectors of 4096 B, but **read the start sector of `abl_a` from your own `printgpt` output** and edit the XML to match), then run `fastboot flashing unlock` (this wipes the tablet).
The Chinese `abl.elf` and the unlock `rawprogram` XML are **not** in this repo; the XDA guide above is where they come from. The guide does the unlock from **Windows with QFIL** (Configuration > FireHose Configuration: device type `ufs`, Reset After Download; Build Type Flat Build; the programmer and XML from its `unlock` folder; EDL by holding Vol+, Vol- and Power, releasing when the ALLDOCUBE logo flashes for about 0.1 s and connecting the cable at once, then Download) followed by `adb reboot bootloader`, `fastboot flashing unlock` and a confirmation on the tablet (which wipes it); the Linux equivalent used here is `bkerler/edl` with the same files (the `unlock` XML writes only `abl_a`). The guide's own prerequisites: OEM unlocking and USB debugging on, a USB 2.0 cable preferred, a backup first. It then roots with a KernelSU-Next patched `init_boot` and installs a GSI (`vbmeta` and `vbmeta_system` flashed with verification disabled, `fastboot erase system`, optionally `fastboot delete-logical-partition product_a` when there is not enough space, then `fastboot flash system <gsi>.img` and a factory reset): that GSI state is the starting point of this project, see above. Verify afterwards that `fastboot oem device-info` answers with `Device unlocked: true` (if it answers at all, ABL ran; XBL's fastboot does not answer it), and that once Linux runs, `grep -o androidboot.verifiedbootstate=[a-z]* /proc/cmdline` says `orange`.

### 2. Build environment

The project host is NixOS; everything that needs a normal Linux userland runs in an Ubuntu 24.04 container:

```
distrobox create -Y -n aosp -i docker.io/library/ubuntu:24.04 --additional-packages "git git-lfs gnupg flex bison build-essential zip unzip curl zlib1g-dev libc6-dev-i386 libssl-dev bc lz4 zstd squashfs-tools libncurses6 pngcrush schedtool lzop imagemagick python3 python-is-python3 openjdk-17-jdk ccache rsync cpio xz-utils"
```

On the PC (outside the container) you also need `dtc`, `fastboot`, `e2fsprogs`, `cpio`, `python3` (on NixOS none of them is on `PATH` by default: `nix-shell -p dtc e2fsprogs cpio python3`). The 7.3.1 kernel was built with the **Android prebuilt clang r574158**
(`prebuilts/clang/host/linux-x86/clang-r574158`); the 7.4-rc4 kernel builds with it and also with Nix's clang 21.1.8 (`scripts/build-kernel-nix.sh`), so any clang 21 should work, older ones are untested. Boot images are packed with AOSP's `mkbootimg.py` (`system/tools/mkbootimg`): fetch both from AOSP (see the paths note above).

### 3. Build the kernel

**Two kernels are supported; build one of them.** `7.4.0-rc4` (current): `kernel/u880-kernel-delta-7.4.patch` + `kernel/u880-7.4.config`, release `7.4.0-rc4-u880e`. `7.3.1` (previous): `kernel/u880-kernel-delta.patch` + `kernel/u880.config`, release `7.3.1-u880e`. Everywhere below, `<release>` means the one you built; the initramfs UFS modules, the boot image and the root filesystem's `/usr/lib/modules/<release>` must all come from the same build.

```
# 7.4.0-rc4 (rc snapshots live at git.kernel.org/torvalds/t/; check the hash, it is the tarball the delta was made against)
curl -LO https://git.kernel.org/torvalds/t/linux-7.4-rc4.tar.gz        # sha256 9f13091e6dd2d3576ad86e0c42ffa76b9993805a3f3a00f06981b242ea48aef9, 274538718 bytes
tar -xf linux-7.4-rc4.tar.gz && cd linux-7.4-rc4
patch -p1 < ../kernel/u880-kernel-delta-7.4.patch && cp ../kernel/u880-7.4.config .config
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e olddefconfig                      # must leave .config equal to kernel/u880-7.4.config
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image Image.gz modules
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e INSTALL_MOD_PATH=$PWD/../modules-out INSTALL_MOD_STRIP=1 modules_install
# on NixOS without the container (Nix clang 21.1.8, tree with .config in place):  MODULES_OUT=$PWD/../modules-out scripts/build-kernel-nix.sh linux-7.4-rc4
```

The 7.3.1 recipe (the same steps with its own files):

```
curl -LO https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz      # keep it in the repo root, it is git-ignored
tar -xf linux-7.3.1.tar.xz
cd linux-7.3.1
patch -p1 < ../kernel/u880-kernel-delta.patch                                   # all our changes (about 220 files)
cp ../kernel/u880_defconfig arch/arm64/configs/
make LLVM=<clang>/bin/ ARCH=arm64 u880_defconfig                                # must equal kernel/u880.config
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image Image.gz modules
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e INSTALL_MOD_PATH=$PWD/../modules-out INSTALL_MOD_STRIP=1 modules_install
```

`LOCALVERSION` **must stay pinned** (`-u880e`): the initramfs and the rootfs carry modules for that exact release and the display driver silently never probes otherwise
(FINDINGS F7). `KVER=7.4-rc4 scripts/clean-rebuild.sh` (or `KVER=7.3.1`) does the pristine-tarball rebuild and compares the result with a working tree (used to prove the delta is complete).
After you change anything under the tree, regenerate the delta: `python3 scripts/snapshot-kernel-delta.py <pristine 7.3.1 dir> linux-7.3.1`, or for 7.4: `SUFFIX=-7.4 python3 scripts/snapshot-kernel-delta.py <pristine linux-7.4-rc4 dir> linux-7.4-rc4`.

### 4. Device tree

`dts/u880.dts` is the production DTB as source (it is the stock SoC DTB with our nodes: cooling maps, vibrator, audio, DP, display, thermal, ...). Compile it (checked 2026-11-26: the result is **byte-identical** to the DTB of the image that ran all the tests, `cmp` clean, 504107 bytes; the camera clock-controller experiment that used to be enabled in this file is in `dts/camcc-experiment-reverse.patch`, apply it with `patch -R`):

```
dtc -q -I dts -O dtb -o stage1/dtb2-u880.dtb dts/u880.dts        # same as: scripts/build-dtb-from-dts.sh (default output stage1/dtb2-u880.dtb); NixOS: nix-shell -p dtc --run "bash scripts/build-dtb-from-dts.sh"
```

The ABL only accepts a DTB that contains the stock SoC structure (it applies the board overlay `dtbo` itself), which is why we start from the stock DT instead of a
minimal one (FINDINGS, `scripts/abl-oracle.sh`). Porting to a sibling tablet means extracting its own `dtb`/`dtbo` from its `vendor_boot` and `dtbo` partitions (`stock-dt/` shows how)
and re-applying our additions with `scripts/build-stock-disabled.sh` and the overlays in `stage1/*.dtso`.

### 5. Initramfs

`stage1/initramfs/` holds the busybox `init` (v12). With `u880root=ufs` on the kernel command line it loads the three UFS modules from `lib/modules-ufs/`, mounts the partition named `archdata` (or, on a stock layout, `userdata`; ext4, label `u880root`) and `switch_root`s;
with `u880root=sd,ufs` it tries the first partition of the SD card first and falls back to the internal root (README step 8a). With neither it is meant to give a rescue shell on the USB serial gadget (`usb0` 172.16.42.2). **On the 7.3/7.4 kernels this rescue is dead** (tested 2026-11-25): the USB PHY (`phy-qcom-qmp-combo`), `qcom_pmic_glink`, the eUSB2 repeater and the display clock (`dispcc-sm8550`) are modules that only the real root filesystem loads, so a rescue boot shows kernel text and then a black screen and never appears on the PC's USB. It has no `mkfs` or GNU `tar` either. Do not flash a rescue image unless those modules are in the initramfs.

The GPU firmware of step 7 must be in the initramfs too, so **do step 7 (at least the three `gen71100_*` files) before this one**, or build without it (`ALLOW_NO_GPU_FW=1`: boots, but nothing can render):

```
mkdir -p stage1/initramfs/lib/modules-ufs stage1/initramfs/lib/firmware/qcom
K=linux-7.4-rc4        # the tree of step 3
cp $K/drivers/ufs/host/ufs-qcom.ko $K/drivers/soc/qcom/qcom_ice.ko $K/drivers/phy/qualcomm/phy-qcom-qmp-ufs.ko stage1/initramfs/lib/modules-ufs/
cp <gen71100_sqe.fw gen71100_gmu.bin gen71100_zap.mbn from step 7> stage1/initramfs/lib/firmware/qcom/
bash scripts/build-initramfs.sh          # -> stage1/initramfs.cpio.gz   (ALLOW_NO_GPU_FW=1 bash scripts/build-initramfs.sh: without the GPU firmware)
```

The three UFS modules must come from the same build/release as the kernel (a mismatch hangs at boot before the root mount: blue screen, no network).

### 6. Boot image

```
scripts/make-boot-image.sh stage1/dtb2-u880.dtb stage1/u880-boot.img
```

The script packs the **uncompressed** kernel `arch/arm64/boot/Image` (not `Image.gz`; the working image's kernel is the 48 MB `Image`), `stage1/initramfs.cpio.gz` and the DTB with `mkbootimg.py` (header v2, offsets `--base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000`, page size 4096) and the command line that every tested image used
(`console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=ufs cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=0x0 msm.u880_dbg2=0 fw_devlink.sync_state=timeout`, plus `debugfs=off` unless `DEV=1`).
Defaults and overrides: `KIMAGE` (kernel Image; default the newest `linux-7.4-rc4`/`linux-7.3.1` in the repo root), `RAMDISK` (default `stage1/initramfs.cpio.gz`), `MKBOOTIMG` (default `../LineageOS/system/tools/mkbootimg/mkbootimg.py`; `git clone https://android.googlesource.com/platform/system/tools/mkbootimg`), `CMDLINE`. **Do not hand-type the `mkbootimg` command**: a made-up kernel argument once boot-looped the tablet (CLAUDE.md).
Before flashing, compare the 4096-byte header of your image with the installed one (`unpack_bootimg.py`): only the size fields, the id hash and the ramdisk may differ.

There is no RAM boot on this unit: the fastboot that the key combination gives is XBL's and refuses `boot` and `flash` (FINDINGS F43, F40), so a bad image is repaired over EDL (step 0, FINDINGS F41), not by booting another one. Flash and fall-back handling are in step 9.

### 7. Firmware you must extract yourself

Vendor firmware is not redistributable and is **not** in this repo. Extract it from your own tablet's stock images (never someone else's copy). The stock `vendor`, `odm` and `modem` images are partitions inside the Android `super` image: unpack it first (`lpunpack super.img`), then read the ext4 ones with `debugfs -R "cat <path>" <img>` or the erofs ones with `fsck.erofs --extract=<dir> <img>` (`debugfs` cannot read erofs). Where the files live in the stock (or LineageOS) vendor tree, and where they go on the root filesystem:

| Files | In the stock vendor tree | Destination on the tablet |
|---|---|---|
| Adreno 735: `gen71100_sqe.fw`, `gen71100_gmu.bin`, `gen71100_zap.mbn` | `/vendor/firmware/` | `/lib/firmware/qcom/`, **and** `stage1/initramfs/lib/firmware/qcom/` (step 5) |
| ADSP (battery/charging, sensors, audio): `adsp2.mdt`, `adsp2.bNN`, `adsp2_dtb.*` (Android's loader picks `adsp2`, not `adsp`) | `/vendor/firmware_mnt/image/` | `/lib/firmware/qcom/u880/` |
| Wi-Fi: the whole `qca6750/` directory (`wpss.mdt`, `wpss.bNN`, `wpss.qdb`, `regdb.bin`, `bdwlan.*`) | `/vendor/firmware_mnt/image/qca6750/` | `/lib/firmware/qca6750/` |
| Wi-Fi board file | build it: `scripts/make-ath11k-board2.py <fw>/qca6750/bdwlan.elf board-2.bin "bus=ahb,qmi-chip-id=1,qmi-board-id=255"` | `/lib/firmware/updates/ath11k/WCN6750/hw1.0/board-2.bin`; `regdb.bin` also to `/lib/firmware/ath11k/WCN6750/hw1.0/regdb.bin` |
| Bluetooth: `msbtfw12.mbn`, `msbtfw12.tlv`, `msnv12.bin` | `/vendor/bt_firmware/image/` | `/lib/firmware/qca/` |
| Speaker amplifiers: `aw882xx_acf.bin` (2016 bytes) | `/vendor/firmware/` | `/lib/firmware/` |
| AudioReach topology `U880-tplg.bin` | **already in the repo** (`topology/U880-tplg.bin`, byte-identical to `tablet-rootfs/lib/firmware/qcom/sm8550/U880-tplg.bin`, installed by `PATHS`) | `/lib/firmware/qcom/sm8550/` |

Without the `qca6750/` directory `ath11k` fails with `Direct firmware load for qca6750/wpss.mdt failed with error -2` and there is no `wlan0`. The base tarball also lacks `wireless-regdb`, so install it too.
SHA-256 of the Adreno files of the reference tablet (stock firmware `U880_B14_V3.0L.1_0311`), to check you extracted the right ones:
`435c7bac9a328b8a100df930b84b65b4d579e42be44785d0e60e3729291bb864 gen71100_gmu.bin`, `b6df660d109504dbea5a266910b037a33d893a11c6de52f524a5fd112008c401 gen71100_sqe.fw`,
`966d2984e1ac7a86f9a25c66fab3fd660423396f1375baf4432db0f1d80f9485 gen71100_zap.mbn` (other firmware versions may differ). `tablet-rootfs/BLOBS` lists the blobs of the reference tablet's root and `BLOBS.sha256` pins their hashes.
The topology can only be rebuilt with the upstream `audioreach-topology` sources (`topology/U880.m4` includes `audioreach/*.m4` and `util/*.m4` from `https://github.com/linux-msm/audioreach-topology`, not copied here) and `alsatplg`; the committed binary is what was tested, so you do not need to.

**Sensors are a second pass, not part of the first image.** `hexagonrpcd`, `libhexagonrpc.so.0.5` and `chrecd` are ARM64 programs that were built on the tablet itself (upstream `https://github.com/linux-msm/hexagonrpc` plus `patches/u880/hexagonrpc-0001-u880-writable-registry-large-buffers.patch`; see `sensors/README.md`), so a first install has none of them: build them on the booted tablet with the base-devel/meson tools and install them to `/usr/local` (`/etc/ld.so.conf.d/usr-local.conf` is already in the mirror). The data they serve is device-specific and comes from your own stock images: `/usr/share/qcom/u880/{sensors,socinfo,persist-sensors}` (`sensors/` = `/vendor/etc/sensors` of the stock vendor image, `socinfo/` = a few static files, `persist-sensors` = the calibration under `sensors/` on the stock `persist` partition) and a writable copy at `/var/lib/hexagonrpcd/persist-sensors`, owned by the system user `fastrpc` (uid/gid 961, created by `scripts/build-rootfs-image.sh`).
Without them everything else works; only auto-rotate and the light sensor are missing. The image build needs `/etc/ld.so.conf.d/usr-local.conf` (`/usr/local/lib`; Arch does not search it, so `hexagonrpcd` fails with `libhexagonrpc.so.0.5: cannot open shared object file`) and the `fastrpc` user before the first boot (otherwise `/dev/fastrpc-adsp` stays `root:root 0600`: `status=217/USER`, then `4/NOPERMISSION`).

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
5. **Packages:** the list of step 8c.6 plus `wireless-regdb` and `sddm`: about 660 packages, 800 MB to download, 3.8 GB installed. Run it detached (`systemd-run --unit=pkgs --property=StandardOutput=append:/root/pkg.log /root/script.sh`), because the connection can drop and the card can be slow. Do not reboot while it runs.
6. **Extra packages and services that the package list of step 8c.6 does not name** but the working system has: `earlyoom tuned tuned-ppd` (`apparmor upower avahi` come in as dependencies), and **`vulkan-freedreno`** (the Turnip Vulkan driver is a separate package from `mesa`; without it there is no Vulkan device and Steam/Proton games cannot run) and `alsa-utils` (`aplay`, `amixer`). Skip the useless initramfs generation for the distro kernel, which writes two 15 MB+ images to the card for 30+ minutes and is not used (our boot image carries its own ramdisk): `mkdir -p /etc/pacman.d/hooks; ln -sf /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook` **before** step 5. If it is already running, kill `mkinitcpio` **and its orphaned `find`/`grep` children**, which keep the hook's pipe open and block `pacman`.
7. **Enable the services** (the image build only enables those whose packages are in the base tarball): `systemctl enable NetworkManager NetworkManager-wait-online bluetooth apparmor upower sddm earlyoom tuned tuned-ppd sensord u880-thermal-guard u880-bt-connectable u880-zram u880-gpu-sample serial-getty@ttyGS0`. **`u880-thermal-guard` is not optional**: the die heats 2.5 to 5 C/s and the device-tree cooling maps alone do not protect it; do not load-test before it runs.
8. Continue with step 8c (passwords, session flags), step 9 and step 10. `tablet-config.sh push` is already done by the image build, **but only for the files listed in `tablet-rootfs/PATHS`**: 10 tracked files (thermal guard, `u880-bt-connectable`, vibrator modules, suspend log, `u880-rumble`, `steam-arm64-gs`, the HDMI UCM file) were missing from that list until 2026-11-26; `comm -23 <(cd tablet-rootfs && git ls-files . | sed 's#^#/#' | sort) <(grep -vE '^\s*(#|$)' tablet-rootfs/PATHS | sort)` must only show `PATHS`, `BLOBS*`, `/etc/environment` and `/etc/u880-bt-addr` (the owner's own Bluetooth address, never copy it).

**Tested on the fresh system (2026-11-26, from a clean public clone plus firmware and sensor data taken from the reference tablet):** boot from the card, display and Plasma Mobile session (SDDM), USB networking, Wi-Fi (5 GHz, power save off, 4 ms ping), touch, Vulkan on the Adreno (`Turnip Adreno (TM) 735`, Mesa 26.3.1), the speaker sink, the Bluetooth controller with the factory address, the accelerometer, gyroscope and light sensor (`ssccli --sensor accelerometer`; `monitor-sensor` from an ssh `su` says `Sensor claim not allowed`, which is only D-Bus authorization of a non-seat session), the thermal guard, no failed units. **Not tested:** Bluetooth pairing, audio playback, a game, suspend/resume, `scripts/dpms-fuzz.sh`, charging, moving the system from the card to the internal storage, and installing without any SD card (for someone coming from Android `fastboot flash userdata rootfs.img` is the obvious route, but this bootloader may not accept it and it destroys Android's data).

### 8c. Configuration reference, and the older route onto the internal partition (not the tested route)

The numbered list below is older than 8a/8b: items 1 and 2 (download the tarball, format the internal partition and extract it) need `mkfs.ext4` and a GNU `tar` on the tablet, which the initramfs does not have, so use 8a/8b instead (which build and write the same root on the PC). Items 3 onwards (modules, passwords, configs, packages, session flags, Flatpak) apply to every install; 8b refers to them as "step 8c.N".

1. Download `ArchLinuxARM-aarch64-latest.tar.gz` and verify the signature (key `68B3537F39A313B3E574D06777193F152BDBE6A6`).
2. **This destroys Android's userdata.** Format the UFS `userdata` partition as ext4 with label `u880root` and extract the tarball into it (as root, with xattrs, ACLs, numeric owners).
   The history of how this was done (via an SD card first) is in `NOTES.md`, section 15 "Android removed, Linux root on internal UFS".
   Every UFS partition except `userdata` is made read-only by `/etc/udev/rules.d/99-u880-ufs-readonly.rules`; keep it.
3. Install the kernel modules into `/usr/lib/modules/<release>/` (for example `7.4.0-rc4-u880e`) and run `depmod` (`scripts/build-rootfs-image.sh` does both).
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

**Sound needs one symlink that no file copy carries:** `ln -s ../../Qualcomm/sm8550/U880/U880.conf /usr/share/alsa/ucm2/conf.d/sm8550/U880.conf` (done by `build-rootfs-image.sh`). Without it the card exists (`/proc/asound/cards`: `sm8550 - U880`) but PipeWire only offers the profiles `off` and `pro-audio`, and `pactl list short sinks` shows only `auto_null`; with it there is `alsa_output.platform-sound.HiFi__Speaker__sink` after `systemctl --user restart wireplumber`.

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

On the tablet: `uname -r` is `<release>` (`7.4.0-rc4-u880e` or `7.3.1-u880e`); `ls /sys/class/drm` shows `card1-DSI-1`; `dmesg | grep "UBWC programmed"` shows `STATIC=0x103e CTRL_2=0x2 PRED=0x1`;
`modetest -M msm -p` lists the four refresh modes; thermal zones show the cooling maps (`ls /sys/class/thermal/thermal_zone*/trip_point_*_temp`); `bluetoothctl show` has the factory address;
`iio-sensor-proxy` sees accelerometer and light; `pactl list short sinks` has `HiFi__Speaker__sink`; `scripts/dpms-fuzz.sh 100 200 4000` finishes without a wedge. Stress and game checks: `scripts/stress-run.sh`, `scripts/game-profile.sh`.

## Porting to another tablet

Mostly the kernel delta and the userspace are SoC-generic for SM7675/SM8650-class parts; the device-specific parts are the DT (`dts/u880.dts`: panel, touch, backlight PWM, speakers,
vibrator, USB-C wiring, regulators), the audio topology/UCM, the firmware set, partition names and the unlock method. Expect to redo: extract your stock DT, redo the panel init sequence
from your stock `qcom,mdss-dsi-*` nodes (`scripts/decode-panel-cmds.py`), and the display handoff quirks (FINDINGS F1-F9, F19-F20).

## What is not in this repo

- The Linux source tree (download it: 7.3.1 from kernel.org with `kernel/u880-kernel-delta.patch`, or 7.4-rc4 with `kernel/u880-kernel-delta-7.4.patch`).
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
