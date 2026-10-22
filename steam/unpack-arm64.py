#!/usr/bin/env python3
# Unpack Valve's Steam client zips: converts the backslash paths and restores unix modes/symlinks. usage: unpack-arm64.py <pkgs dir> <dest>
import sys, os, zipfile, stat, glob
pk, dest = sys.argv[1], sys.argv[2]
n = 0
for z in sorted(glob.glob(pk + '/*.zip.*')):
    zf = zipfile.ZipFile(z)
    for i in zf.infolist():
        name = i.filename.replace('\\', '/')
        path = os.path.join(dest, name)
        if i.is_dir() or name.endswith('/'):
            os.makedirs(path, exist_ok=True); continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        mode = i.external_attr >> 16
        if stat.S_ISLNK(mode):
            if os.path.lexists(path): os.remove(path)
            os.symlink(zf.read(i).decode(), path); continue
        with open(path, 'wb') as f: f.write(zf.read(i))
        os.chmod(path, (mode & 0o777) or 0o644); n += 1
print('files', n)
# the zips carry no unix modes: make ELF programs (no .so/.dat/.pak names) and shell scripts executable
for root, _, files in os.walk(dest):
    for f in files:
        p = os.path.join(root, f)
        if os.path.islink(p): continue
        try:
            with open(p, 'rb') as fh: head = fh.read(4)
        except OSError: continue
        if (head == b'\x7fELF' and '.so' not in f) or f.endswith('.sh') or head[:2] == b'#!':
            os.chmod(p, 0o755)
