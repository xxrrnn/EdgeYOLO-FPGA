"""Quick smoke test: verify XDMA read/write to all FPGA memory regions."""
import struct
import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parent))

from xdma_win import (
    XDMAWin, REGS_BASE, VPU_BUF_BASE, VPU_WB_BASE,
    TILE_IBUF_BASE, TILE_OBUF_BASE, INST_BASE,
)

x = XDMAWin(verbose=False)
all_pass = True

def check(label, wrote, got):
    global all_pass
    ok = wrote == got
    status = "PASS" if ok else "FAIL"
    if not ok:
        all_pass = False
    print(f"  {label:30s} {status}")
    if not ok:
        print(f"    wrote:    {wrote.hex()}")
        print(f"    readback: {got.hex()}")
    return ok

print("=" * 60)
print("XDMA Smoke Test - EdgeYOLO-FPGA-lite")
print("=" * 60)

# 1. Register read
print("\n[1] Register Read")
for name, off in [("STATUS", 0x04), ("DECODER_CTRL", 0x38),
                  ("INST_COUNT", 0x3C), ("DECODER_STATUS", 0x40)]:
    val = x.read_u32(REGS_BASE + off)
    print(f"  {name:20s} (0x{off:02x}) = 0x{val:08x}")

# 2. VPU_BUF write/read
print("\n[2] VPU_BUF Write/Read (16 bytes @ 0x{:010x})".format(VPU_BUF_BASE))
d = bytes([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
           0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0])
x.write(VPU_BUF_BASE, d)
check("VPU_BUF word 0", d, x.read(VPU_BUF_BASE, 16))

# 3. TILE_IBUF[0]
print("\n[3] TILE_IBUF[0] Write/Read (16 bytes @ 0x{:010x})".format(TILE_IBUF_BASE))
d2 = bytes(range(16))
x.write(TILE_IBUF_BASE, d2)
check("TILE_IBUF[0] word 0", d2, x.read(TILE_IBUF_BASE, 16))

# 4. TILE_OBUF[0]
print("\n[4] TILE_OBUF[0] Write/Read (16 bytes @ 0x{:010x})".format(TILE_OBUF_BASE))
d3 = bytes([0xFF - i for i in range(16)])
x.write(TILE_OBUF_BASE, d3)
check("TILE_OBUF[0] word 0", d3, x.read(TILE_OBUF_BASE, 16))

# 5. INST_BRAM
print("\n[5] INST_BRAM Write/Read (16 bytes @ 0x{:010x})".format(INST_BASE))
d4 = struct.pack("<4I", 0x00000000, 0xF0000000, 0x12345678, 0xABCDEF01)
x.write(INST_BASE, d4)
check("INST_BRAM 4 words", d4, x.read(INST_BASE, 16))

# 6. VPU WB
print("\n[6] VPU_WB Write/Read (16 bytes @ 0x{:010x})".format(VPU_WB_BASE))
d5 = bytes([0xA0 + i for i in range(16)])
x.write(VPU_WB_BASE, d5)
check("VPU_WB word 0", d5, x.read(VPU_WB_BASE, 16))

# 7. Larger block: 256 bytes to VPU_BUF
print("\n[7] VPU_BUF Bulk Write/Read (256 bytes)")
d6 = bytes([(i * 7 + 3) & 0xFF for i in range(256)])
x.write(VPU_BUF_BASE + 0x100, d6)
check("VPU_BUF 256B bulk", d6, x.read(VPU_BUF_BASE + 0x100, 256))

print("\n" + "=" * 60)
if all_pass:
    print("ALL TESTS PASSED")
else:
    print("SOME TESTS FAILED")
    sys.exit(1)
