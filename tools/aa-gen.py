#!/usr/bin/env python3
"""Turn the AppArmor complain-mode log of one profile into profile rules.
usage: aa-gen.py <profile name> <attach path> [dmesg-file]   (reads `dmesg` when no file is given)
Output is a starting point: review it, the path collapsing is heuristic."""
import re, subprocess, sys, collections
prof, attach = sys.argv[1], sys.argv[2]
log = open(sys.argv[3]).read() if len(sys.argv) > 3 else subprocess.run(['dmesg'], capture_output=True, text=True).stdout
caps, nets, files, execs, other = set(), set(), collections.defaultdict(set), set(), set()
def coll(p):
    p = re.sub(r'^/proc/\d+/', '@{PROC}/*/', p)
    p = re.sub(r'^/proc/self/', '@{PROC}/self/', p)
    p = re.sub(r'^/sys/devices/.*', '/sys/devices/**', p)
    p = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '*', p)
    p = re.sub(r'\.[A-Za-z0-9]{6}$', '.*', p)
    p = re.sub(r'^/run/user/\d+/', '/run/user/*/', p)
    p = re.sub(r'/home/[^/]+/', '/home/*/', p)
    return p
for l in log.splitlines():
    if f'profile="{prof}"' not in l or 'apparmor="' not in l: continue
    g = lambda k: (re.search(k + r'="([^"]*)"', l) or [None, None])[1]
    op, cl = g('operation'), g('class')
    if cl == 'cap': caps.add(g('capname'))
    elif cl == 'net':
        if g('family'): nets.add((g('family'), g('sock_type')))
        else: other.add('unix,')
    elif cl == 'file':
        n = g('name') or ''
        if op == 'exec': execs.add(n); continue
        m = g('requested_mask') or ''
        if n: files[coll(n)] |= set(m)
    else: other.add(f'# {cl} {op} {g("name") or g("peer") or ""}')
out = ['abi <abi/4.0>,', '', 'include <tunables/global>', '', f'{attach} {{', '  include <abstractions/base>', '  include <abstractions/nameservice>', '']
out += [f'  capability {c},' for c in sorted(caps)] + ['']
out += [f'  network {f} {t},' for f, t in sorted(nets)] + ['']
out += sorted('  ' + o for o in other if o.startswith('unix'))
out += [f'  {e} Ux,' for e in sorted(execs)] + ['', f'  {attach} mr,']
def mask(s):
    m = ''.join(c for c in 'rwakl' if c in s or (c == 'w' and set('cdx') & s and False))
    if set('cd') & s or 'w' in s: m = m.replace('w', '') + 'w'
    return m or 'r'
for p in sorted(files):
    s = files[p]; m = mask(s)
    if 'w' in s or 'c' in s or 'd' in s: m = 'rw' if 'r' in s or 'w' in s else 'w'; m += 'k' if 'k' in s else ''
    out.append(f'  {p} {m},')
out += sorted('  ' + o for o in other if o.startswith('#'))
out += ['}']
print('\n'.join(out))
