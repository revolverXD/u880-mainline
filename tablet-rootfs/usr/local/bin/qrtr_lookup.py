#!/usr/bin/env python3
# List QRTR services (like qrtr-lookup): send NEW_LOOKUP to the local control port, print NEW_SERVER replies.
import socket, struct
QRTR_TYPE_NEW_SERVER, QRTR_TYPE_NEW_LOOKUP, PORT_CTRL = 4, 10, 0xfffffffe
s = socket.socket(socket.AF_QIPCRTR, socket.SOCK_DGRAM)

node = 1  # local QRTR node id (Qualcomm default)
s.sendto(struct.pack('<5I', QRTR_TYPE_NEW_LOOKUP, 0, 0, 0, 0), (node, PORT_CTRL))
s.settimeout(2)
names = {400: 'SNS_CLIENT(sensors)', 15: 'DIAG?', 1: 'TEST', 769: 'SLIMBUS', 47: 'IPA?', 7: 'PDR', 66: 'SERVREG_LOC', 64: 'SERVREG_NOTIF', 409: 'SNS_REMOTE?', 288: 'SSCTL?', 43: 'SSCTL', 33: 'QCSPI?'}
try:
    while True:
        d, _ = s.recvfrom(64)
        t, svc, ins, nd, pt = struct.unpack('<5I', d[:20])
        if t == QRTR_TYPE_NEW_SERVER and svc:
            print(f'service {svc:4d} ver {ins & 0xff:3d} inst {ins >> 8:3d}  node {nd:3d} port {pt:5d}  {names.get(svc, "")}')
except socket.timeout:
    pass
