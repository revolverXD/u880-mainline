#!/usr/bin/python3
# Display off/on cycles through KMS, so the panel driver sees the same CRTC disable/enable that the
# compositor's power-button DPMS does. No headers or extra modules on the tablet: libdrm through ctypes,
# the few struct layouts it needs written out here.
#
# usage: dpms-cycle.py [card] [off_seconds] [on_seconds] [cycles]
# It sets its own all-white framebuffer, so a photo says straight away whether the panel displays.
import ctypes as C, os, sys, time, mmap

MI = 52                       # sizeof(drmModeModeInfo)
MODE_H, MODE_V = 4, 14        # hdisplay (u16) and vdisplay (u16) inside drmModeModeInfo
MODE_NAME = 39                # name[13] starts after clock+10*u16+vrefresh+flags+type
CONNECTED = 1
CREATE_DUMB, MAP_DUMB = 0xC01864B0, 0xC01064B2


class Res(C.Structure):
    _fields_ = [("count_fbs", C.c_int), ("fbs", C.POINTER(C.c_uint32)),
                ("count_encoders", C.c_int), ("encoders", C.POINTER(C.c_uint32)),
                ("count_connectors", C.c_int), ("connectors", C.POINTER(C.c_uint32)),
                ("count_crtcs", C.c_int), ("crtcs", C.POINTER(C.c_uint32)),
                ("count_modes", C.c_int), ("modes", C.POINTER(C.c_uint32)),
                ("w", C.c_uint32), ("h", C.c_uint32), ("minw", C.c_uint32), ("minh", C.c_uint32),
                ("maxw", C.c_uint32), ("maxh", C.c_uint32)]


class Conn(C.Structure):
    _fields_ = [("connector_id", C.c_uint32), ("encoder_id", C.c_uint32), ("type", C.c_uint32),
                ("connector_type_id", C.c_uint32), ("connection", C.c_uint32),
                ("mmw", C.c_uint32), ("mmh", C.c_uint32), ("subpixel", C.c_uint32),
                ("count_encoders", C.c_uint32), ("encoders", C.POINTER(C.c_uint32)),
                ("count_modes", C.c_uint32), ("modes", C.POINTER(C.c_void_p))]


class Enc(C.Structure):
    _fields_ = [("encoder_id", C.c_uint32), ("encoder_type", C.c_uint32), ("crtc_id", C.c_uint32),
                ("possible_crtcs", C.c_uint32), ("possible_clones", C.c_uint32)]


class Dumb(C.Structure):
    _fields_ = [("height", C.c_uint32), ("width", C.c_uint32), ("bpp", C.c_uint32),
                ("pitch", C.c_uint32), ("size", C.c_uint32), ("handle", C.c_uint32)]


class Map(C.Structure):
    _fields_ = [("handle", C.c_uint32), ("pad", C.c_uint32), ("offset", C.c_uint64)]


lib = C.CDLL("libdrm.so.2")
lib.drmModeGetResources.restype = C.POINTER(Res)
lib.drmModeGetConnector.restype = C.POINTER(Conn)
lib.drmModeGetEncoder.restype = C.POINTER(Enc)
lib.drmModeSetCrtc.argtypes = [C.c_int, C.c_uint32, C.c_uint32, C.c_uint32, C.c_uint32,
                               C.POINTER(C.c_uint32), C.c_int, C.c_void_p]
lib.drmModeAddFB.argtypes = [C.c_int] + [C.c_uint32] * 5 + [C.POINTER(C.c_uint32), C.c_uint32]

card = sys.argv[1] if len(sys.argv) > 1 else "/dev/dri/card1"
toff = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
ton = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
cycles = int(sys.argv[4]) if len(sys.argv) > 4 else 1

fd = os.open(card, os.O_RDWR)
if lib.drmSetMaster(fd):
    print("E: not DRM master - the compositor holds the card")
    sys.exit(1)

res = lib.drmModeGetResources(fd)
conn = cn = None
for i in range(res.contents.count_connectors):
    c = lib.drmModeGetConnector(fd, res.contents.connectors[i])
    if c and c.contents.connection == CONNECTED and c.contents.count_modes:
        conn, cn = c.contents, c
        break
if not conn:
    print("E: no connected connector with modes")
    sys.exit(1)

enc = lib.drmModeGetEncoder(fd, conn.encoder_id or conn.encoders[0]).contents
mask = enc.possible_crtcs
ci = (mask & -mask).bit_length() - 1
crtc_id = res.contents.crtcs[ci]

mode = (C.c_ubyte * MI).from_buffer_copy(C.string_at(conn.modes[0], MI))
w, h = C.cast(mode, C.POINTER(C.c_uint16))[MODE_H // 2], C.cast(mode, C.POINTER(C.c_uint16))[MODE_V // 2]
print("conn %d enc %d crtc %d mode %s (%dx%d)" % (
    conn.connector_id, enc.encoder_id, crtc_id,
    bytes(mode[MODE_NAME:MODE_NAME + 13]).split(b"\0")[0].decode(), w, h))

d = Dumb(height=h, width=w, bpp=32)
if lib.drmIoctl(fd, CREATE_DUMB, C.byref(d)):
    print("E: create dumb failed")
    sys.exit(1)
m = Map(handle=d.handle)
lib.drmIoctl(fd, MAP_DUMB, C.byref(m))
buf = mmap.mmap(fd, d.size, mmap.PROT_READ | mmap.PROT_WRITE, mmap.MAP_SHARED, fd, m.offset)
pat = b"\xff" * 4096                      # all channels on: the panel shows white when it works
buf[:] = pat * (d.size // len(pat)) + pat[:d.size % len(pat)]
buf.close()
fb = C.c_uint32()
if lib.drmModeAddFB(fd, w, h, 24, 32, d.pitch, C.byref(fb), d.handle):
    print("E: addfb failed")
    sys.exit(1)

connp = (C.c_uint32 * 1)(conn.connector_id)


def on():
    return lib.drmModeSetCrtc(fd, crtc_id, fb.value, 0, 0, connp, 1, C.byref(mode))


def off():
    return lib.drmModeSetCrtc(fd, crtc_id, 0, 0, 0, connp, 0, None)


print("start on ->", on())
for n in range(1, cycles + 1):
    time.sleep(ton)
    print("cycle %d: off -> %s" % (n, off()))
    time.sleep(toff)
    print("cycle %d: on -> %s" % (n, on()))
print("done")
