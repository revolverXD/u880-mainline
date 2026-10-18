# usage: stub-dts.py in.dts out.dts ops.txt N
# Applies the first N ops ("stub <path>": drop the node's own properties except phandle; "rm <path>": drop subtree).
import re,sys
src,dst,opsf,n=sys.argv[1],sys.argv[2],sys.argv[3],int(sys.argv[4])
ops=[l.split(None,1) for l in open(opsf).read().split('\n') if l.strip()][:n]
stub={p for o,p in ops if o=='stub'}; rm={p for o,p in ops if o=='rm'}
out=[];st=[];skip_depth=None
for l in open(src).read().split('\n'):
    m=re.match(r'^(\t*)(?:[\w]+: )*([^\s{]+) \{$',l)
    e=re.match(r'^(\t*)\};$',l)
    if m:
        d=len(m.group(1)); st=st[:d]+[m.group(2)]
        p='/'+'/'.join(st[1:]) if d>0 else '/'
        if skip_depth is None and p in rm: skip_depth=d
        if skip_depth is None: out.append(l)
        continue
    if e:
        d=len(e.group(1))
        if skip_depth is None: out.append(l)
        elif d==skip_depth: skip_depth=None
        continue
    if skip_depth is not None: continue
    pm=re.match(r'^(\t*)([^\s=;]+)( =.*)?;$',l)
    if pm and st:
        d=len(pm.group(1))-1
        p='/'+'/'.join(st[1:d+1]) if d>0 else '/'
        if p in stub and pm.group(2) not in ('phandle','linux,phandle'): continue
    out.append(l)
open(dst,'w').write('\n'.join(out))
