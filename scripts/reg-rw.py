#!/usr/bin/env python3
"""Read or write one 32-bit SoC register through /dev/mem. Run as root on the tablet.
usage: reg-rw.py <hexaddr> [<hexaddr>=<hexvalue> ...]"""
import mmap, struct, sys

PAGE = 4096

def touch(addr, value=None):
    ln = 4096
    off = addr % PAGE
    phys = addr - off
    with open("/dev/mem", "rb" if value is None else "r+b") as f:
        m = mmap.mmap(f.fileno(), ln, mmap.MAP_SHARED,
                      mmap.PROT_READ | (mmap.PROT_WRITE if value is not None else 0), offset=phys)
        if value is not None:
            m[off:off + 4] = struct.pack("<I", value)
        v = struct.unpack_from("<I", m, off)[0]
        m.close()
    return v

for a in sys.argv[1:]:
    addr, sep, val = a.partition("=")
    addr = int(addr, 16)
    v = touch(addr, int(val, 16) if sep else None)
    print("%08x %08x" % (addr, v))
