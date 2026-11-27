# Mainline Linux + Plasma Mobile on the Alldocube iPlay 70 mini Ultra (U880)

A mainline Linux 7.3.1 / 7.4-rc4 port for one tablet: **Alldocube iPlay 70 mini Ultra, Global model, codename U880**
(Qualcomm Snapdragon 7+ Gen 3, SM7675 "Cliffs", 12 GB RAM, 256 GB UFS (the chip reports spec 4.0; the vendor says 3.1), 8.8" 1600x2560 144 Hz panel). It runs Arch Linux ARM with
KDE Plasma Mobile (and the Denial shell), native ARM64 Steam and Proton, with the GPU, display, touch, Wi-Fi, Bluetooth,
audio (speakers and microphone), both cameras, hardware video, sensors, USB-C (host, DisplayPort, PD), battery and thermal control working.
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
| Touch (Novatek NT36523N, 10 points) | works (rising-edge IRQ and pressure/major axes since 2026-11-27: idle interrupts 1330/s -> 14/s, F61); the numbers that follow predate that change: the IC publishes only ~31-47 frames/s and about 1 in 5 light taps is lost (IC firmware, FINDINGS/NOTES 2026-11-24) |
| Wi-Fi 6 (ath11k WCN6750) | works |
| Bluetooth 5.4 (A2DP incl. LDAC, HID, BLE central and peripheral, factory address) | works; LE Audio untested |
| Audio: 2 speakers (AW88261, 0 dB unity gain in UCM, F63), DisplayPort audio, PipeWire | works |
| Microphone: one built-in analog mic (WCD9395 AMIC1 over SoundWire, `hw:0,2`) | works with `arecord`/`alsaucm`; PipeWire capture inside a Plasma session and capture across suspend not tested (F52) |
| Sensors: accelerometer, ambient light, gyroscope, compass via ADSP | works |
| USB-C: host, USB 3 SuperSpeed, DisplayPort alt mode, PD charging, gadget for ssh | works |
| Battery gauge and charging (via ADSP, PMIC GLINK) | works |
| Suspend: s2idle (power key), deep suspend | works (about 0.5-0.7 W asleep; SoC deep states not reached, issue #13) |
| Vibration motor | works (no haptics service yet) |
| Steam ARM64 + Proton Experimental ARM64 (games run) | works |
| Cameras: front GC05A2 5 MP, rear OV13B10 13 MP (CAMSS + libcamera software ISP on the GPU, PipeWire/Plasma Camera, rear flash LED and autofocus) | works (27-30 fps); **never start a camera with the screen off**: it wedges the RPMh `apps_rsc` until a forced reboot (F53); libcamera tuning and a landscape viewfinder quirk open |
| Video: hardware H.264/HEVC encode and H.264/HEVC/VP9/AV1 decode (qcom-iris) | works (1080p60 H.264 decode 285 fps) (F54) |
| Compute DSP (CDSP) + FastRPC, hardware TRNG (`qcom-rng`) | works; the QCE crypto engine is deliberately not enabled (upstream marks it BROKEN; the CPU's ARMv8 crypto is faster) (F59, F60) |
| DDR/LLCC bandwidth scaling (icc-bwmon) | works (F58) |
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

**Paths:** the scripts were written for the repo living at `/home/USER/External/work/src/mainline`, with `LineageOS/` (AOSP `prebuilts/clang/...` and `system/tools/mkbootimg`) next to it in `/home/USER/External/work/src/`. The newer scripts find their own directory; for the older ones rewrite the prefix once (run it in the repo root; the clone may have any name, only `LineageOS/` has to sit next to it; steps 2 to 7 do not need them (the scripts used there find their own directory); the `sed` lines modify about 33 tracked files, so do not commit them: `git checkout .` undoes them):

```
SRC=$(dirname "$PWD")        # the directory that contains this repo and (for clang and mkbootimg) a LineageOS/ directory
grep -rIl '/home/USER/External/work/src/mainline' scripts tools tablet-rootfs steam | xargs -r sed -i "s#/home/USER/External/work/src/mainline#$PWD#g"
grep -rIl '/home/USER/External/work/src' scripts tools tablet-rootfs steam | xargs -r sed -i "s#/home/USER/External/work/src#$SRC#g"
```

In `tablet-rootfs/` and `steam/` the word `USER` is a different placeholder: the tablet's user name, not a host path (`TABLET_USER=<name> scripts/tablet-config.sh push` and `scripts/build-rootfs-image.sh` replace it in the paths, the owners and the file contents). Scripts that call `edl` (`scripts/u880-ab.py`) look for the unlock folder's programmer at `../recovery/unlock/prog_firehose_ddr.elf` relative to the **current directory** (run it from the repo root, so `$SRC/recovery/unlock/`), or take `EDL_LOADER=<path>`; `scripts/stock-camera-check.sh` is an Android-era script whose header still mentions a `fastboot boot` that no longer works (F43).

Put the AOSP pieces where the scripts look: `$SRC/LineageOS/system/tools/mkbootimg` (`git clone https://android.googlesource.com/platform/system/tools/mkbootimg`) and, for the Android clang, `$SRC/LineageOS/prebuilts/clang/host/linux-x86/clang-r574158` (from AOSP `platform/prebuilts/clang/host/linux-x86`, tag `android-16.0.0_r4`, which contains it (the tree used here has that repository at commit `9916fb51ccb914d62d35ad9a7b9b21d2ef046928`, "Snap for 14079904"; both checked 2026-11-26 with `git ls-tree`): `git clone --depth=1 -b android-16.0.0_r4 --filter=blob:none --sparse https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 $SRC/LineageOS/prebuilts/clang/host/linux-x86 && git -C $SRC/LineageOS/prebuilts/clang/host/linux-x86 sparse-checkout set clang-r574158` (3.4 GB; sparse-checkout syntax not run here). Or build with the Nix clang of recipe B if you have no clang 21 (any 21.x works: Nix's 21.1.8 built this kernel several times; the script uses the unpinned `llvmPackages` of your nixpkgs channel, so the version may differ)). `scripts/build-kernel-7.sh` and `scripts/build-kernel.sh` use further paths of the original machine (`root/guest-kernel/...`): they are for the Debian VM and the Android-era build and are not needed for this install.

## Safety rules

These come from mistakes and a brick on this exact model:

1. **Never use QFIL/EDL "Erase all before download".** It has bricked this model.
2. Never write `abl`, `xbl`, `vendor_boot`, `dtbo` or `vbmeta` from Linux. Only `boot_a`/`boot_b` are written by the scripts here.
3. Never flash stock images one partition at a time in fastboot; use the EDL XMLs of the full stock firmware for recovery.
4. Keep the original ABL: `abl_a`/`abl_b` backups are the only copies of the original Global ABL.
5. Back up everything you can read before touching anything (`persist`, `modemst*`, `fsg`, `devinfo`, the GPT of every LUN).
6. There is no RAM boot on this unit (the fastboot that the key combination gives is XBL's and refuses `boot`, FINDINGS F43): a boot image is tested by flashing `boot_b` with a backup and a known-good image at hand, and a bad image on the active slot needs the USB cable, EDL and a PC to recover (FINDINGS F41).
7. This project removed Android's userdata (`sda11` is now the Linux root). There is no going back without a factory reset and the stock images.

## How to recreate the system

You need: a Linux PC, the tablet on stock firmware `U880_B14_V3.0L.1_0311` (stock images for EDL recovery), a USB-C cable, at least 25 GB of disk (steps 0 to 7 alone use about 13 GB: kernel tree 8, stock zip 2.8, extracted images 1.7; the step 0 backups add about 3 GB and the step 8a root image 10 GB) and, for the first kernel build, about 15 minutes on 16 cores (measured 2026-11-26). The steps are in the order they were done; each says where the details are.
**Reading this as an LLM agent:** start with `CLAUDE.md` (the rules that override everything), then do the steps in the order of the next line (steps 0 to 7 means 0, 1, 2, 3, 4, 7, 5, 6; 7b and later need the tablet and are the install itself); steps 7b, 8a and 8b are the route that was actually run end to end, with the errors you will see and what they mean. Every flash or format needs the user's explicit go, with the exact command, the target device and the backup shown first.
**Order of work: 0, 1, 2, 3, 4, then 7, then 5, 6, then 7b, 8a, 8b, 8c, 9, 10.** The numbers are historical: the initramfs of step 5 needs the GPU firmware of step 7 (or `ALLOW_NO_GPU_FW=1`, which builds a ramdisk without rendering).

### 0. Back up and get recovery material

**Starting point.** The reference tablet ran stock firmware `U880_B14_V3.0L.1_0311` and then a LineageOS GSI (an Android system image flashed over the stock `system`) before this port. A GSI changes only the system partitions: the stock `vendor`, `odm` and `modem` firmware that step 7 extracts is still there, so a tablet that runs LineageOS or any other GSI is a valid starting point as long as it is on firmware V3.0L.1 (step 1 unlocks it if it is not unlocked yet). **Use V3.0L.1 and nothing newer** (L.2 and L.3 were never tried here; every hash in this README is from L.1) (see "Firmware L.4" below). Flashing a GSI is **not** a prerequisite of this port: what the reference tablet has is an unlocked bootloader (step 1) and `vbmeta`/`vbmeta_system` flashed with verification disabled by the guide's GSI procedure; whether Linux boots without the latter is untested: do it (step 1.6), the reference tablet has them, and it costs nothing.

**Where the files come from.** The XDA guide for this model, `https://xdaforums.com/t/guide-root-gsi-alldocube-iplay-70-mini-ultra-sd7-gen3-global.4754469/` ("[GUIDE] ROOT + GSI - Alldocube iPlay 70 Mini Ultra (SD7+ Gen3) Global", read on 2026-11-26; it refuses automated fetchers with HTTP 403, so open it in a browser). It offers an attachment `U880_root.zip` (no checksum is published; 76.6 MB on the forum page, 81,842,388 bytes as downloaded: the Qualcomm USB driver and QPST 2.7.496, Google platform-tools, and an `unlock` folder with `prog_firehose_ddr.elf`, `rawprogram_unlock.xml`, `patch0.xml` and the Chinese `abl.elf`), a GSI tweaks zip and a low-latency tile apk, and links to stock ROMs hosted by others: an "oldest stock ROM" on MEGA, `U880_B14_V3.0L.3_20250820.7z` and `U880_B14_V3.0L.4_20260314_v2.1.7z` (Google Drive). The official builds, oldest first: `V3.0L.1_0311` (2025-03-11, the reference firmware), `V3.0L.2_20250629`, `V3.0L.3_20250820`, `V3.0L.4_20260314` (the March 2026 security update, "version 103"). The MEGA link is `U880_B14_V3.0L.1_0311.zip` (2,938,652,908 bytes, sha256 `8c9f999a7d43574a55083510e7732aef68967f09d516c778c5e9a9ac757ebbdd`, checked 2026-11-26): an EDL flat build with the separate partition images, `prog_firehose_ddr.elf`, `Flash.cmd`, **`rawprogram_all.xml`** (the only rawprogram file in it), `patch0.xml` and `gpt_main0-5.bin`/`gpt_backup0-5.bin`. The stock package is not redistributed here.

**Tools.** `bkerler/edl` (`https://github.com/bkerler/edl`; its README covers the udev rules and the Python dependencies) with **the programmer of the guide's `unlock` folder** (`prog_firehose_ddr.elf`, sha256 in step 1) for every `edl` command: the stock package's programmer has the same size and a different hash and was never tried. So fetch `U880_root.zip` before you back anything up (give `--loader` the full path `$SRC/recovery/unlock/prog_firehose_ddr.elf`) and unpack its `unlock` folder: `unzip U880_root.zip 'unlock/*' -d $SRC/recovery/` (its platform-tools are for Windows: on Linux use your distribution's `android-tools`) (`$SRC` is the directory that contains this repo; "Paths" under Repository map).

**Back up** (the tablet in EDL: how to enter it is under **Recovery** below;  `L` is the LUN; the partition tables are what every later EDL write takes its sectors from, never notes):
1. `for L in 0 1 2 3 4 5; do edl --loader=prog_firehose_ddr.elf --memory=ufs --lun=$L printgpt > gpt-lun$L.txt; done`. Keep all backups in a directory of their own (`$SRC/u880-backup/`), not in the unlock folder; the loader path is then `$SRC/recovery/unlock/prog_firehose_ddr.elf`.
2. LUN 1 to 5 are small (xbl and ddr, the 72 partitions of LUN 4, `modemst1`/`modemst2`/`fsg`): `for L in 1 2 3 4 5; do edl --loader=prog_firehose_ddr.elf --memory=ufs --lun=$L rl backup-lun$L; done` (about 3 GB together; LUN 4 holds `abl_a`/`abl_b`, `boot_a`/`boot_b`, `modem_*`, `bluetooth_*`, `devinfo`).
3. LUN 0 holds the big partitions of the stock layout: `super` 8 GB, `rawdump` 12.2 GB, `userdata` 214 GiB. **Do not `rl` it.** Read the small ones one by one with `edl ... --lun=0 r <name> <file>`: `vbmeta_system_a`/`vbmeta_system_b`, `persist` (32 MB; it also holds the sensor registry and calibration that step 7 needs), `misc`, `frp`, `keystore`, `ssd`, `metadata`.
4. Keep a copy of `abl_a`, `abl_b` (the original Global ABL, the only copies) and the stock `boot_a`.

**Recovery.** Enter EDL with `adb reboot edl` (Android running, USB debugging on), or with the tablet off: hold Vol+, Vol- and Power until the ALLDOCUBE logo flashes for about 0.1 s (backlight on, screen black), release and connect the cable at once; this works even from a bootloop (post of 2025-10-30 in the thread). When the tablet does not boot at all, the deep flash cable (USB D+ shorted to GND, Vol+/Vol- held) forces EDL: it was needed on 2026-11-02 (FINDINGS F40). **Warning:** `rawprogram_all.xml` rewrites the primary and backup GPT of all six LUNs (`gpt_main*.bin`, `gpt_backup*.bin`) and zeroes the start of `userdata`: on a tablet that was repartitioned for Linux it destroys the Linux partition table and root (restore from your GPT/partition backups). To restore the whole stock firmware use `rawprogram_all.xml` + `patch0.xml` and the programmer, memory type UFS. The command that restored the reference tablet (Windows, 2026-10-11, from its QFIL log; 5.98 GB; `--setactivepartition=1` makes slot a active): `fh_loader.exe --port=\\.\COM3 --setactivepartition=1 --zlpawarehost=1 --sendxml=rawprogram_all.xml,patch0.xml --search_path=<...>\U880_B14_V3.0L.1_0311\images --noprompt --showpercentagecomplete --memoryname=UFS --reset`; the package's own `Flash.cmd` does the same (the thread says: use `Flash.cmd`, not QFIL, for the L.4 package). On Linux `bkerler/edl` has a `qfil` command that takes the XMLs (see its README; not run here). That XML leaves `persist`, `modemst*`, `fsg`, `devinfo`, `frp` and all `_b` partitions alone. Afterwards redo the unlock (step 1). **Never tick "Erase all before download".** If a Linux system that used to boot stops booting, repair `boot_b` over EDL with a known-good image (FINDINGS F41); the fastboot that the key combination gives is XBL's and cannot flash anything. While Linux still runs, step 9 flashes a new image from the running tablet.

**Firmware L.4 and the unlock** (all reports of other users in the thread, none of it tested here): L.4 changed the signing key and added protection against replacing the ABL (limzei89, 2026-07-10). Replacing the ABL on L.4 gives the AVB red state (`Your device is corrupt. It can't be trusted and will not boot`), but fastboot still works, `fastboot flashing unlock` still works, and after it `fastboot flash boot boot.img` (the report does not say in which fastboot mode) (the stock `boot.img` of that firmware) followed by `fastboot reboot` boots Android again; slakosd (2026-10-17) unlocked and rooted an L.4 tablet that way with a separately provided ABL package (`abl_flash_alldocube.zip`, linked in the thread, Google Drive) and a KernelSU-Next-patched `init_boot`. A tablet that was unlocked on the 2025 firmware can take the 2026 update (texhno04, 2026-07-03; not known for a locked one). A locked L.4 tablet was flashed back to L.1_0311 with `Flash.cmd` without bricking, although the rollback index drops from 1772668800 to 1733356800 (limzei89, 2026-07-06). This project's own rule is more cautious: it never lets the tablet take a stock OTA, and it has only ever run on L.1 with the ABL of the unlock package; a custom boot image on top of an L.4 unlock is untested.
**Other things the thread says that matter here:** flashing is done in **fastbootd** (`adb reboot fastboot`), not in the bootloader (`unknown command` from `fastboot flash` means the wrong mode); `fastboot flash vbmeta` failing with `Failed to find AVB_MAGIC at offset: 0` means an old platform-tools (post of 2026-03-20); stock firmware cannot be restored with fastboot commands, only through EDL; a GSI flash that leaves the tablet rebooting every 3 seconds was recovered through EDL (post of 2025-10-30); the Ultra Pad ships an Android 15 base, its GPT differs and its `rawprogram` XML is not compatible with this tablet (limzei89, 2026-07-05).

### 1. Unlock the bootloader (model specific, risky)

The Global ABL refuses `fastboot flashing unlock`. The method (from the XDA guide above) writes the Chinese-model `abl.elf` over `abl_a`, nothing else, then unlocks.

- **Active slot first:** this writes `abl_a` only, so the tablet must boot slot a: `fastboot getvar current-slot` (or `adb shell getprop ro.boot.slot_suffix`); on slot b run `fastboot set_active a` first (untested here: a locked bootloader may refuse it, and a tablet that only boots from slot b has no tested path; the fastboot to use is the bootloader's, `adb reboot bootloader`, not the key-combination one, which is XBL's and refuses commands), or the Global ABL of `abl_b` keeps running.
1. **Files** of the guide's `unlock` folder, by hash: `abl.elf` (241,464 bytes) `9e7f416e255ade22d21df2118a69cca37a85f8af53f342dfb0e507efabd597b3`; `rawprogram_unlock.xml` `9c117484f6fe00f12518757f85bcb849de014f6adbdc6f66dfb06363d57c57f1`; `patch0.xml` `06ad8dc21eb42ea1289092be0a139d025688bcec3d6dbfb0c1373c4cb5e002b1` (**not used**: the unlock run sent only `rawprogram_unlock.xml`); `prog_firehose_ddr.elf` (1,568,240 bytes) `f809475544eed6ba04bdbd03b795856d0fdb77bacc7206befd8a8d9b7b22abfb`.
2. **The XML** has one `<program>` for `abl.elf`: `label=abl_a`, `physical_partition_number=4`, `start_sector=95238` (byte `0x17406000`), `num_partition_sectors=256` of 4096 B. These numbers equal the `abl_a` entry of the stock package's own `gpt_main4.bin` (checked 2026-11-26, as is `boot_b` = LBA 454422, 24576 sectors), but **read the start sector of `abl_a` from your own `printgpt` output** and edit the XML if it differs.
3. **Write it** (tablet in EDL): the tested way is the guide's, from **Windows with QFIL** (Configuration > FireHose Configuration: device type `ufs`, Reset After Download; Build Type Flat Build; the programmer, `rawprogram_unlock.xml` from the `unlock` folder; Download). The log of the reference run: `fh_loader.exe --port=\\.\COM3 --sendxml=rawprogram_unlock.xml --search_path=<...>\unlock --memoryname=UFS --zlpawarehost=1 --noprompt`, "59 sectors needed at location 95238 on LUN 4". On Linux the same raw write is `edl --loader=prog_firehose_ddr.elf --memory=ufs --lun=4 ws 95238 abl.elf` (95238 is the sector of the reference tablet: use the `abl_a` start sector of your own `printgpt`) (the command that wrote `boot_b` in F41; **not run for `abl_a` here**). Afterwards the first 241,464 bytes of `abl_a` read back equal `abl.elf`; the rest of the 1 MiB partition is the old content.
4. **Unlock:** disconnect the cable, hold Power for about 10 s so that Android boots, enable USB debugging and OEM unlocking, run `adb reboot bootloader` (this reaches the fastboot of the replaced ABL; the fastboot that the key combination gives on a Linux-only tablet is XBL's and refuses flash and unlock), then `fastboot flashing unlock` and confirm with volume and power on the tablet. **This wipes the tablet.**
5. **Verify:** `fastboot oem device-info` answers with `Device unlocked: true` (if it answers at all, ABL ran; XBL's fastboot does not answer it); once Linux runs, `grep -o androidboot.verifiedbootstate=[a-z]* /proc/cmdline` says `orange`.
6. **vbmeta (do this; the reference tablet has it)** and **what else the guide does (optional, not needed by this port)**. The images are in `U880_B14_V3.0L.1_0311/images/` of the stock package. **Do:** `fastboot --disable-verification flash vbmeta images/vbmeta.img` (the unlock wiped the tablet: boot Android once, finish the setup and re-enable USB debugging before `adb reboot fastboot`; all `fastboot flash`/`erase` here run in fastbootd, `adb reboot fastboot`; only `fastboot flashing unlock` of step 4 runs in the bootloader), `fastboot --disable-verity --disable-verification flash vbmeta_system images/vbmeta_system.img` (both byte-identical to the ones the reference tablet uses). **Optional (the guide's root and GSI, the reference tablet has them):** root with a KernelSU-Next patched `init_boot` (`fastboot flash init_boot`, in fastbootd), then `fastboot erase system`, optionally `fastboot delete-logical-partition product_a` ("Not enough space"), `fastboot flash system <gsi>.img`, then a factory reset. None of it is needed to boot this port except, perhaps, the `vbmeta` flags (untested, see step 0).

### 2. Build environment

The project host is NixOS; everything that needs a normal Linux userland runs in an Ubuntu 24.04 container:

```
distrobox create -Y -n aosp -i docker.io/library/ubuntu:24.04 --additional-packages "git git-lfs gnupg flex bison build-essential zip unzip curl zlib1g-dev libc6-dev-i386 libssl-dev bc lz4 zstd squashfs-tools libncurses6 pngcrush schedtool lzop imagemagick python3 python-is-python3 openjdk-17-jdk ccache rsync cpio xz-utils"
```

On the PC (outside the container) you also need `dtc`, `fastboot` and `adb` (android-tools), `e2fsprogs` (`debugfs`, `mkfs.ext4`), `mtools` (`mdir`, `mcopy`: they read the FAT partitions of the stock package), `unzip`, `libarchive` (`bsdtar`, step 8a), `cpio`, `python3` and `bkerler/edl` (step 0); on NixOS none of them is on `PATH` by default: `nix-shell -p dtc android-tools e2fsprogs mtools unzip libarchive cpio python3 gnupatch` (edl: `pip` in a venv, with the native libraries of its README; Nix does not provide them by default). The 7.3.1 kernel was built with the **Android prebuilt clang r574158**
(`prebuilts/clang/host/linux-x86/clang-r574158`); the 7.4-rc4 kernel builds with it and also with Nix's clang 21.1.8 (`scripts/build-kernel-nix.sh`), so any clang 21 should work, older ones are untested; Ubuntu 24.04's own repository has no clang 21, so take the AOSP prebuilt, a clang 21 build from your distribution or from `apt.llvm.org` (that last source is not tested here). Boot images are packed with AOSP's `mkbootimg.py` (`system/tools/mkbootimg`): fetch mkbootimg from AOSP (see the paths note above); the AOSP clang is only needed for recipe A of step 3 (3.4 GB), recipe B uses Nix's clang.

### 3. Build the kernel

**Two kernels are supported; build one of them.** `7.4.0-rc4` (current): `kernel/u880-kernel-delta-7.4.patch` + `kernel/u880-7.4.config`, release `7.4.0-rc4-u880e`. `7.3.1` (previous; `kernel/u880_defconfig` is the input, `kernel/u880.config` the full `.config` it yields, which `clean-rebuild.sh` compares): `kernel/u880-kernel-delta.patch` + `kernel/u880.config`, release `7.3.1-u880e`. Everywhere below, `<release>` means the one you built; the initramfs UFS modules, the boot image and the root filesystem's `/usr/lib/modules/<release>` must all come from the same build.

```
# 7.4.0-rc4: get and patch the tree. Run this in the REPO ROOT: step 5 and scripts/make-boot-image.sh look for linux-7.4-rc4/ there (the old git.kernel.org snapshot URL answered 200 with 0 bytes on 2026-11-26, GitHub's tag archive is byte-identical; check the hash, it is the tarball the delta was made against)
curl -fL --retry 3 --retry-delay 10 -o linux-7.4-rc4.tar.gz https://github.com/torvalds/linux/archive/refs/tags/v7.4-rc4.tar.gz        # sha256 9f13091e6dd2d3576ad86e0c42ffa76b9993805a3f3a00f06981b242ea48aef9, 274538718 bytes
echo '9f13091e6dd2d3576ad86e0c42ffa76b9993805a3f3a00f06981b242ea48aef9  linux-7.4-rc4.tar.gz' | sha256sum -c      # stop here if this fails (GitHub answered 429 once: wait and retry)
tar -xf linux-7.4-rc4.tar.gz && cd linux-7.4-rc4
patch -p1 < ../kernel/u880-kernel-delta-7.4.patch && cp ../kernel/u880-7.4.config .config
```

Then build it with **one** of these:

```
# A) in the container / on a normal distribution with a clang 21 (Android r574158 or any 21.x), inside linux-7.4-rc4:
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e olddefconfig      # leaves .config equal to kernel/u880-7.4.config, except possibly the single line CONFIG_OPENSSL_SUPPORTS_ML_DSA when your OpenSSL is older than 3.5; the committed file is the reference
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image Image.gz modules
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e INSTALL_MOD_PATH=$PWD/../modules-out INSTALL_MOD_STRIP=1 modules_install

# B) NixOS without the container (Nix clang 21.1.8): from the REPO ROOT, with the tree's .config in place (it needs an x86_64 OpenSSL; the script fetches one if the store has none). It never runs olddefconfig, but the kernel's own config sync drops CONFIG_OPENSSL_SUPPORTS_ML_DSA with an OpenSSL older than 3.5 here too; harmless:
MODULES_OUT=$PWD/modules-out scripts/build-kernel-nix.sh linux-7.4-rc4        # (if you are still inside linux-7.4-rc4, `cd ..` first) builds Image, Image.gz, modules and runs modules_install into modules-out/
```


The 7.3.1 recipe (the same steps with its own files):

```
curl -LO https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz      # keep it in the repo root, it is git-ignored
echo 'fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231  linux-7.3.1.tar.xz' | sha256sum -c      # the file of the reference build
tar -xf linux-7.3.1.tar.xz
cd linux-7.3.1
patch -p1 < ../kernel/u880-kernel-delta.patch                                   # all our changes (about 220 files)
cp ../kernel/u880_defconfig arch/arm64/configs/
make LLVM=<clang>/bin/ ARCH=arm64 u880_defconfig                                # input is kernel/u880_defconfig; the resulting .config must equal kernel/u880.config
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e -j$(nproc) Image Image.gz modules
make LLVM=<clang>/bin/ ARCH=arm64 LOCALVERSION=-u880e INSTALL_MOD_PATH=$PWD/../modules-out INSTALL_MOD_STRIP=1 modules_install
```

`LOCALVERSION` **must stay pinned** (`-u880e`): the initramfs and the rootfs carry modules for that exact release and the display driver silently never probes otherwise
(FINDINGS F7). `KVER=7.4-rc4 scripts/clean-rebuild.sh` (or `KVER=7.3.1`) does the pristine-tarball rebuild (needs the AOSP clang or a clang 21 on `PATH`, or `CL=<clang bin dir>`; on NixOS run it where `build-kernel-nix.sh` finds its clang) and compares the result with a working tree (used to prove the delta is complete).
After you change anything under the tree, regenerate the delta: `python3 scripts/snapshot-kernel-delta.py <pristine 7.3.1 dir> linux-7.3.1`, or for 7.4: `SUFFIX=-7.4 python3 scripts/snapshot-kernel-delta.py <pristine linux-7.4-rc4 dir> linux-7.4-rc4`.

### 4. Device tree

`dts/u880.dts` is the production DTB as source (compiled sha256 `34c092d212292e0950475c10802f7f6bb8d7b63da090f79b1b698714fdfd4d50`, 514,171 bytes; up to 2026-11-26 it was 504,107 bytes, `5cc07ae5...`, before the microphone, camera, video, CDSP, TRNG, GPU and touch nodes) (it is the stock SoC DTB with our nodes: cooling maps, vibrator, audio, DP, display, thermal, ...). Compile it (checked 2026-11-27: the result is **byte-identical** to the DTB inside the tested image `boot-7.4rc4-gpu.img`, `cmp` clean, 514171 bytes; the camera clock controller is enabled in this file now):

```
# (back in the repo root: `cd ..` if you are still inside linux-7.4-rc4)
dtc -q -I dts -O dtb -o stage1/dtb2-u880.dtb dts/u880.dts        # same as: scripts/build-dtb-from-dts.sh (NixOS: nix-shell -p dtc --run "bash scripts/build-dtb-from-dts.sh")
# roundtrip check (tested 2026-11-26, prints SAME; the decompile prints harmless reg_format warnings):
dtc -I dtb -O dts stage1/dtb2-u880.dtb 2>/dev/null | dtc -q -I dts -O dtb 2>/dev/null | cmp - stage1/dtb2-u880.dtb && echo SAME
```

The ABL only accepts a DTB that contains the stock SoC structure (it applies the board overlay `dtbo` itself), which is why we start from the stock DT instead of a
minimal one (FINDINGS, `scripts/abl-oracle.sh`). Porting to a sibling tablet means extracting its own `dtb`/`dtbo` from its `vendor_boot` and `dtbo` partitions (`stock-dt/` shows how)
and re-applying our additions with `scripts/build-stock-disabled.sh` and the overlays in `stage1/*.dtso`. (That script is a porting tool and is not needed for this tablet: it expects `$M/linux-7.3.1/include` and the senemos-uke kernel tree `ref/senemos-uke-kernel-mainline/` next to the repo, which is not part of it.)

### 5. Initramfs

`stage1/initramfs/` holds the busybox `init` (v12). With `u880root=ufs` on the kernel command line it loads the three UFS modules from `lib/modules-ufs/`, mounts the partition whose GPT name is `archdata`, or failing that `userdata` (an old layout used it; on a stock layout `userdata` is Android's, the ext4 mount fails and init falls through; the filesystem label is not checked; no step creates `archdata`, step 8c item 2 formats `userdata` instead) and `switch_root`s;
with `u880root=sd,ufs` it tries the first partition of the SD card first and falls back to the internal root (README step 8a). With neither it is meant to give a rescue shell on the USB serial gadget (`usb0` 172.16.42.2). **On the 7.3/7.4 kernels this rescue is dead** (tested 2026-11-25): the USB PHY (`phy-qcom-qmp-combo`), `qcom_pmic_glink`, the eUSB2 repeater and the display clock (`dispcc-sm8550`) are modules that only the real root filesystem loads, so a rescue boot shows kernel text and then a black screen and never appears on the PC's USB. It has no `mkfs` or GNU `tar` either. Do not flash a rescue image unless those modules are in the initramfs.

The GPU firmware of step 7 must be in the initramfs too, so **do step 7 (at least the three `gen71100_*` files) before this one**, or build without it (`ALLOW_NO_GPU_FW=1`: boots, but nothing can render):

```
mkdir -p stage1/initramfs/lib/modules-ufs stage1/initramfs/lib/firmware/qcom
K=linux-7.4-rc4        # the tree of step 3 (only for the unstripped copies below)
MK=modules-out/lib/modules/7.4.0-rc4-u880e/kernel      # the stripped modules_install copies (about 200 KB, not 1.4 MB: keeps the initramfs fast); both recipes put them in <repo>/modules-out
cp $MK/drivers/ufs/host/ufs-qcom.ko $MK/drivers/soc/qcom/qcom_ice.ko $MK/drivers/phy/qualcomm/phy-qcom-qmp-ufs.ko stage1/initramfs/lib/modules-ufs/     # the unstripped ones of the tree ($K/drivers/...) also work
cp <gen71100_sqe.fw gen71100_gmu.bin gen71100_zap.mbn from step 7> stage1/initramfs/lib/firmware/qcom/
bash scripts/build-initramfs.sh          # -> stage1/initramfs.cpio.gz (it stops when one of the three .ko or one of the three GPU files is missing, and it creates `dev`, `proc`, `sys`, `newroot` and `tmp`, which git does not keep: without them `init` cannot mount anything)   (ALLOW_NO_GPU_FW=1 bash scripts/build-initramfs.sh: without the GPU firmware)
```

The three UFS modules must come from the same build/release as the kernel (a mismatch hangs at boot before the root mount: blue screen, no network).

### 6. Boot image

```
# run ONE of the two (different output names, so they cannot overwrite each other):
scripts/make-boot-image.sh stage1/dtb2-u880.dtb stage1/u880-boot-ufs.img            # u880root=ufs: root on the internal partition (an installed system)
ROOT=sd,ufs scripts/make-boot-image.sh stage1/dtb2-u880.dtb stage1/u880-boot-sd.img    # FIRST INSTALL: card first (step 8a), internal root as fallback
```

The script packs the **uncompressed** kernel `arch/arm64/boot/Image` (not `Image.gz`; the working image's kernel is the 46 MB `Image`; the packed boot image is 48 MiB, 50 MB), `stage1/initramfs.cpio.gz` and the DTB with `mkbootimg.py` (header v2, offsets `--base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000`, page size 4096) and the command line that every tested image used
(`console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=ufs cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=0x0 msm.u880_dbg2=0 fw_devlink.sync_state=timeout`, plus `apparmor=1 security=apparmor`, and `debugfs=off` unless `DEV=1`); the other `mkbootimg` arguments are `--header_version 2 --os_version 14.0.0 --os_patch_level 2024-03`.
Defaults and overrides: `ROOT` (`ufs` by default; `sd,ufs` tries an SD card first, step 8a), `KIMAGE` (kernel Image; default the newest `linux-7.4-rc4`/`linux-7.3.1` in the repo root), `RAMDISK` (default `stage1/initramfs.cpio.gz`), `MKBOOTIMG` (default `../LineageOS/system/tools/mkbootimg/mkbootimg.py`; `git clone https://android.googlesource.com/platform/system/tools/mkbootimg`), `CMDLINE`. **Do not hand-type the `mkbootimg` command**: a made-up kernel argument once boot-looped the tablet (CLAUDE.md).
When you replace an image of this project that already runs, compare the 4096-byte header of the new one with the installed one first (`unpack_bootimg.py`): only the size fields, the id hash and the ramdisk may differ. On a first install the installed `boot_a` is Android's (boot header v4 with an empty ramdisk), so there is nothing to compare with; unpack your own image and check the cmdline above instead.

There is no RAM boot on this unit: the fastboot that the key combination gives is XBL's and refuses `boot` and `flash` (FINDINGS F43, F40), so a bad image is repaired over EDL (step 0, FINDINGS F41), not by booting another one. Flash and fall-back handling are in step 9.

### 7. Firmware you must extract yourself

Vendor firmware is not redistributable and is **not** in this repo. Extract it from your own tablet's stock package (never someone else's copy). In the `U880_B14_V3.0L.1_0311.zip` of step 0 the partitions are **separate images in `images/`** (there is no `super.img`): `vendor.img`, `odm.img` and `dsp.img` are ext4 (read them with `debugfs -R "dump /firmware/<file> <out>" vendor.img`, or `mount -o ro,loop`), `modem.img` and `bluetooth.img` are **FAT** (`mdir -i modem.img ::/image`, `mcopy -i modem.img "::/image/qca6750/*" <dir>/`, from the `mtools` package; or `mount -o ro,loop`; as a normal user `debugfs` prints `Operation not permitted` while setting owners, harmless). Nothing needs to be run from the package. `odm.img` and `dsp.img` are in the package but no file of them is used here. Checked on 2026-11-26 against the files of the working tablet: every hash below matches. The table below lists where each file lives in the stock package and where it goes on the root filesystem. **Overlay layout:** the firmware overlay for `scripts/build-rootfs-image.sh` (`FWDIR`) is laid out like `/`, and on Arch `/lib` is a symlink to `usr/lib`, so the destination `/lib/firmware/qcom/x` below is `FWDIR/usr/lib/firmware/qcom/x` (the paths of `tablet-rootfs/FIRMWARE.sha256` use that form):

| Files | In the stock vendor tree | Destination on the tablet |
|---|---|---|
| Adreno 735: `gen71100_sqe.fw` (66036 B), `gen71100_gmu.bin` (80680 B), `gen71100_zap.mbn` (12088 B) | `vendor.img`: `/firmware/` | `/lib/firmware/qcom/`, **and** `stage1/initramfs/lib/firmware/qcom/` (step 5) |
| ADSP (battery/charging, sensors, audio): `adsp2.mdt` and the 56 other `adsp2*` files (identical to the tablet's, 57 of 57 hashes; Android's loader picks `adsp2`, not `adsp`) | `modem.img` (FAT): `/image/adsp2*` | `/lib/firmware/qcom/u880/` |
| Wi-Fi: the whole `qca6750/` directory (69 files, `bdwlan.elf` is the exact name of the board-data input, next to the `bdwlan.bNN` parts: `wpss.mdt`, `wpss.bNN`, `wpss.qdb`, `regdb.bin`, `bdwlan.*`) | `modem.img` (FAT): `/image/qca6750/` | `/lib/firmware/qca6750/` |
| Wi-Fi board file | build it (the result is bit-identical to the tablet's, sha256 `8c3955899101...`): `python3 scripts/make-ath11k-board2.py <fw>/qca6750/bdwlan.elf board-2.bin "bus=ahb,qmi-chip-id=1,qmi-board-id=255"` (writes `board-2.bin` to the current directory: copy it to the destination in your `FWDIR`) | `/lib/firmware/updates/ath11k/WCN6750/hw1.0/board-2.bin`; `regdb.bin` (the `qca6750/regdb.bin` of the row above) also to `/lib/firmware/ath11k/WCN6750/hw1.0/regdb.bin` |
| Video codec (Iris): `vpu30_2v.mbn` (2.3 MB, signed) | `vendor.img`: `/firmware/` | `/lib/firmware/qcom/vpu/` |
| Compute DSP: the 21 files `cdsp.mdt`, `cdsp.b00`-`b13` and `b15` (there is no `b14`), `cdsp_dtb.mdt`, `cdsp_dtb.b00`-`b02`, `cdspr.jsn` | `modem.img` (FAT): `/image/` | `/lib/firmware/qcom/u880/` |
| Bluetooth: `msbtfw12.mbn`, `msbtfw12.tlv`, `msnv12.bin` | `bluetooth.img` (FAT): `/image/` | `/lib/firmware/qca/` |
| Speaker amplifiers: `aw882xx_acf.bin` (2016 B) | `vendor.img`: `/firmware/` | `/lib/firmware/` |
| AudioReach topology `U880-tplg.bin` | **already in the repo** (`topology/U880-tplg.bin`, byte-identical to `tablet-rootfs/lib/firmware/qcom/sm8550/U880-tplg.bin`, installed by `tablet-rootfs/PATHS`) | `/lib/firmware/qcom/sm8550/` |

Without the `qca6750/` directory `ath11k` fails with `Direct firmware load for qca6750/wpss.mdt failed with error -2` and there is no `wlan0`. The base tarball also lacks `wireless-regdb`: install it in step 8b (`pacman -S wireless-regdb`), not here.
SHA-256 of the Adreno files of the reference tablet (stock firmware `U880_B14_V3.0L.1_0311`), to check you extracted the right ones:
`435c7bac9a328b8a100df930b84b65b4d579e42be44785d0e60e3729291bb864 gen71100_gmu.bin`, `b6df660d109504dbea5a266910b037a33d893a11c6de52f524a5fd112008c401 gen71100_sqe.fw`,
`966d2984e1ac7a86f9a25c66fab3fd660423396f1375baf4432db0f1d80f9485 gen71100_zap.mbn` (other firmware versions may differ). `tablet-rootfs/BLOBS` and `BLOBS.sha256` cover only the blobs that `scripts/tablet-config.sh` pulls from the tablet (the locally built `hexagonrpcd` files and a few firmware files). **`tablet-rootfs/FIRMWARE.sha256` is the check list for the whole overlay**: the sha256 of every stock-derived file (GPU, the Iris video firmware `vpu30_2v.mbn`, the 21 CDSP files, ADSP 57 files, `qca6750/` 69 files, Bluetooth, amplifier, `regdb.bin`, the built `board-2.bin`) with its path in the overlay; verify yours with `cd <FWDIR> && sha256sum -c <repo>/tablet-rootfs/FIRMWARE.sha256 --ignore-missing | grep -c ': OK$'` (it prints **157** for a complete overlay; `--ignore-missing` hides files that are absent, so count the OK lines).
The topology can only be rebuilt with the upstream `audioreach-topology` sources: `topology/audioreach/` holds our three U880 files (`u880-device-dp-playback.m4`, `u880-device-i2s-playback.m4`, `u880-stream-playback.m4`), but `topology/U880.m4` also includes the upstream base files `audioreach/audioreach.m4`, `stream-subgraph.m4`, `device-subgraph.m4`, `tokens.m4` and `util/route.m4`, `util/mixer.m4` from `https://github.com/linux-msm/audioreach-topology` (not copied here), and `alsatplg` compiles it; the committed binary is what was tested, so you do not need to.

**Sensors are a second pass, not part of the first image.** `hexagonrpcd`, `libhexagonrpc.so.0.5` and `chrecd` are ARM64 programs that were built on the tablet itself (upstream `https://github.com/linux-msm/hexagonrpc` plus `patches/u880/hexagonrpc-0001-u880-writable-registry-large-buffers.patch`; see `sensors/README.md`), so a first install has none of them: build them on the booted tablet with the base-devel/meson tools and install them to `/usr/local` (`/etc/ld.so.conf.d/usr-local.conf` is already in the mirror). The data they serve comes from your own tablet: `/usr/share/qcom/u880/{sensors,socinfo,persist-sensors}`. `/usr/share/qcom/u880/sensors/` on the tablet is `vendor.img:/etc/sensors` (not the repo's own `sensors/` directory, which holds notes and `tablet-config/`; the hexagonrpc patch is under `patches/u880/`) (checked: 74 of its 76 files are byte-identical to the working tablet's; of the other two, `hals.conf` (Android's HAL list) is simply **not installed** and `sns_reg_config` is installed under the name `sns_reg.conf`, content identical (`cmp` clean); nothing was edited. The tablet additionally has a `registry/` tree of 290 files that is **not** in the stock package: it is the `registry/registry/` directory of the tablet's own `persist` partition (on the tablet that is `persist:/sensors/registry/registry/`; the directory above it also holds `parsed_file_list.csv` and `sns_reg_version`; the reference notes keep a local, git-ignored copy under `sensors/persist/`, not in the repo), so it comes with the `persist-sensors` copy below; the patched `hexagonrpcd` only lets the sensors core rewrite it, and whether the core can build it from nothing was not tried). `socinfo/` is eight one-line text files (`family` = `Snapdragon`, `hw_platform` = `QRD`, `machine` = `CLIFFS7P`, `platform_subtype` = `Unknown`, `platform_subtype_id` = `0`, `platform_version` = `65536`, `revision` = `1.0`, `soc_id` = `643`; no vendor data, you can write them yourself), and **in short:** `/usr/share/qcom/u880/sensors/` = `vendor.img:/etc/sensors` (+ its `registry/` = persist's `sensors/registry/registry/`), `/usr/share/qcom/u880/persist-sensors` and the writable `/var/lib/hexagonrpcd/persist-sensors` = persist's whole `sensors/` directory; `persist-sensors` is the registry and calibration that Android generated into the tablet's own `persist` partition: it is not in the zip, so read it from the tablet (the `persist` backup of step 0.3, or EDL `r persist`, or mounted read-only; copy the partition's `sensors/` directory) before Android is gone and a writable copy at `/var/lib/hexagonrpcd/persist-sensors`, owned by the system user `fastrpc` (uid/gid 961, created by `scripts/build-rootfs-image.sh`).
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
2. **Firmware overlay (`FWDIR`).** A directory laid out like `/` that holds **only** the vendor files of step 7 (the paths of `tablet-rootfs/FIRMWARE.sha256`: the files of the table in step 7, the `u880/adsp2.*` set, `qca6750/` as a whole directory; `tablet-rootfs/BLOBS` also lists the blobs built on the tablet later, which are not part of it). **Do not copy whole directories of distro-owned firmware** (`qca/`, `ath11k/`): `pacman -Syu` later stops with `linux-firmware-atheros: /usr/lib/firmware/qca/... exists in filesystem`.
3. **Image.** As root, with `bsdtar` (libarchive) installed so that file capabilities (`ping`, `newuidmap`) survive; GNU `tar` prints `Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.security.capability'` and drops them:
   ```
   sudo TARBALL=ArchLinuxARM-aarch64-latest.tar.gz MODULES=<modules_install dir>/lib/modules/<release> FWDIR=<overlay> \
        SSH_PUBKEY=~/.ssh/id_ed25519.pub ROOT_LABEL=u880root scripts/build-rootfs-image.sh rootfs.img
   ```
   (on NixOS: `sudo nix-shell -p libarchive --run '...'` with absolute paths; `$HOME` becomes `/root` under sudo.) It unpacks the tarball, installs the modules and runs `depmod`, copies the overlay, installs everything listed in `tablet-rootfs/PATHS` (the offline equivalent of `tablet-config.sh push`; the mirror's home directory becomes `/home/alarm`), enables the project's units and a first-boot `u880-growfs.service`, and writes a 10 GB sparse ext4 image. Use another `ROOT_LABEL` (for example `u880sdtest`) when the tablet still has another root labelled `u880root`: fstab, growfs and the read-only udev rule all key on it. The tarball's default logins `alarm/alarm` and `root/root` stay: change them before the tablet joins a network.
4. **Shrink it** (the card is the slow part): `cp --sparse=always rootfs.img min.img; e2fsck -f min.img; resize2fs -M min.img; truncate -s $((BLOCKS*4096)) min.img` (`BLOCKS` from `dumpe2fs -h`). A 10 GiB image shrinks to about 3.6 GB.
5. **Write the card on the PC** (not in the tablet, whose slot wrote a slow card at 1 to 2 MB/s where the PC reader did 13 MB/s): `sudo bash scripts/write-sd-image.sh min.img /dev/sdX`. It refuses non-removable or mounted devices, partitions the card, writes the image, compares the sha256 of the written bytes, runs `e2fsck` and grows the filesystem to the whole card.
6. **Boot image that tries the card first.** `ROOT=sd,ufs scripts/make-boot-image.sh stage1/dtb2-u880.dtb stage1/u880-boot-sd.img` (the default command line with `u880root=sd,ufs` instead of `u880root=ufs`). `u880root=sd,ufs` makes `init` v12 mount `mmcblk1p1` first and fall back to the internal root when that fails, so a bad card cannot strand the tablet in the dead rescue. **Do not make the SD wait longer than a few seconds in `init`**: with no card the internal root then mounted 21 s late, `dispcc` (a module of the root filesystem) came after `fw_devlink.sync_state=timeout`, and the display never probed (black screen, ssh fine). Flash it as in step 9.
7. **Card notes.** A card that fails with `mmc1: tuning execution failed: -110` / `DLL failed to LOCK` / `error -110 whilst initialising SD card` cannot do the 200 MHz mode on this board (two of three cards tried). Mask the fast modes in the SD node of the DTB and it runs at high speed (about 24 MB/s read): `fdtput -t x dtb /soc/sdhci@8804000 sdhci-caps-mask 3 0` (`<0x3 0x0>`: SDR50 and SDR104 off). **The mask applies to every card**, also fast ones, so remove it again when your card does not need it.

### 8b. First boot of the fresh system, and the install that needs a reboot in the middle

Boot with the card in. About 6 s of `init`, then Arch Linux ARM: display, USB networking and `sshd` are up (the very first boot can take minutes on a slow card). Then, over USB (step 7b):

1. `ssh root@172.16.42.2` (key from `SSH_PUBKEY`, or `alarm/alarm`), set the date (step 7b).
2. **Wi-Fi firmware and clock.** Without `/lib/firmware/qca6750/` (`wpss.mdt`, `wpss.bNN`, `wpss.qdb`, `regdb.bin`) the log says `remoteproc0: Direct firmware load for qca6750/wpss.mdt failed with error -2`, `ath11k ... probe with driver ath11k failed with error -2`, and there is no `wlan0`. If you copied the files after boot: `echo start > /sys/class/remoteproc/remoteproc0/state`, or reboot.
3. `pacman-key --init && pacman-key --populate archlinuxarm`.
4. **System upgrade, then reboot immediately:** `pacman -Syu --noconfirm --disable-download-timeout` (add `--overwrite '/usr/lib/firmware/qca/*'` etc. if step 8a.2 was not followed). It replaces `systemd`, `glibc`, `openssl` and `openssh` under the running system: afterwards new ssh sessions are reset before the banner (`kex_exchange_identification: Connection reset by peer`), the console shows `udev socket overridden while running` and `failed to send WATCHDOG=1 notification`. **Wait until the post-transaction hooks have finished (the log ends with the hooks list, and `pgrep pacman` is empty), then reboot.** Rebooting earlier leaves `/var/lib/pacman/db.lck` and half-run hooks (the log stops at `running '20-systemd-sysusers.hook'...`); repair with `rm /var/lib/pacman/db.lck; systemd-sysusers; systemd-tmpfiles --create; systemd-hwdb update; ldconfig; update-ca-trust`.
5. **Packages:** the list of step 8c.6 plus `wireless-regdb` and `sddm`: about 660 packages, 800 MB to download, 3.8 GB installed. Run it detached (`systemd-run --unit=pkgs --property=StandardOutput=append:/root/pkg.log /root/script.sh`), because the connection can drop and the card can be slow. Do not reboot while it runs.
6. **Extra packages and services that the package list of step 8c.6 does not name** but the working system has: `earlyoom tuned tuned-ppd` (`apparmor upower avahi` come in as dependencies), and **`vulkan-freedreno`** (the Turnip Vulkan driver is a separate package from `mesa`; without it there is no Vulkan device and Steam/Proton games cannot run) and `alsa-utils` (`aplay`, `amixer`, `alsaucm`, `arecord`). **Camera and video (2026-11-27, F53/F54; names checked with `pacman -Q` on the reference tablet 2026-11-27: the seven camera packages and `mpv` were installed by hand, `ffmpeg`, `gst-plugins-good` and `v4l-utils` came in as dependencies; not re-run on a fresh image):** `libcamera libcamera-ipa libcamera-tools pipewire-libcamera gst-plugin-libcamera gst-plugin-pipewire plasma-camera` for the cameras (libcamera's software ISP runs on the GPU and needs `/dev/dma_heap/system`: the mirror has `modules-load.d/u880-camera.conf`, the udev rules for the heap and the flash LED, and AppArmor profiles for PipeWire and WirePlumber that allow `/dev/video*`, `/dev/media*` (with `k`), `/dev/dma_heap/system` and the render node), and `ffmpeg gst-plugins-good v4l-utils` (dependencies, listed so that you check them) and `mpv` for hardware video, with the line `hwdec=v4l2m2m-copy` in `~/.config/mpv/mpv.conf` (a user file, not in the mirror). Skip the useless initramfs generation for the distro kernel, which writes two 15 MB+ images to the card for 30+ minutes and is not used (our boot image carries its own ramdisk): `mkdir -p /etc/pacman.d/hooks; ln -sf /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook` **before** step 5. If it is already running, kill `mkinitcpio` **and its orphaned `find`/`grep` children**, which keep the hook's pipe open and block `pacman`.
7. **Enable the services** (the image build only enables those whose packages are in the base tarball): `systemctl enable NetworkManager NetworkManager-wait-online bluetooth apparmor upower sddm earlyoom tuned tuned-ppd sensord u880-thermal-guard u880-bt-connectable u880-zram u880-gpu-sample serial-getty@ttyGS0`; the user unit `u880-autobrightness` (ambient-light brightness through `iio-sensor-proxy` and PowerDevil) is enabled by `scripts/build-rootfs-image.sh` for every user. **`u880-thermal-guard` is not optional**: the die heats 2.5 to 5 C/s and the device-tree cooling maps alone do not protect it; do not load-test before it runs.
8. Continue with step 8c (passwords, session flags), step 9 and step 10. `tablet-config.sh push` is already done by the image build, **but only for the files listed in `tablet-rootfs/PATHS`**: 10 tracked files (thermal guard, `u880-bt-connectable`, vibrator modules, suspend log, `u880-rumble`, `steam-arm64-gs`, the HDMI UCM file) were missing from that list until 2026-11-26; `comm -23 <(cd tablet-rootfs && git ls-files . | sed 's#^#/#' | sort) <(grep -vE '^\s*(#|$)' tablet-rootfs/PATHS | sort)` must only show `PATHS`, `BLOBS*`, `FIRMWARE.sha256`, `/etc/environment` and `/etc/u880-bt-addr` (the owner's own Bluetooth address, never copy it).

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
cat stage1/u880-boot-ufs.img | ssh root@<tablet> 'cat > /root/boot.img'
ssh root@<tablet> 'dd if=/dev/sde40 of=/root/u880-backup/boot_b-before.img bs=4M;            # sde40 = boot_b on the reference tablet
   blockdev --setrw /dev/sde /dev/sde40; dd if=/root/boot.img of=/dev/sde40 bs=4M conv=fsync; sync;
   blockdev --setro /dev/sde40 /dev/sde; head -c $(stat -c %s /root/boot.img) /dev/sde40 | sha256sum'
```

Check the hash against the image, then reboot. `scripts/gpt-mark-successful.py` marks a slot successful after `set_active` (see FINDINGS F13/F18). The partition names/devices are those of the reference
tablet: check yours with `ls -l /dev/disk/by-partlabel/` before writing anything. `scripts/flash-boot-b.sh` automates the first flash through an Android detour.

### 10. Verify

On the tablet: `uname -r` is `<release>` (`7.4.0-rc4-u880e` or `7.3.1-u880e`); `ls /sys/class/drm` shows `card1-DSI-1`; `dmesg | grep "UBWC programmed"` shows `STATIC=0x103e CTRL_2=0x2 PRED=0x1`;
`modetest -M msm -p` lists the four refresh modes; thermal zones show the cooling maps (`ls /sys/class/thermal/thermal_zone*/trip_point_*_temp`); `bluetoothctl show` has the factory address;
`iio-sensor-proxy` sees accelerometer and light; `cat /proc/asound/pcm` lists `MultiMedia3 Capture` and `alsaucm -c U880 set _verb HiFi set _enadev Mic && arecord -D hw:0,2 -f S16_LE -r 48000 -c 2 -d 2 /tmp/mic.wav` records (F52); `cam -l` shows `gc05a2` and `ov13b10`, `cam -c 1 --capture=5` runs at about 27 fps with the screen on (F53); `ls /dev/fastrpc-cdsp /dev/video*` and `cat /sys/class/misc/hw_random/rng_available` (has `qcom_hwrng`); `pactl list short sinks` has `HiFi__Speaker__sink`; `scripts/dpms-fuzz.sh 100 200 4000` finishes without a wedge. Stress and game checks: `scripts/stress-run.sh`, `scripts/game-profile.sh`.

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
