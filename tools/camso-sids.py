#!/usr/bin/env python3
"""Decode the I2C address and chip-ID check of the stock CamX module configs.

The ParamFile ("com.qti.sensormodule.*.bin") stores a register write as u32:
<type=4> <8-bit SID> <reg-addr-len> <data-len> <reg> <value>. In every config of
this vendor image exactly one such entry exists, the chip-ID check of the
sensorDriverData "Default" block. There are no power-up records in these files (2026-11-02: scanning every 4-byte offset of a config finds exactly one such record, and
no section is named `powerUpSeq` - that lead is closed, see FINDINGS F37), so the address set below is what the stack *addresses*, not every write it
ever makes (the AF address comes from the actuator driver, not from these files).
It also lists the ParamFile sections of each config: an EEPROM-less module config
has no EEPROMDriverData section, which is part of the evidence that the devices at 0x50/0x58 are not vendor-configured (the other part: no `qcom,cam-eeprom` node exists
in stock-dt/o25.dts at all).

usage: tools/camso-sids.py logs/camso   (files dumped from vendor.img by debugfs)
"""
import sys, os, re, struct, collections

SECT = re.compile(rb'(?:^|[^A-Za-z_])(sensorDriverData|cameraModuleData|actuatorDriver|flashDriverData|OISDriver[a-zA-Z]*|[A-Za-z]*[Ee][Ee][Pp][Rr][Oo][Mm][A-Za-z]*|Default)\x00')

def scan(path):
    b = open(path, 'rb').read()
    names = sorted({m.group(1).decode() for m in SECT.finditer(b)})
    sects = [(m.start(), m.group(1).decode()) for m in SECT.finditer(b)]
    out = collections.OrderedDict()
    for i in range(0, len(b) - 24, 4):
        t, sid, rl, dl = struct.unpack_from('<4I', b, i)
        if t != 4 or not (0 < sid < 0x100) or rl not in (1, 2) or dl not in (1, 2, 4):
            continue
        reg, val = struct.unpack_from('<2I', b, i + 16)
        if rl == 2 and reg > 0xFFFF:
            continue
        sec = max([s for s in sects if s[0] < i], key=lambda s: s[0])[1] if sects else '?'
        k = (sid, sec)
        if k not in out:
            out[k] = [0, reg, val]
        out[k][0] += 1
    return out, names

d = sys.argv[1]
agg = collections.defaultdict(set)
for f in sorted(os.listdir(d)):
    hits, names = scan(os.path.join(d, f))
    print(f"{f[20:-4]:28} sections: {' '.join(names)}")
    for (sid, sec), (n, reg, val) in hits.items():
        print(f"{f[20:-4]:28} {sec:18} 8bit 0x{sid:02x}  7bit 0x{sid>>1:02x}  n={n:5}  ex {reg:#06x}={val:#010x}")
        agg[sid >> 1].add(f[20:-4])
print("\nAll 7-bit addresses in", d)
for a in sorted(agg):
    print(f"  0x{a:02x}  {len(agg[a])} files")
