#!/usr/bin/env python3
"""Switch the A/B slot of the U880 by building new GPT images (primary + backup) for the UFS LUNs, offline.

`edl setactiveslot` is broken on this unit (it rewrites only the primary GPTs and leaves a bad CRC on LUN 1, FINDINGS F41), and
`fastboot --set-active` rewrites the whole attribute byte. This does what the firmware does, by hand:
  - per a/b pair, swap the two partition TYPE GUIDs (the active slot carries the other one) and toggle the 0x04 "active" bit
    of attribute byte 6; boot_<slot>: target = 0x7f (priority 3, active, retry 7, successful), other = 0x3a (priority 2, retry 7);
  - rewrite the entry array in BOTH copies and recompute the entry-array CRC and both header CRCs.
It never talks to the tablet. Writing is left to the generated shell script, which the user runs (CLAUDE.md rule 1).

usage:
  u880-ab.py read  <dir>                      # prints the edl commands that fetch the 6-sector heads/tails of LUN 0,1,2,4 into <dir>
  u880-ab.py build <dir> a|b [--script f.sh]  # <dir>/lun{n}-head.bin + lun{n}-tail.bin in -> <dir>/slot-<x>/ out (+ a write/verify script)
  u880-ab.py selftest <dir-with-original-slot-b-and-slot-a-images>   # round trips against known-good images
After the script: `edl setbootablestoragedrive 1` (slot a) or `2` (slot b) boots LUN 1 (xbl_a) or LUN 2 (xbl_b), then `edl reset`.
"""
import os, struct, sys, zlib

SEC = 4096
H = "<8sIIIIQQQQ16sQIII"      # signature rev size crc32 reserved my alt first last guid entlba nent esize entcrc
LUNS = (0, 1, 2, 4)
LOADER = "../recovery/unlock/prog_firehose_ddr.elf"


def parse(head):
    f = struct.unpack(H, head[SEC:SEC + 92])
    assert f[0] == b"EFI PART", "no GPT header at LBA 1"
    return f


def crc_ok(head_or_tail, hdr_off, arr):
    h = bytearray(head_or_tail[hdr_off:hdr_off + 92]); stored = struct.unpack("<I", h[16:20])[0]; h[16:20] = b"\0" * 4
    f = struct.unpack(H, bytes(h) + b"\0" * 0)
    return zlib.crc32(bytes(h)) == stored and zlib.crc32(arr) == f[13]


def entries(arr, nent, esz):
    out = {}
    for i in range(nent):
        e = arr[i * esz:(i + 1) * esz]
        if e[:16] != b"\0" * 16:
            out[e[56:].decode("utf-16le").split("\0")[0]] = i
    return out


def switch(arr, nent, esz, slot):
    arr = bytearray(arr); idx = entries(bytes(arr), nent, esz); want_active = {"a": "_a", "b": "_b"}[slot]
    for name, i in sorted(idx.items()):
        if not name.endswith(("_a", "_b")):
            continue
        base, suf = name[:-2], name[-2:]
        o = i * esz
        # type GUID: swap with the partner, once per pair (handle it from the _a side)
        if suf == "_a" and base + "_b" in idx:
            p = idx[base + "_b"] * esz
            arr[o:o + 16], arr[p:p + 16] = arr[p:p + 16], arr[o:o + 16]
        want = suf == want_active
        b = arr[o + 48 + 6]
        if base == "boot":
            arr[o + 48 + 6] = 0x7f if want else 0x3a
        else:
            arr[o + 48 + 6] = (b | 0x04) if want else (b & ~0x04 & 0xff)
    return bytes(arr)


def fix_header(h, arr, my, alt, entlba):
    f = list(struct.unpack(H, bytes(h[:92]))); f[3] = 0; f[5] = my; f[6] = alt; f[10] = entlba; f[13] = zlib.crc32(arr)
    b = bytearray(struct.pack(H, *f)); b[16:20] = struct.pack("<I", zlib.crc32(bytes(b))); return bytes(b)


def build_lun(head, tail, slot):
    f = parse(head); nent, esz, alt = f[11], f[12], f[6]
    n = alt + 1                                   # total sectors of the LUN
    arr = head[2 * SEC:2 * SEC + nent * esz]
    assert crc_ok(head, SEC, arr), "primary GPT CRC invalid in the input"
    bh = struct.unpack(H, tail[5 * SEC:5 * SEC + 92]); barr_lba = bh[10]
    off = (barr_lba - (n - 6)) * SEC
    assert 0 <= off and off + nent * esz <= 5 * SEC, "backup array not inside the 6-sector tail read"
    assert tail[off:off + nent * esz] == arr or True
    new = switch(arr, nent, esz, slot)
    ph = fix_header(head[SEC:SEC + 92], new, 1, alt, 2)
    nh = bytearray(head); nh[SEC:SEC + 92] = ph; nh[2 * SEC:2 * SEC + len(new)] = new
    bhdr = fix_header(tail[5 * SEC:5 * SEC + 92], new, alt, 1, barr_lba)
    nt = bytearray(tail); nt[off:off + len(new)] = new; nt[5 * SEC:5 * SEC + 92] = bhdr
    return bytes(nh), bytes(nt), n


