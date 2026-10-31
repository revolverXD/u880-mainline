# Minimal ELF64 reader for stock .ko files: returns {symbol: (section, bytes)} for data objects. Used to read the Cliffs camcc tables (NOTES 2026-10-31).
import struct,sys
def load(p):
    d=open(p,'rb').read()
    shoff,=struct.unpack_from('<Q',d,0x28); shentsize,shnum,shstrndx=struct.unpack_from('<HHH',d,0x3a)
    sh=[]
    for i in range(shnum):
        n,t,f,a,o,s,l,inf,al,es=struct.unpack_from('<IIQQQQIIQQ',d,shoff+i*shentsize); sh.append((n,t,f,a,o,s,l,inf,al,es))
    stro=sh[shstrndx][4]
    def nm(o,base): 
        e=d.index(b'\0',base+o); return d[base+o:e].decode()
    secn=[nm(s[0],stro) for s in sh]
    syms={}
    for i,s in enumerate(sh):
        if s[1]==2:
            strb=sh[s[6]][4]
            for k in range(s[5]//24):
                nmo,info,oth,shn,val,size=struct.unpack_from('<IBBHQQ',d,s[4]+k*24)
                if shn and shn<len(sh) and (info&0xf)==1 and size:
                    nmv=nm(nmo,strb)
                    if sh[shn][1]!=8: syms[nmv]=(secn[shn],d[sh[shn][4]+val:sh[shn][4]+val+size])
    return syms
if __name__=='__main__':
    a=load(sys.argv[1]); b=load(sys.argv[2]); pa=sys.argv[3]; pb=sys.argv[4]
    for k in sorted(a):
        if not (k.startswith('ftbl') or k.endswith('_config') or 'post_div_table' in k): continue
        k2=k.replace(pa,pb)
        if k2 not in b: print('MISSING-IN-B',k); continue
        print(('SAME ' if a[k][1]==b[k2][1] else 'DIFF ')+k, len(a[k][1]), len(b[k2][1]))
