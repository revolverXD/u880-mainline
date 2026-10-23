#!/usr/bin/env python3
# BlueZ GATT server + LE advertisement for phone tests (nRF Connect): service FFE0, characteristic FFE1 (read/write/notify).
# Reads return the stored value, writes replace it (logged), notify sends a counter every 2 s once subscribed. Run as root on the tablet.
import dbus, dbus.mainloop.glib, dbus.service, sys, time
from gi.repository import GLib

BUS = "org.bluez"
SVC, CHR = "0000ffe0-0000-1000-8000-00805f9b34fb", "0000ffe1-0000-1000-8000-00805f9b34fb"
def log(*a): print(time.strftime("%H:%M:%S"), *a, flush=True)

class App(dbus.service.Object):
    def __init__(self, bus): super().__init__(bus, "/test"); self.objs = {}
    def add(self, o): self.objs[o.path] = o
    @dbus.service.method("org.freedesktop.DBus.ObjectManager", out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self): return {p: o.props() for p, o in self.objs.items()}

class Service(dbus.service.Object):
    def __init__(self, bus): self.path = "/test/service0"; super().__init__(bus, self.path)
    def props(self): return {"org.bluez.GattService1": {"UUID": SVC, "Primary": True}}

class Char(dbus.service.Object):
    def __init__(self, bus, svc):
        self.path = svc.path + "/char0"; self.svc = svc; self.value = [dbus.Byte(b) for b in b"U880 hello"]; self.notifying = False; self.n = 0
        super().__init__(bus, self.path)
    def props(self):
        return {"org.bluez.GattCharacteristic1": {"UUID": CHR, "Service": dbus.ObjectPath(self.svc.path), "Flags": ["read", "write", "write-without-response", "notify"]}}
    @dbus.service.method("org.bluez.GattCharacteristic1", in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, opts): log("READ ->", bytes(self.value)); return self.value
    @dbus.service.method("org.bluez.GattCharacteristic1", in_signature="aya{sv}")
    def WriteValue(self, value, opts): self.value = value; log("WRITE <-", bytes(value).hex(), bytes(value))
    @dbus.service.method("org.bluez.GattCharacteristic1")
    def StartNotify(self):
        log("NOTIFY subscribed"); self.notifying = True
        GLib.timeout_add_seconds(2, self.tick)
    @dbus.service.method("org.bluez.GattCharacteristic1")
    def StopNotify(self): log("NOTIFY unsubscribed"); self.notifying = False
    def tick(self):
        if not self.notifying: return False
        self.n += 1; self.value = [dbus.Byte(self.n & 0xff)]
        self.PropertiesChanged("org.bluez.GattCharacteristic1", {"Value": self.value}, [])
        return True
    @dbus.service.signal("org.freedesktop.DBus.Properties", signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, inval): pass

class Adv(dbus.service.Object):
    def __init__(self, bus): self.path = "/test/adv0"; super().__init__(bus, self.path)
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return {"Type": "peripheral", "ServiceUUIDs": dbus.Array([SVC], signature="s"), "LocalName": "U880-BLE", "Includes": dbus.Array(["tx-power"], signature="s")}
    @dbus.service.method("org.bluez.LEAdvertisement1")
    def Release(self): log("advertisement released")

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
adapter = "/org/bluez/hci0"
app = App(bus); svc = Service(bus); ch = Char(bus, svc); app.add(svc); app.add(ch); adv = Adv(bus)
mgr = dbus.Interface(bus.get_object(BUS, adapter), "org.bluez.GattManager1")
mgr.RegisterApplication(app, {}, reply_handler=lambda: log("GATT application registered"), error_handler=lambda e: (log("GATT error", e), sys.exit(1)))
am = dbus.Interface(bus.get_object(BUS, adapter), "org.bluez.LEAdvertisingManager1")
am.RegisterAdvertisement(adv, {}, reply_handler=lambda: log("advertising as U880-BLE"), error_handler=lambda e: (log("ADV error", e), sys.exit(1)))
def conn(iface, changed, inval, path=None):
    if "Connected" in changed: log("device", path, "connected" if changed["Connected"] else "disconnected")
bus.add_signal_receiver(conn, "PropertiesChanged", "org.freedesktop.DBus.Properties", BUS, path_keyword="path")
GLib.MainLoop().run()
