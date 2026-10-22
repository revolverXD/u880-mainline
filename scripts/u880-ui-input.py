#!/usr/bin/python3
# A virtual power key, keyboard and pointer for the tablet, so the states the user drives with the
# tablet's own controls can be scripted. Run as root: it creates the uinput device, then acts on
# commands. The compositor only sees the device if udev tags it uaccess (see
# /etc/udev/rules.d/99-u880-keypower.rules); logind does not hand out an ACL to a device that
# appears after the session starts, so after each restart do: setfacl -m u:1001:rw /dev/input/eventN
#
#   touch /tmp/power-press          -> press the power key (display off/on)
#   echo 'click 800 100'  > /tmp/u880-ui   -> left click at logical output position
#   echo 'drag 800 0 0 400' > /tmp/u880-ui -> press, move, release (relative move)
#   echo 'type hello'     > /tmp/u880-ui   -> type text (a-z, 0-9, space, enter)
#   echo 'key meta'       > /tmp/u880-ui   -> tap one named key
#   echo 'shot'           > /tmp/u880-ui   -> Super+Shift+S then drag-select the whole output
#
# The logical output is 1600x2560 portrait; the pointer is relative, so every gesture starts by
# clamping the cursor to (0,0) with big negative moves.
import ctypes as C, os, struct, time

UINPUT = "/dev/uinput"
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
UI_DEV_SETUP = 0x405C5503   # _IOW(U, 3, struct uinput_setup), size 92
EV_KEY, EV_REL, SYN = 1, 2, 0
BTN_LEFT, REL_X, REL_Y = 272, 0, 1
CMD, POWER_FLAG = "/tmp/u880-ui", "/tmp/power-press"
W, H = 1600, 2560

# libinput only treats a device as a keyboard if it has the ESC..ZZ range, so declare it.
KEYS = dict(zip("1234567890abcdefghijklmnopqrstuvwxyz ",
                [2,3,4,5,6,7,8,9,10,11] +
                [30,48,46,32,18,33,34,35,23,36,37,38,50,49,24,25,16,19,31,20,22,47,17,45,21,44] + [57]))
KEYS.update({"\n": 28, "enter": 28, "meta": 125, "shift": 42, "s": 31, "power": 116, "esc": 1})

lib = C.CDLL("libc.so.6", use_errno=True)
lib.ioctl.restype = C.c_int
lib.ioctl.argtypes = [C.c_int, C.c_ulong, C.c_void_p]

fd = os.open(UINPUT, os.O_WRONLY | os.O_NONBLOCK)
lib.ioctl(fd, UI_SET_EVBIT, EV_KEY)
for code in list(range(1, 53)) + [116, 343, 347, 42, 54, BTN_LEFT]:
    lib.ioctl(fd, UI_SET_KEYBIT, code)
lib.ioctl(fd, UI_SET_EVBIT, EV_REL)
for rel in (REL_X, REL_Y):
    lib.ioctl(fd, UI_SET_RELBIT, rel)
# struct uinput_setup { struct input_id id; char name[80]; u32 ff_effects_max; }
setup = struct.pack("<HHHH80sI", 0x19, 0x0001, 0x0001, 1, b"u880-power-sim", 0)
print("setup" if lib.ioctl(fd, UI_DEV_SETUP, C.c_char_p(setup)) >= 0 else "UI_DEV_SETUP failed")
print("create" if lib.ioctl(fd, UI_DEV_CREATE, None) >= 0 else "UI_DEV_CREATE failed")
print("u880-power-sim up; commands to %s, power key via %s" % (CMD, POWER_FLAG), flush=True)

# struct input_event { timeval (2 long); u16 type; u16 code; s32 value; } on 64-bit
def ev(t, code, value):
    os.write(fd, struct.pack("<QQHHi", 0, 0, t, code, value))

def key(code):
    ev(EV_KEY, code, 1); ev(SYN, 0, 0)
    time.sleep(0.05)
    ev(EV_KEY, code, 0); ev(SYN, 0, 0)

def move(dx, dy):
    # One pixel per event: libinput's default pointer profile accelerates fast movement, which would
    # put the cursor somewhere other than the requested position.
    sx, sy = (1 if dx > 0 else -1) if dx else 0, (1 if dy > 0 else -1) if dy else 0
    for i in range(max(abs(dx), abs(dy))):
        ev(EV_REL, REL_X, sx if i < abs(dx) else 0)
        ev(EV_REL, REL_Y, sy if i < abs(dy) else 0)
        ev(SYN, 0, 0)
    time.sleep(0.05)

def to_home():
    move(-4 * W, -4 * H)      # clamp to (0,0), so later moves are absolute

def click(x, y):
    to_home(); move(x, y); time.sleep(0.2)
    ev(EV_KEY, BTN_LEFT, 1); ev(SYN, 0, 0); time.sleep(0.1)
    ev(EV_KEY, BTN_LEFT, 0); ev(SYN, 0, 0)

def drag(x, y, dx, dy):
    to_home(); move(x, y); time.sleep(0.3)
    ev(EV_KEY, BTN_LEFT, 1); ev(SYN, 0, 0); time.sleep(0.2)
    move(dx, dy)
    ev(EV_KEY, BTN_LEFT, 0); ev(SYN, 0, 0)

def chord():
    ev(EV_KEY, 125, 1); ev(EV_KEY, 42, 1); time.sleep(0.05)
    key(31)
    ev(EV_KEY, 42, 0); ev(EV_KEY, 125, 0); ev(SYN, 0, 0)

def shot():
    chord()
    time.sleep(0.8)                        # the region selector takes the pointer from wherever it is
    to_home(); move(120, 240); time.sleep(0.3)
    ev(EV_KEY, BTN_LEFT, 1); ev(SYN, 0, 0); time.sleep(0.2)
    move(1300, 2100)
    ev(EV_KEY, BTN_LEFT, 0); ev(SYN, 0, 0)

def type_text(text):
    for ch in text:
        code = KEYS.get(ch.lower() if ch not in KEYS else ch)
        if code is None:
            print("no keycode for %r" % ch, flush=True)
        else:
            key(code)

while True:
    if os.path.exists(POWER_FLAG):
        os.unlink(POWER_FLAG)
        key(KEYS["power"])
        print("power", flush=True)
    if os.path.exists(CMD):
        line = open(CMD).read().strip()
        os.unlink(CMD)
        parts = line.split()
        if not parts:
            continue
        cmd = parts[0]
        if cmd == "click":
            click(int(parts[1]), int(parts[2]))
        elif cmd == "drag":
            drag(*[int(v) for v in parts[1:5]])
        elif cmd == "key":
            key(KEYS[parts[1]])
        elif cmd == "type":
            type_text(line[len("type"):].strip())
        elif cmd == "shot":
            shot()
        elif cmd == "shotkey":
            chord()
        elif cmd == "power":
            key(KEYS["power"])
        else:
            print("unknown command %r" % line, flush=True)
        print("did %r" % line, flush=True)
    time.sleep(0.3)
