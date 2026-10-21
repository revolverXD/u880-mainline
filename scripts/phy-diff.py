#!/usr/bin/env python3
"""Compare DSI PHY registers: Android (vendor debugfs dumps) vs ours (u880-display/live), per link.

usage: scripts/phy-diff.py <our-live-dump> [start] [end]
  offsets are PHY-relative hex, default 0 c00 (whole block is 0xa00)
Android files: display/regs/android/dsi{0,1}_phy.txt  ("0x000000c0: v0 v1 v2 v3")
Our file: "0ae95000 20080000" lines, PHY0 = 0xae95000, PHY1 = 0xae97000.
"""
import re, sys

M = "/home/USER/External/work/src/mainline"

def load_android(path):
    regs = {}
    for line in open(path):
        m = re.match(r"\s*0x([0-9a-fA-F]+):\s+(.*)", line)
        if not m:
            continue
        base = int(m.group(1), 16)
        for i, v in enumerate(m.group(2).split()):
            regs[base + 4 * i] = int(v, 16)
    return regs

def load_live(path, base):
    regs = {}
    for line in open(path):
        m = re.match(r"([0-9a-fA-F]{8}) ([0-9a-fA-F]{1,8})", line)
        if not m:
            continue
        a = int(m.group(1), 16)
        if base <= a < base + 0xa00:
            regs[a - base] = int(m.group(2), 16)
    return regs

live = sys.argv[1]
start = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x0
end = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xa00

a0 = load_android(f"{M}/display/regs/android/dsi0_phy.txt")
a1 = load_android(f"{M}/display/regs/android/dsi1_phy.txt")
o0 = load_live(live, 0xAE95000)
o1 = load_live(live, 0xAE97000)

print(f"{'off':>6} {'android0':>9} {'ours0':>9} {'android1':>9} {'ours1':>9}  note")
for off in sorted(set(a0) | set(a1) | set(o0) | set(o1)):
    if not (start <= off <= end):
        continue
    v = [a0.get(off), o0.get(off), a1.get(off), o1.get(off)]
    if len({x for x in v if x is not None}) <= 1:
        continue
    fmt = lambda x: f"{x:08x}" if x is not None else "  --   "
    note = []
    if v[0] != v[1] and v[2] == v[3]:
        note.append("link0-only diff")
    if v[2] != v[3] and v[0] == v[1]:
        note.append("link1-only diff")
    if v[0] != v[1] and v[2] != v[3] and (v[0] == v[2] or v[1] == v[3]):
        note.append("both links differ from android")
    if (v[0] is not None and v[1] is not None and abs(v[0] - v[1]) <= 2) and \
       (v[2] is not None and v[3] is not None and abs(v[2] - v[3]) <= 2):
        note.append("trim-level (+-2)")
    print(f"{off:#06x} {fmt(v[0])} {fmt(v[1])} {fmt(v[2])} {fmt(v[3])}  {' '.join(note)}")
