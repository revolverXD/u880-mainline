# Run a shell command on the tablet over the USB serial gadget and print its output; exit code = remote $?.
# usage: ttycmd.py "<command>" [timeout_s]   (device /dev/ttyACM0, override with TTY env)
import os,sys,termios,time,select,random
dev=os.environ.get('TTY','/dev/ttyACM0'); cmd=sys.argv[1]; tmo=float(sys.argv[2]) if len(sys.argv)>2 else 30
fd=os.open(dev,os.O_RDWR|os.O_NOCTTY)
a=termios.tcgetattr(fd); a[0]=0; a[1]=0; a[3]=0; a[6][termios.VMIN]=0; a[6][termios.VTIME]=0
termios.tcsetattr(fd,termios.TCSANOW,a)

def drain(t):
    end=time.time()+t
    while time.time()<end:
        if select.select([fd],[],[],0.2)[0]: os.read(fd,65536)

os.write(fd,b'stty -echo 2>/dev/null; export PS1=\n'); drain(0.8)
n=random.randrange(10**6); tag=f'__END{n:06d}__'.encode()
# split the marker in the command text so an echoed command line never matches it
os.write(fd,f'{cmd}; echo "__E""ND{n:06d}__$?"\n'.encode())
buf=b''; end=time.time()+tmo
while time.time()<end:
    if select.select([fd],[],[],0.5)[0]:
        buf+=os.read(fd,65536)
        i=buf.find(tag)
        if i>=0 and buf.find(b'\n',i)>=0: break
out=buf.decode('utf-8','replace').replace('\r','')
i=out.find(tag.decode())
if i<0: sys.stdout.write(out); print('[timeout]'); sys.exit(124)
print(out[:i].rstrip())
rc=out[i+len(tag):].split()
sys.exit(int(rc[0]) if rc and rc[0].isdigit() else 1)
