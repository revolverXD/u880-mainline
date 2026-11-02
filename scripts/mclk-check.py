#!/usr/bin/env python3
"""Is the camera MCLK really at the pad? Reads CAMCC and TLMM registers over /dev/mem.

Needs a kernel with DEVMEM=y (merge kernel/dev-devmem.config), RAM-booted, run as root:
  python3 mclk-check.py            # everything
  python3 mclk-check.py 64 68      # only poll the mux pad of GPIO_64 (rear) and GPIO_68 (front)
  python3 mclk-check.py 72 73      # the front port's SDA1/SCL1 pads - run it while that bus has traffic
                                   # (a probe loop), that is what proves a master really drives its pins

Register offsets are the ones the kernel drivers use: drivers/clk/qcom/camcc-sm8650.c (camcc at 0xade0000),
and the NEW TLMM layout of this SoC, drivers/pinctrl/qcom/pinctrl-cliffs.c PINGROUP(): every pin has its own
0x1000 block at ctl_reg = 0x100000 + 0x1000 * n, with io_reg = ctl_reg + 4 (pinctrl-msm.c:
ctl bit mux_bit=2 holds the index into the pin's funcs list; io_reg bit0 = input read-back, bit1 = driven
value, bit9 = output enable). The old PIN_MUX_CTL(n) = 4n / PIN_CONFIG(n) = 0x1000 + 4n layout does NOT
apply here - reading it returns unrelated registers.

The pad question is answered by the poll of io_reg bit0: a pin that carries a clock shows both levels, a dead
pin reads constant. Calibrate the method in the same run by polling GPIO_70/71 (cci_i2c_sda0/scl0, which the
CCI driver is definitely clocking during an i2c transfer) - if those come out static too, the poll proves
nothing about output pads.
"""
import mmap
import os
import sys

CAMCC = 0xade0000
TLMM = 0xf000000  # dts/u880.dts tlmm: pinctrl@f000000, reg = <0xf000000 0x1000000>
REF = 19200000  # bi_tcxo, the xo this board runs (clock-summary says 19.2 MHz)

# name -> offset inside camcc, from camcc-sm8650.c
CLKS = {
    "pll2": (0x2000, "alpha PLL, RIVIAN_EVO: opmode +0x04 status +0x0c l +0x10 user_ctl +0x14"),
    "mclk0_src": (0x15000, "rcg2 cmd_rcgr; cfg at +0x04 (src 2:0, pre_div 5:3), m/n +0x08, div +0x0c"),
    "mclk0": (0x15018, "branch ctrl: bit0 CTL_ENABLE, bit31 CLK_OFF, bits30:28 NOC_FSM_STATUS"),
    "mclk4_src": (0x15070, "rcg2, the front sensor's clock (F35 correction)"),
    "mclk4": (0x15088, "branch"),
    "cci0_src": (0x131cc, "rcg2, proves a working camcc output for comparison (37.5 MHz)"),
    "cci0": (0x131e4, "branch"),
    "cci1_src": (0x131e8, "rcg2, the CCI controller's second master (the front port), F37"),
    "cci1": (0x13200, "branch"),
}


def region(base, size):
    fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
    return mmap.mmap(fd, size, mmap.MAP_SHARED, mmap.PROT_READ, offset=base)


def rd(mem, off):
    return int.from_bytes(mem[off:off + 4], "little")


def main():
    poll_only = [int(a) for a in sys.argv[1:]]
    if not poll_only:
        cam = region(CAMCC, 0x20000)
        for name, (off, note) in CLKS.items():
            if name == "pll2":
                vals = {r: rd(cam, off + r) for r in (0x04, 0x0c, 0x10, 0x14, 0x1c, 0x20, 0x24)}
                status, l = vals[0x0c], vals[0x10]
                print(f"cam_cc_pll2 (0x{CAMCC + off:x}):")
                for r, v in vals.items():
                    print(f"  +0x{r:02x} = 0x{v:08x}")
                print(f"  STATUS(+0x0c) bit31 = {(status >> 31) & 1} (this driver has no is_locked op for "
                      f"RIVIAN_EVO, so it is not a proven lock bit), l = {l}, "
                      f"VCO would be {REF * l / 1e6:.1f} MHz")
            else:
                vals = [(o, rd(cam, o)) for o in (off, off + 4, off + 8, off + 12, off + 16)]
                if not name.endswith("_src"):
                    v = vals[0][1]
                    fsm = (v >> 28) & 7
                    print(f"cam_cc_{name} (0x{CAMCC + off:x}) = 0x{v:08x}  "
                          f"CTL_ENABLE={v & 1} CLK_OFF={(v >> 31) & 1} NOC_FSM_STATUS={fsm} "
                          f"({'RUNNING' if (v & 1) and not ((v >> 31) & 1) and fsm != 7 else 'not running'})")
                else:
                    cmd, cfg = vals[0][1], vals[1][1]
                    print(f"cam_cc_{name} (0x{CAMCC + off:x}): " +
                          " ".join(f"+0x{o - off:02x}=0x{v:08x}" for o, v in vals))
                    print(f"  ROOT_OFF(bit31 of cmd)={(cmd >> 31) & 1} UPDATE(bit14)={(cmd >> 14) & 1} "
                          f"src_sel={cfg & 7} pre_div={(cfg >> 3) & 0x1f} cfg=0x{cfg:08x}  # {note}")
    # pinctrl-cliffs.c PINGROUP(id, f1, f2, ...) -> funcs[0] = gpio, funcs[i] = fi
    FUNCS = {
        64: "cam_mclk cri_trng0 qdss_gpio0", 65: "cam_mclk cri_trng1 qdss_gpio1",
        66: "cam_mclk prng_rosc0 qdss_gpio2", 67: "cam_mclk qdss_gpio3",
        68: "cam_aon_mclk4 prng_rosc1 qdss_gpio4", 69: "cam_mclk tmess_prng3 qdss_gpio5",
        70: "cci_i2c_sda0 tmess_prng2 qdss_gpio6", 71: "cci_i2c_scl0 qdss_gpio7",
        72: "cci_i2c_sda1 tmess_prng1 qdss_gpio8", 73: "cci_i2c_scl1 tmess_prng0 qdss_gpio9",
    }
    tlmm = region(TLMM, 0x100000 + 0x1000 * 80)
    for pin in (poll_only or [64, 68, 70, 71]):
        ctl, io = rd(tlmm, 0x100000 + 0x1000 * pin), rd(tlmm, 0x100000 + 0x1000 * pin + 4)
        f = (ctl >> 2) & 0xF
        names = "gpio " + FUNCS.get(pin, "")
        fn = names.split()[f] if f < len(names.split()) else f
        print(f"GPIO_{pin}: CTL=0x{ctl:08x} -> function {f} = {fn}; IO=0x{io:08x} "
              f"(in={io & 1} out={(io >> 1) & 1} oe={(io >> 9) & 1})")
        seen, ones, in1, n = {}, 0, 0, 400
        for _ in range(n):
            v = rd(tlmm, 0x100000 + 0x1000 * pin + 4)
            seen[v] = seen.get(v, 0) + 1
            in1 += v & 1
            ones += (v >> 1) & 1
        flip = [b for b in range(32) if len({(v >> b) & 1 for v in seen}) > 1]
        print(f"  {n} reads of IO: {len(seen)} different values, bits that changed: {flip}, "
              f"io bit0 (input read-back) was 1 in {in1}/{n}, bit1 (driven) was 1 in {ones}/{n}")
        print(f"  -> {'the pad is TOGGLING (clock present)' if in1 and in1 < n else 'the pad is STATIC (no clock)'}")


main()
