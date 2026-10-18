import struct,sys,os
f=open(sys.argv[1],'rb').read(); out=sys.argv[2]
assert f[:8]==b'VNDRBOOT'
ver,page,kaddr,raddr,vrsize=struct.unpack_from('<5I',f,8)
off=8+20+2048
tags,=struct.unpack_from('<I',f,off); name=f[off+4:off+20]; hsize,dtbsize=struct.unpack_from('<2I',f,off+20)
cmdline=f[28:28+2048].split(b'\0')[0]
print('ver',ver,'page',page,'name',name,'dtb',dtbsize); print('cmdline',cmdline.decode())
al=lambda x:(x+page-1)//page*page
dstart=al(hsize)+al(vrsize); dtb=f[dstart:dstart+dtbsize]
i=0;n=0
while True:
    j=dtb.find(b'\xd0\x0d\xfe\xed',i)
    if j<0: break
    sz=struct.unpack_from('>I',dtb,j+4)[0]
    open(os.path.join(out,f'dtb{n}.dtb'),'wb').write(dtb[j:j+sz]); n+=1; i=j+sz
print('dtbs',n)
