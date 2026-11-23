#!/usr/bin/env python3
"""Mark an A/B slot 'successful' in the Qualcomm GPT of the boot LU (sde): set bit 6 of attribute byte 6 of the boot_<slot> entry,
in BOTH the primary and the backup GPT, fixing entry-array and header CRCs. Run on the tablet as root.
usage: gpt-mark-successful.py /dev/sde boot_b|active [--clear] [--write]   (default: dry run, prints what would change)
  `active` = whichever of boot_a/boot_b has the active bit (0x04); a no-op if it is already successful.
  `--clear` = the opposite: mark the slot NOT successful with a full retry count (0x38), so that ABL counts failed boots of a new image
  down and falls back to the other slot after 7 (a slot that is marked successful is never counted down: ABL just stops in fastboot)."""
import struct, sys, os, zlib
dev, part = sys.argv[1], sys.argv[2]; write = '--write' in sys.argv; clear = '--clear' in sys.argv
SEC = 4096
fd = os.open(dev, os.O_RDWR if write else os.O_RDONLY)
total = os.lseek(fd, 0, os.SEEK_END) // SEC
def rd(lba, n=1): return os.pread(fd, SEC * n, lba * SEC)
def hdr(lba):
    h = bytearray(rd(lba)[:92]); assert h[:8] == b'EFI PART'
    return h, struct.unpack('<QIII', bytes(h[72:92]))
def hcrc(h): t = bytearray(h); t[16:20] = b'\0\0\0\0'; return zlib.crc32(bytes(t)) & 0xffffffff
plan = []
new_ecrc = None
for hlba in (1, total - 1):
    h, (elba, n, esz, ecrc) = hdr(hlba)
    arr = bytearray(rd(elba, (n * esz + SEC - 1) // SEC)[:n * esz])
    assert zlib.crc32(bytes(arr)) & 0xffffffff == ecrc, 'entry CRC mismatch before edit'
    assert struct.unpack('<I', bytes(h[16:20]))[0] == hcrc(h), 'header CRC mismatch before edit'
    if part == 'active':
        act = [nm for nm in ('boot_a', 'boot_b') for i in range(n)
               if arr[i*esz+56:(i+1)*esz].decode('utf-16le').split('\0')[0] == nm and arr[i*esz+48+6] & 0x04]
        assert len(act) == 1, 'cannot tell the active slot: %s' % act
        part = act[0]
    idx = [i for i in range(n) if arr[i*esz+56:(i+1)*esz].decode('utf-16le').split('\0')[0] == part]
    assert len(idx) == 1, idx
    i = idx[0]; off = i * esz + 48 + 6
    old = arr[off]
    assert old & 0x80 == 0, 'slot marked unbootable'
    new = ((old & ~0x40) | 0x38) if clear else (old | 0x40)
    if new == old: print(part, 'already', 'unsuccessful' if clear else 'successful', '- nothing to do'); sys.exit(0)
    arr[off] = new
    print('GPT@%d entry %d %s byte6 %#x -> %#x' % (hlba, i, part, old, arr[off]))
    ecrc2 = zlib.crc32(bytes(arr)) & 0xffffffff
    h[88:92] = struct.pack('<I', ecrc2); h[16:20] = struct.pack('<I', hcrc(h))
    sec_first = elba + (i * esz) // SEC
    plan.append((sec_first, bytes(arr[((i*esz)//SEC)*SEC:((i*esz)//SEC+1)*SEC]).ljust(SEC, b'\0'), hlba, bytes(h)))
if write:
    for sec, data, hlba, h in plan:
        cur = bytearray(rd(sec)); cur[:len(data)] = data[:SEC]
        os.pwrite(fd, bytes(cur), sec * SEC)
        cur = bytearray(rd(hlba)); cur[:92] = h
        os.pwrite(fd, bytes(cur), hlba * SEC)
    os.fsync(fd); print('written')
else:
    print('dry run, nothing written')
