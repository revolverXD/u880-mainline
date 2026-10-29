#!/usr/bin/env python3
"""Write kernel/u880-kernel-delta.patch = every SOURCE-type file in linux-7.2.9/ that differs from the pristine tarball tree (new files included),
and kernel/u880.config = the .config. Build outputs and generated files are skipped.
usage: snapshot-kernel-delta.py <pristine linux-7.2.9 dir> [current dir=linux-7.2.9]"""
import os, sys, difflib, shutil
pri, cur = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'linux-7.2.9')
SRC_EXT = ('.c', '.h', '.S', '.dts', '.dtsi', '.dtso', '.yaml', '.txt', '.rst', '.py', '.sh', '.json', '.dtbo')
SRC_NAMES = ('Kconfig', 'Makefile', 'Kbuild')
SKIP_DIRS = ('include/generated', 'include/config', 'arch/arm64/include/generated', '.tmp', 'modules-out', 'tools/objtool', 'tools/bpf', 'scripts/basic',
             'scripts/mod', 'scripts/kconfig', 'scripts/dtc', 'scripts/selinux', 'scripts/genksyms', 'scripts/gcc-plugins')
GENERATED = ('security/apparmor/rlim_names.h', 'security/apparmor/capability_names.h', 'security/apparmor/net_names.h')   # written by the AppArmor build
def is_src(rel):
    b = os.path.basename(rel)
    if rel in GENERATED: return False
    if b.endswith(('.mod.c', '.dtb.S', '.o.cmd')) or b.startswith('.'): return False
    if any(rel.startswith(d + '/') or rel == d for d in SKIP_DIRS): return False
    return b.endswith(SRC_EXT) or b in SRC_NAMES or b.startswith('Kconfig')
out = []; n = 0
for root, dirs, files in os.walk(cur):
    rel_root = os.path.relpath(root, cur)
    dirs[:] = [d for d in dirs if d != '.git' and not os.path.join(rel_root, d).lstrip('./') in SKIP_DIRS]
    for f in files:
        rel = os.path.normpath(os.path.join(rel_root, f))
        if not is_src(rel): continue
        c = os.path.join(cur, rel); p = os.path.join(pri, rel)
        try: cb = open(c, 'rb').read()
        except OSError: continue
        if os.path.exists(p):
            if open(p, 'rb').read() == cb: continue
            a = open(p, 'rb').read().decode('utf-8', 'replace').splitlines(keepends=True)
        else: a = []
        b = cb.decode('utf-8', 'replace').splitlines(keepends=True)
        d = list(difflib.unified_diff(a, b, 'a/' + rel if a else '/dev/null', 'b/' + rel))
        if d: out.extend(d); n += 1
open('kernel/u880-kernel-delta.patch', 'w').write(''.join(out))
shutil.copy(os.path.join(cur, '.config'), 'kernel/u880.config')
print(n, 'files in delta;', sum(1 for l in out if l.startswith('+') and not l.startswith('+++')), 'added lines')
