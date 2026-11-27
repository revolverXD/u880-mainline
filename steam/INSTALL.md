# Steam (native ARM64), launchers and extra Proton builds on the U880

This is the install guide for games on the finished system (README steps 0-10 done, Arch Linux ARM + Plasma Mobile running, GPU working: `vulkaninfo --summary` shows `Turnip Adreno (TM) 735`).
It describes what is on the reference tablet. The pieces were each run there; **this guide as one script was not re-run from an empty home directory**, and a few spots below say so.
The older route (x86 Steam under FEX) is in `steam/README.md`; the notes of how the native client was first assembled are in `steam/README-arm64.md`.

Everything below runs **as your normal user on the tablet** (not root) unless it says `root`. `$HOME` is that user's home. Games and Proton builds are big (2 GB per Proton build, 1 GB for the client): put them on a card or on the internal disk with room; examples use `$HOME/sd` for a card.
Send the files of this directory to the tablet first, for example `scp steam/{fetch-arm64.sh,unpack-arm64.py,arm64-packages.txt,fetch-proton.sh} <user>@<tablet>:`.
The scripts in this directory were written with the owner's home directory in them (`/home/USER/` in the private repo, `/home/USER/` in the public copy). Replace it once, on the tablet, in the files you copied:
`sed -i -E "s#/home/(USER|USER)/#$HOME/#g" fetch-arm64.sh fetch-proton.sh`.

## 1. Host packages

As root:

```
pacman -S --needed openal ibus lsof libxcrypt-compat lsb-release zenity alsa-plugins xorg-fonts-misc xorg-xrandr gamescope vulkan-freedreno alsa-utils
```

