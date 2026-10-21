#!/usr/bin/env python3
"""Read the same display registers as /sys/kernel/debug/u880-display/live, straight from /dev/mem.
Works in a boot that never binds msm (separate_gpu_kms=1), i.e. in the working simpledrm state.
Same ranges and same "0ae94010 02009230" output as uke-mdss-handoff.c, so the two dumps diff directly.
Run as root on the tablet, only while the display is on: unclocked blocks can hang the SoC.
"""
import mmap, struct, sys

# INTF1, INTF2, DSI0, PHY0, DSI1, PHY1, dispcc RCGs. PP/DSC and DSC are left out: reading them reset the SoC.
R = [(0xAE36000, 0x300), (0xAE37000, 0x300), (0xAE94000, 0x400), (0xAE95000, 0xA00),
     (0xAE96000, 0x400), (0xAE97000, 0xA00), (0xAF08000, 0x300)]

f = open("/dev/mem", "rb")
for phys, ln in R:
    m = mmap.mmap(f.fileno(), ln, mmap.MAP_SHARED, mmap.PROT_READ, offset=phys)
    for off in range(0, ln, 4):
        print("%08x %08x" % (phys + off, struct.unpack_from("<I", m, off)[0]))
    m.close()
