# Log in on the tablet's serial getty (Arch Linux ARM) and run one command. usage: ttylogin.py "<cmd>" [user] [pass]
import os,sys,termios,time,select
cmd=sys.argv[1]; user=sys.argv[2] if len(sys.argv)>2 else 'root'; pw=sys.argv[3] if len(sys.argv)>3 else 'root'
fd=os.open(os.environ.get('TTY','/dev/ttyACM0'),os.O_RDWR|os.O_NOCTTY)
a=termios.tcgetattr(fd); a[0]=0;a[1]=0;a[3]=0; a[6][termios.VMIN]=0;a[6][termios.VTIME]=0; termios.tcsetattr(fd,termios.TCSANOW,a)
buf=b''
def wait(pats,t):
    global buf; end=time.time()+t
    while time.time()<end:
        if select.select([fd],[],[],0.3)[0]: buf+=os.read(fd,65536)
        for p in pats:
            if p in buf: return p
    return None
def send(s): os.write(fd,s.encode())
send('\x03\n'); p=wait([b'login:',b'Password:',b'# ',b'$ '],8)
if p==b'Password:': send('\n'); p=wait([b'login:'],8)
if p in (b'login:',None):
    buf=b''; send(user+'\n'); wait([b'Password:'],8); buf=b''; send(pw+'\n'); p=wait([b'# ',b'$ ',b'incorrect'],15)
    if p==b'incorrect': print(buf.decode('utf-8','replace')); sys.exit('login failed')
buf=b''; send(f'stty -echo; {cmd}; echo __E""ND__$?\n'); wait([b'__END__'],float(os.environ.get('TMO','60')))
time.sleep(0.3)
while select.select([fd],[],[],0.2)[0]: buf+=os.read(fd,65536)
out=buf.decode('utf-8','replace').replace('\r','')
i=out.find('__END__'); print(out[:i] if i>=0 else out)
