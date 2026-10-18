# Tiny arm64 "kernel" (valid Image header) that immediately calls PSCI SYSTEM_RESET (smc, then hvc).
# Used as an automatic oracle for "did ABL accept the boot image": accepted -> device resets into Android.
import struct,sys
code=[0x52800120,  # movz w0, #0x9
      0x72b08000,  # movk w0, #0x8400, lsl #16  -> 0x84000009 PSCI SYSTEM_RESET
      0xd4000003,  # smc #0
      0x52800120, 0x72b08000,
      0xd4000002,  # hvc #0
      0x14000000]  # b .
hdr=struct.pack('<IIQQQQQQII',0x14000010,0xd503201f,0,4096,0xa,0,0,0,0x644d5241,0)
img=hdr+b''.join(struct.pack('<I',c) for c in code)
open(sys.argv[1],'wb').write(img.ljust(4096,b'\0'))
