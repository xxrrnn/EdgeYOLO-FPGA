"""Smoke test: host can only DMA to HBM and INST_BRAM."""
import struct
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))

from xdma_win import XDMAWin, HBM_BASE, INST_BASE

x = XDMAWin(verbose=False)
all_pass = True


def check(label, wrote, got):
    global all_pass
    ok = wrote == got
    if not ok:
        all_pass = False
    print(f"  {label:30s} {'PASS' if ok else 'FAIL'}")
    if not ok:
        print(f"    wrote:    {wrote.hex()}")
        print(f"    readback: {got.hex()}")


print("=" * 60)
print("XDMA Smoke Test (HBM + INST_BRAM only)")
print("=" * 60)

print("\n[1] HBM write/read @ 0x0")
d1 = bytes(range(16))
x.write(HBM_BASE, d1)
check("HBM word0", d1, x.read(HBM_BASE, 16))

print("\n[2] HBM bulk 256B @ 0x1000")
d2 = bytes([(i * 7 + 3) & 0xFF for i in range(256)])
x.write(HBM_BASE + 0x1000, d2)
check("HBM 256B bulk", d2, x.read(HBM_BASE + 0x1000, 256))

print("\n[3] INST_BRAM write/read @ 0x{:010x}".format(INST_BASE))
d3 = struct.pack("<4I", 0x00000000, 0xF0000000, 0x12345678, 0xABCDEF01)
x.write(INST_BASE, d3)
check("INST_BRAM 4 words", d3, x.read(INST_BASE, 16))

print("\n" + "=" * 60)
if all_pass:
    print("ALL TESTS PASSED")
else:
    print("SOME TESTS FAILED")
    sys.exit(1)