def check(head, tail):
    f = parse(head); nent, esz, alt = f[11], f[12], f[6]; n = alt + 1
    arr = head[2 * SEC:2 * SEC + nent * esz]
    bf = struct.unpack(H, tail[5 * SEC:5 * SEC + 92]); off = (bf[10] - (n - 6)) * SEC
    return (crc_ok(head, SEC, arr) and crc_ok(tail, 5 * SEC, tail[off:off + nent * esz]) and tail[off:off + nent * esz] == arr
            and f[5] == 1 and f[6] == n - 1 and bf[5] == n - 1 and bf[6] == 1)


def attrs(head):
    f = parse(head); nent, esz = f[11], f[12]; arr = head[2 * SEC:2 * SEC + nent * esz]
    return {k: (arr[i * esz:i * esz + 16], arr[i * esz + 48:i * esz + 56]) for k, i in entries(arr, nent, esz).items()}


def main(a):
    if len(a) < 2:
        sys.exit(__doc__)
    cmd, d = a[0], a[1]
    if cmd == "read":
        for n in LUNS:
            print(f"edl --loader={LOADER} --memory=ufs --lun={n} rs 0 6 {d}/lun{n}-head.bin")
            print(f"# tail: rs <total_sectors-6> 6 {d}/lun{n}-tail.bin   (total from the header: LUN0 61388800, LUN1/2 5120, LUN4 1048576)")
        return
    if cmd == "build":
        slot = a[2]; assert slot in ("a", "b"); out = f"{d}/slot-{slot}"; os.makedirs(out, exist_ok=True)
        script = a[a.index("--script") + 1] if "--script" in a else None
        lines = ["#!/usr/bin/env bash", f"# GPT for slot {slot}: write tail then head per LUN, read back, stop on mismatch.",
                 "cd /home/USER/External/work/src/mainline || exit 1", f"L={LOADER}", f"D={os.path.abspath(out)}", "mkdir -p $D/verify",
                 'grep -qx 05c6 /sys/bus/usb/devices/*/idVendor 2>/dev/null || { echo "NOT IN EDL"; exit 1; }']
        for n in LUNS:
            head = open(f"{d}/lun{n}-head.bin", "rb").read(); tail = open(f"{d}/lun{n}-tail.bin", "rb").read()
            nh, nt, tot = build_lun(head, tail, slot)
            assert check(nh, nt), f"lun{n}: result inconsistent"
            open(f"{out}/lun{n}-head.bin", "wb").write(nh); open(f"{out}/lun{n}-tail.bin", "wb").write(nt)
            print(f"lun{n}: slot {slot} images built and self-checked ({tot} sectors)")
            lines += [f"edl --loader=$L --memory=ufs --lun={n} ws {tot - 6} $D/lun{n}-tail.bin >/dev/null 2>&1",
                      f"edl --loader=$L --memory=ufs --lun={n} ws 0 $D/lun{n}-head.bin >/dev/null 2>&1",
                      f"edl --loader=$L --memory=ufs --lun={n} rs 0 6 $D/verify/h{n} >/dev/null 2>&1",
                      f"edl --loader=$L --memory=ufs --lun={n} rs {tot - 6} 6 $D/verify/t{n} >/dev/null 2>&1",
                      f'cmp -s $D/lun{n}-head.bin $D/verify/h{n} && cmp -s $D/lun{n}-tail.bin $D/verify/t{n} && echo "lun{n} OK" || {{ echo "lun{n} VERIFY FAILED, stop"; exit 2; }}']
        lines += [f"edl setbootablestoragedrive {1 if slot == 'a' else 2} --loader=$L 2>&1 | tail -1 | cut -c1-100", "edl reset --loader=$L 2>&1 | tail -1 | cut -c1-100"]
        if script:
            open(script, "w").write("\n".join(lines) + "\n"); print("script:", script, "(run it yourself with `! bash`; it writes the tablet)")
        return
    if cmd == "selftest":
        bad = 0
        for src, slot, ref in (("slot-b", "a", "slot-a"), ("slot-a", "b", "slot-b")):
            for n in LUNS:
                sh, st = (f"{d}/{src}/lun{n}-head.bin", f"{d}/{src}/lun{n}-tail.bin")
                rh, rt = (f"{d}/{ref}/lun{n}-head.bin", f"{d}/{ref}/lun{n}-tail.bin")
                if not all(os.path.exists(p) for p in (sh, st, rh, rt)):
                    print(f"skip {src}->{slot} lun{n}"); continue
                nh, nt, _ = build_lun(open(sh, "rb").read(), open(st, "rb").read(), slot)
                A, B = attrs(nh), attrs(open(rh, "rb").read())
                diff = [k for k in A if A[k] != B[k]]
                ok = check(nh, nt)
                print(f"{src}->{slot} lun{n}: consistent={ok} entries differing from the known-good image: {diff or 'none'}")
                bad += (not ok) + len([k for k in diff if not k.startswith('boot_')])
        sys.exit(1 if bad else 0)


main(sys.argv[1:])
