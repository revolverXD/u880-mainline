#!/usr/bin/env python3
# Decode qcom,mdss-dsi-*-command properties (dtc printed as 32-bit cells) from a panel node dump.
# Packet format: type, last, vc, ack, wait_ms, len_hi, len_lo, payload[len]. usage: decode-panel-cmds.py node.dts
import re, sys
text = open(sys.argv[1]).read()
for name, cells in re.findall(r'(qcom,mdss-dsi-[\w-]*command) = <([^>]*)>;', text):
    b = b''.join(int(c, 16).to_bytes(4, 'big') for c in cells.split())
    print(f'# {name}')
    i = 0
    while i + 7 <= len(b):
        t, last, vc, ack, wait, n = b[i], b[i+1], b[i+2], b[i+3], b[i+4], (b[i+5] << 8) | b[i+6]
        p = b[i+7:i+7+n]
        print(f'{t:02x} last={last} wait={wait:3d}  {p.hex(" ")}')
        i += 7 + n
    assert i == len(b), (name, i, len(b))
