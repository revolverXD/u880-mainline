import sys, os, tarfile, io, subprocess, glob
R = sys.argv[1]
def data_member(path):
    with open(path, 'rb') as f:
        assert f.read(8) == b'!<arch>\n'
        while True:
            h = f.read(60)
            if len(h) < 60: return None
            name = h[:16].decode().strip().rstrip('/'); size = int(h[48:58])
            body = f.read(size + (size & 1) if False else size)
            if size & 1: f.read(1)
            if name.startswith('data.tar'): return name, body
n = 0
for deb in sorted(glob.glob('/tmp/acache/archives/*.deb') + ['/tmp/steam.deb']):
    r = data_member(deb)
    if not r: print('no data', deb); continue
    name, body = r
    ext = name.split('.')[-1]
    if ext == 'zst':
        body = subprocess.run(['zstd', '-dc'], input=body, capture_output=True, check=True).stdout; mode = 'r:'
    elif ext == 'xz': mode = 'r:xz'
    elif ext == 'gz': mode = 'r:gz'
    else: mode = 'r:*'
    with tarfile.open(fileobj=io.BytesIO(body), mode=mode) as t:
        t.extractall(R, filter='tar'); n += 1
print('unpacked', n)
