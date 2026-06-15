"""Minimal step-by-step debug for dcim_tiny_1x1."""
import sys, time, struct
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from xdma_win import (
    XDMAWin, hex_to_bin, hex_to_bin_32bit,
    REGS_BASE, INST_BASE, TILE_IBUF_BASE, TILE_OBUF_BASE,
    REG_INST_COUNT, REG_DECODER_CTRL, REG_DECODER_STATUS,
)

x = XDMAWin(verbose=False)
run_dir = Path("runs/dcim_matmul_dcim_tiny_1x1_qint8")

print("[1] Upload activations to TILE_IBUF[0] act region")
act_data = hex_to_bin(run_dir / "act.hex")
print(f"    act.hex: {len(act_data)} bytes")
x.write(TILE_IBUF_BASE, act_data)
print("    OK")

print("[2] Upload weights to TILE_IBUF[0] weight region")
wei_data = hex_to_bin(run_dir / "weight_tile0.hex")
print(f"    weight_tile0.hex: {len(wei_data)} bytes")
x.write(TILE_IBUF_BASE + 0x40000, wei_data)
print("    OK")

print("[3] Upload instructions to INST_BRAM")
inst_data = hex_to_bin_32bit(run_dir / "inst.hex")
n_words = len(inst_data) // 4
print(f"    inst.hex: {n_words} words ({len(inst_data)} bytes)")
x.write(INST_BASE, inst_data)
print("    OK")

print("[4] Write INST_COUNT and start decoder")
x.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
time.sleep(0.001)
x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
print("    Decoder started")

print("[5] Poll DECODER_STATUS")
for i in range(100):
    st = x.read_u32(REGS_BASE + REG_DECODER_STATUS)
    if st & 0x2:
        print(f"    DONE (status=0x{st:08x}) after {i+1} polls")
        break
    if st & 0x80000000:
        print(f"    ERROR (status=0x{st:08x})")
        sys.exit(1)
    time.sleep(0.01)
else:
    print(f"    TIMEOUT (last status=0x{st:08x})")
    sys.exit(1)

print("[6] Read results from TILE_OBUF[0]")
# checks.txt says: dst=0x800000 which maps to TILE_OBUF_BASE + 0
# 128 words * 16 bytes = 2048 bytes
nbytes = 128 * 16
print(f"    Reading {nbytes} bytes from TILE_OBUF[0]...")
t0 = time.time()
got = x.read(TILE_OBUF_BASE, nbytes)
elapsed = time.time() - t0
print(f"    Read done in {elapsed:.3f}s")

print("[7] Compare with expected")
exp_data = hex_to_bin(run_dir / "expected.hex")
exp_data = exp_data[:nbytes]

n_pass = 0
n_fail = 0
first_fail = None
for w in range(128):
    off = w * 16
    exp_w = exp_data[off:off+16]
    got_w = got[off:off+16]
    if exp_w == got_w:
        n_pass += 1
    else:
        n_fail += 1
        if first_fail is None:
            first_fail = (w, exp_w.hex(), got_w.hex())

print(f"    PASS: {n_pass}  FAIL: {n_fail}  TOTAL: 128")
if first_fail:
    w, e, g = first_fail
    print(f"    First mismatch at word {w}:")
    print(f"      exp: {e}")
    print(f"      got: {g}")
    sys.exit(1)
else:
    print("    ALL 128 WORDS MATCH!")
    sys.exit(0)
