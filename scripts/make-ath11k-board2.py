#!/usr/bin/env python3
"""Wrap a vendor WLAN board-data file (e.g. bdwlan.elf from the tablet's firmware_mnt/image/qca6750/) into
ath11k's board-2.bin container, so ath11k uses the device's own calibration instead of linux-firmware's
reference-board entry.

Usage: make-ath11k-board2.py BOARD_FILE OUT_board-2.bin NAME [NAME...]
  NAME is the ath11k lookup key, e.g. "bus=ahb,qmi-chip-id=1,qmi-board-id=255" (U880 WCN6750: chip_id 0x1,
  board_id 0xff from the ath11k "chip_id ... board_id ..." log line).
Format (drivers/net/wireless/ath/ath11k/hw.h): "QCA-ATH11K-BOARD\\0" padded to 4, then IEs {u32 id, u32 len,
data padded to 4}; IE 0 = BOARD containing sub-IEs 0 = NAME, 1 = DATA.
"""
import struct, sys

def ie(ie_id, data):
    pad = (4 - len(data) % 4) % 4
    return struct.pack('<II', ie_id, len(data)) + data + b'\0' * pad

def main():
    board, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    if not names:
        sys.exit(__doc__)
    data = open(board, 'rb').read()
    magic = b'QCA-ATH11K-BOARD\0'
    blob = magic + b'\0' * ((4 - len(magic) % 4) % 4)
    for name in names:
        blob += ie(0, ie(0, name.encode()) + ie(1, data))
    open(out, 'wb').write(blob)
    print(f'{out}: {len(blob)} bytes, {len(names)} entr{"y" if len(names) == 1 else "ies"} from {board}')

main()
