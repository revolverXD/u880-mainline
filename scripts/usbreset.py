# Reset the tablet's USB device (fastboot/adb) by vendor 18d1, via USBDEVFS_RESET. Clears a desynced fastboot link.
import fcntl,os,glob
for d in glob.glob('/sys/bus/usb/devices/*'):
    try:
        if open(d+'/idVendor').read().strip()!='18d1': continue
        bus=int(open(d+'/busnum').read()); dev=int(open(d+'/devnum').read())
    except OSError: continue
    path=f'/dev/bus/usb/{bus:03d}/{dev:03d}'
    fd=os.open(path,os.O_WRONLY); fcntl.ioctl(fd,0x5514,0); os.close(fd)   # USBDEVFS_RESET = _IO('U',20)
    print('reset',path,os.path.basename(d))
