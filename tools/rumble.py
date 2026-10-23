#!/usr/bin/env python3
# Rumble the first force-feedback input device named pm8xxx_vib_ffmemless. usage: rumble.py [strong 0-65535] [ms]
import fcntl, glob, os, struct, sys, time
strong = int(sys.argv[1]) if len(sys.argv) > 1 else 0xFFFF
ms = int(sys.argv[2]) if len(sys.argv) > 2 else 800
dev = next(f"/dev/input/{os.path.basename(p)}" for p in glob.glob("/sys/class/input/event*")
           if open(p + "/device/name").read().strip() == "pm8xxx_vib_ffmemless")
fd = os.open(dev, os.O_RDWR)
# struct ff_effect: type, id, direction, trigger{button,interval}, replay{length,delay}, 2 bytes pad, union at offset 16 (rumble: strong, weak), 48 bytes total
eff = struct.pack("HhHHHHHxxHH", 0x50, -1, 0, 0, 0, ms, 0, strong, 0).ljust(48, b"\0")
buf = bytearray(eff)
fcntl.ioctl(fd, 0x40304580, buf)  # EVIOCSFF
eid = struct.unpack("h", bytes(buf[2:4]))[0]
os.write(fd, struct.pack("llHHi", 0, 0, 0x15, eid, 1))  # EV_FF play
time.sleep(ms / 1000 + 0.3)
fcntl.ioctl(fd, 0x40044581, eid)  # EVIOCRMFF
print("played", dev, "strong", strong, "ms", ms)
