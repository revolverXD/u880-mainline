import struct,sys,os
f=open(sys.argv[1],'rb').read()
assert f[:4]==b'\xd7\xb7\xab\x1e'
_,tot,hs,es,n,eoff=struct.unpack_from('>6I',f,0)
for k in range(n):
    sz,off,id_,rev=struct.unpack_from('>4I',f,eoff+k*es)
    open(os.path.join(sys.argv[2],f'o{k}.dtb'),'wb').write(f[off:off+sz])
print(n,'overlays')
