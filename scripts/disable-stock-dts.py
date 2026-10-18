# Stock dtb2 with every device node disabled except what mainline needs to boot (GIC, arch timer, PSCI).
# Structure stays identical, so ABL (and its o25 overlay) accept it; mainline only probes the kept nodes.
# usage: disable-stock-dts.py in.dts out.dts [allow-compatibles.txt]
#   allow file: one compatible per line (# comments); depth-2 nodes whose compatible list contains one stay enabled;
#   "!/soc/path" lines keep that node disabled anyway.
import re,sys
KEEP={'/soc/interrupt-controller@17100000','/soc/timer','/soc/psci'}
DISABLE_PARENTS={'/soc','/firmware','/thermal-zones'}
ALLOW=set()
if len(sys.argv)>3:
    entries=[l.split('#')[0].strip() for l in open(sys.argv[3]) if l.split('#')[0].strip()]
    ALLOW={e for e in entries if not e.startswith(('!','+'))}
    KEEP_PARENTS={e[1:] for e in entries if e.startswith('+')}   # "+/thermal-zones": leave that parent's children as-is
    DISABLE_PARENTS.difference_update(KEEP_PARENTS)
    DENY={e[1:] for e in entries if e.startswith('!')}   # "!/soc/node@addr" forces a matched node to stay disabled
else: DENY=set()
src=open(sys.argv[1]).read().split('\n'); out=[]; st=[]; pending=None; n=0
# map node path -> compatibles (first pass)
compat={}; st2=[]
for l in src:
    m=re.match(r'^(\t*)(?:[\w]+: )*([^\s{]+) \{$',l)
    if m:
        d=len(m.group(1)); st2=st2[:d]+[m.group(2)]; continue
    c=re.match(r'^\t*compatible = (.*);$',l)
    if c and st2: compat.setdefault('/'+'/'.join(st2[1:]),set()).update(re.findall(r'"([^"]+)"',c.group(1)))
kept_allow=[]
for l in src:
    m=re.match(r'^(\t*)(?:[\w]+: )*([^\s{]+) \{$',l)
    if m:
        d=len(m.group(1)); st=st[:d]+[m.group(2)]
        p='/'+'/'.join(st[1:]) if d>0 else '/'
        parent=p.rsplit('/',1)[0] or '/'
        out.append(l)
        allowed=bool(compat.get(p,set()) & ALLOW) and p not in DENY
        if allowed and d==2 and parent in DISABLE_PARENTS: kept_allow.append(p)
        if d==2 and parent in DISABLE_PARENTS and p not in KEEP and not allowed:
            out.append('\t'*(d+1)+'status = "disabled";'); pending=d; n+=1
        else: pending=None
        continue
    # drop the node's own original status line (would duplicate ours)
    sm=re.match(r'^(\t*)status = ',l)
    if sm and pending is not None and len(sm.group(1))==pending+1: continue
    if re.match(r'^\t*\};$',l) or re.match(r'^(\t*)(?:[\w]+: )*([^\s{]+) \{$',l): pending=None
    out.append(l)
open(sys.argv[2],'w').write('\n'.join(out)); print('disabled',n,'nodes; allow-listed:',len(kept_allow),file=sys.stderr)
for p in kept_allow: print('  enabled',p,file=sys.stderr)