(These are the dependencies of Arch's x86 `steam` package that the native client also wants, plus `gamescope` and the Turnip Vulkan driver, which is a separate package from `mesa`. Versions on the reference tablet: gamescope 3.17.0, mesa/vulkan-freedreno 26.3.1.)
`alsa-plugins` is needed so that ALSA's `default` goes to PipeWire; without it the Steam UI logs `PcmOpen default: Host is down`.

## 2. Install the native ARM64 Steam client

Valve ships a Linux ARM64 Steam client, but not as an installer; it is assembled from its update manifest (`https://client-update.steamstatic.com/steam_client_linuxarm64`). `arm64-packages.txt` lists the 35 packages (`name|file|sha256`).

```
D=$HOME/steam-arm
bash fetch-arm64.sh arm64-packages.txt      # downloads into $D/pkgs, ~1 GB, checks every sha256 (the script also unzips each package into `$D/root`; run the next step in any case, it restores the paths and modes)
python3 unpack-arm64.py $D/pkgs $D/root     # the zips use backslash paths and carry no unix modes: this script fixes both and makes the ELF programs and scripts executable
```

Then three fixes:

1. **libpng:** Arch's current libpng (1.6.59) crashes Big Picture (`png_create_info_struct` from `friendsui.so`). Put an older **libpng16 arm64** from Ubuntu 24.04 in `$D/root/steamrtarm64/libs/libpng16.so.16`. The reference tablet has 1.6.47 there; the current Ubuntu pool at `https://ports.ubuntu.com/pool/main/libp/libpng1.6/` lists `libpng16-16t64_1.6.50-1ubuntu0.5_arm64.deb` (not tried): unpack the `.deb` with `bsdtar -xf <deb> data.tar.zst` or `ar x`, take the real file `usr/lib/aarch64-linux-gnu/libpng16.so.16.*` and copy it under the name `libpng16.so.16`.
2. **Symlinks** (Steam looks for these under its data directory `~/.local/share/Steam`, which the x86 client would share):
   ```
   mkdir -p ~/.steam ~/.local/share/Steam
   ln -sfn $D/root/linuxarm64   ~/.local/share/Steam/linuxarm64
   ln -sfn $D/root/linuxarm64   ~/.local/share/Steam/sdkarm64
   ln -sfn $D/root/steamrtarm64 ~/.local/share/Steam/steamrtarm64
   ln -sfn $D/root/linuxarm64   ~/.steam/sdkarm64
   ```
3. **Launcher:** `steam/steam-arm64` (see the next section; it is `/usr/local/bin/steam-arm64`). It sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS` for the user (the values inherited from a root shell break pressure-vessel with `bwrap: Can't find source path /run/user/0/bus`) and restarts the client when it exits with code 42, which is how Steam asks to restart after a self-update.

First start: run `steam-arm64` from the Plasma session (or `steam-arm64-gs-1280`, section 3). It **self-updates (about 670 MB) and restarts itself**. Log in. The native client then offers, by itself, Valve's tools **Proton Experimental (ARM64)** (tool 4427310), **Steam Linux Runtime 4.0 for arm64** (4185400) and a **FEX-Emu** tool; install them from the library (Tools filter) or they download when a game first needs them.
Known: the Steam overlay does not work (`gameoverlayrenderer.so` preload fails in the logs; harmless). The client is much lighter than the emulated x86 one (UI in seconds; the CPU idles near 46 C instead of peaking at 99 C).

## 3. The launchers (desktop and gamescope)

Three small files, all in the config mirror (`tablet-rootfs/PATHS`), so `TABLET_USER=<user> scripts/tablet-config.sh push` (or the image build, README step 8a) installs them with your user name filled in. By hand:

| File | Where | What it does |
|---|---|---|
| `steam/steam-arm64` | `/usr/local/bin/steam-arm64` (root, mode 755) | starts the client directly on the current Plasma session (`STEAMROOT=$HOME/steam-arm/root`, `LD_LIBRARY_PATH` = the client's own libraries, `GDK_BACKEND=x11`, `LD_PRELOAD=libXrandr.so.2`) |
| `steam/steam-arm64-gs` | `/usr/local/bin/steam-arm64-gs` | the same client inside `gamescope -f -W 2560 -H 1600` (the panel's native size) |
| `steam/steam-arm64-gs-1280` | `/usr/local/bin/steam-arm64-gs-1280` | inside `gamescope -f -W 1280 -H 800 -w 1280 -h 800`: the compositor scales the 1280x800 window up to the panel, which costs the GPU much less in games |

**Why gamescope at all:** the Denial shell does not draw Xwayland override-redirect windows, so Steam's X11 pop-up menus (View menu and others) do nothing there. `gamescope` has its own Xwayland that draws them. The owner also runs the plain `steam-arm64` directly in the Plasma session; which of the two is better for you depends on whether you need those menus.

Desktop entries (so they appear in the launcher, as the user, in `~/.local/share/applications/`):

```
# steam-arm64.desktop            (steam-arm64-gs-1280.desktop is the same with its own Name/Exec)
[Desktop Entry]
Name=Steam (native ARM64)
Comment=Valve's native Linux ARM64 Steam client
Exec=/usr/local/bin/steam-arm64
Icon=steam
Terminal=false
Type=Application
Categories=Game;
```

The repo has `tablet-rootfs/home/*/.local/share/applications/steam-arm64.desktop`, `steam-arm64-gs-1280.desktop` (and the old `steam-x86.desktop`) to copy. Run `update-desktop-database ~/.local/share/applications` afterwards if the entries do not show up.

**Per-game shortcuts:** Steam's "Add desktop shortcut" writes entries like `Exec=steam steam://rungameid/1245620` into `~/.local/share/applications/`. There is **no `steam` command on this system's `PATH`** (checked on the reference tablet 2026-11-27), so those entries only work once you add one: as root, `ln -s /usr/local/bin/steam-arm64 /usr/local/bin/steam` (not tried; or edit the `Exec=` lines to `/usr/local/bin/steam-arm64 steam://rungameid/<appid>`). If Steam is already running, the second call hands the URL to the running client.

**Known issue in gamescope (2026-11-27):** a game started under `steam-arm64-gs*` can print `CreateSwapchainKHR: Creating swapchain for non-Gamescope swapchain.` (the text is in `libVkLayer_FROG_gamescope_wsi_aarch64.so`; not found in the Proton log or the journal), and the owner reports that the problem does not happen outside gamescope. The cause is not established. If a game misbehaves in gamescope, start Steam with `steam-arm64` instead.

## 4. More Proton builds (DroidDeck, GE-Proton for ARM64)

Valve's `Proton Experimental (ARM64)` comes with the client. Two community builds for ARM64 are used on the reference tablet:

| Build | Release page | Archive name |
|---|---|---|
| DroidDeck-Proton | `https://github.com/Droid-Deck/DroidDeck-Proton/releases` | `DroidDeck-Proton-<ver>-aarch64.tar.gz` (+ `.sha512sum`) |
| GE-Proton for ARM64 | `https://github.com/GloriousEggroll/proton-ge-custom/releases` | `GE-Proton<ver>-aarch64.tar.gz` (+ `.sha512sum`) |

`steam/fetch-proton.sh` downloads one release of each, checks the `.sha512sum` and unpacks into `~/.local/share/Steam/compatibilitytools.d/`. **Edit the two `get ...` lines at its end to the versions you want** (the file has `DroidDeck-Proton-11-12.8` and `GE-Proton11-14`, the ones the reference tablet used on 2026-11-24; open the release pages for newer tags). Then:

```
bash fetch-proton.sh         # ~2 GB per build; prints "ok <name>" per build
```

To keep the builds on a card (they are 2 GB each) unpack them there and link them in, which is what the reference tablet does:

```
mkdir -p ~/sd/compatibilitytools.d
tar -xzf GE-Proton11-14-aarch64.tar.gz -C ~/sd/compatibilitytools.d
ln -sfn ~/sd/compatibilitytools.d/GE-Proton11-14-aarch64 ~/.local/share/Steam/compatibilitytools.d/GE-Proton11-14-aarch64
```

Then **restart Steam** (it only lists tools at start). Per game: Library > right-click the game > Properties > Compatibility > "Force the use of a specific Steam Play compatibility tool" and pick the build. Note that the DroidDeck 11-12.8 archive unpacks to a directory with a space in its name (`DroidDeck-Proton 11-12.8`); Steam handles it.

What to expect:
- **The first launch with a new build is slow** (the reference tablet: under a minute from the click to `Balls.exe` on a card), because Steam creates a new Wine prefix for that game and copies about 400 MB into `steamapps/compatdata/<appid>/`. On a slow card the first Python step of Proton sits in disk wait: do not click again. Check progress with `tail -f ~/steam-<appid>.log` (needs the launch option below).
- **Debug a game that does not start:** set the launch option `PROTON_LOG=1 %command%`; the log is `~/steam-<appid>.log`. The first lines name the Proton build and the command; an `err:` line in the log is the place to start. If the log stops after about 18 lines, Wine has not started yet.
- **Anti-cheat games:** Easy Anti-Cheat titles (for example Elden Ring) did not start on `Proton Experimental (ARM64)` on 2026-11-27: the launcher `start_protected_game.exe` runs and exits without loading the EAC modules, and the ARM64 `proton` script has no EAC runtime handling. Not tried with the other builds.
- **Tool names matter:** the directory name under `compatibilitytools.d` is what Steam shows; do not rename a build after you assigned it to games.

## 5. Gamemode

`pacman -S gamemode`, and keep the repo's `tablet-rootfs/etc/gamemode.ini` (pins the `schedutil` governor; the default `performance` would overheat this die). Start a game with the launch option `gamemoderun %command%`. MangoHud is not packaged for Arch Linux ARM; it was not built here.

## What was and was not tested

Tested on the reference tablet: the whole chain above as it stands today (client, both gamescope sizes, three Proton tools, games from the SD card: 10 Minutes Till Dawn and Borderlands 2 run (README table); BALL x PIT started with GE-Proton11-14 (`Balls.exe` loaded, DXVK and Turnip initialised; gameplay not checked by me).
Not re-run from empty: sections 1-2 as one sequence on a fresh home directory, the libpng replacement with a package that is in the pool today, the `steam` symlink, and the per-game shortcuts.
