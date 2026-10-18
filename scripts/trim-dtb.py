# Remove nodes from a DTB except those needed by the o25 overlay (labels + ancestors) and an extra keep list.
# usage: trim-dtb.py in.dtb out.dtb o25.dtb [fraction 0..1 of removable top nodes to remove] [keep-prefix ...]
import subprocess,sys
inp,out,ov=sys.argv[1:4]; frac=float(sys.argv[4]) if len(sys.argv)>4 else 1.0; extra=sys.argv[5:]
run=lambda *a: subprocess.run(a,capture_output=True,text=True).stdout
labels=run('fdtget','-p',ov,'/__fixups__').split()
keep={'/','/chosen','/memory','/__symbols__','/aliases'}
for l in labels:
    p=run('fdtget','-t','s',inp,'/__symbols__',l).strip()
    if not p: print('missing symbol',l,file=sys.stderr); continue
    parts=p.strip('/').split('/')
    for i in range(len(parts)+1): keep.add('/'+'/'.join(parts[:i]) if i else '/')
def kept(p): return p in keep or any(p.startswith(e) for e in extra) or any(k.startswith(p+'/') for k in keep)
# removable = maximal subtrees not containing any kept node
rem=[]
def walk(p):
    for c in run('fdtget','-l',inp,p).split():
        cp=(p.rstrip('/')+'/'+c)
        if any(cp==k or k.startswith(cp+'/') for k in keep) or any(cp.startswith(e) or e.startswith(cp+'/') for e in extra):
            if cp not in keep or any(k.startswith(cp+'/') for k in keep): walk(cp)
        else: rem.append(cp)
walk('/')
rem=rem[:int(len(rem)*frac)]
subprocess.run(['cp',inp,out])
for p in rem: subprocess.run(['fdtput','-r',out,p])
print(f'removed {len(rem)} subtrees',file=sys.stderr)
for p in rem: print(p)
