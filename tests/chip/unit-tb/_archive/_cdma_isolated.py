"""Isolated test: preload + exec, then single CDMA tile_obuf[0][0..15] -> HBM, compare."""
from pathlib import Path
import struct
from xdma_win import (
    ChipRunnerWin, XDMAWin, HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
    hex_to_bin, inst_words_to_bin, parse_inst_words,
)
from hbm_flow import cdma_copy, _header, OP_WAIT_CDMA, OP_END

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")

runner = ChipRunnerWin(verbose=True)

# Step 1: preload + run core only (no drain)
runner.upload_preload(run_dir)
n_words = runner.upload_inst_raw(run_dir)
runner.clear_tile_obufs(128, wpt=4)
runner.start_decoder(n_words)
runner.poll_done(60.0)
print("\n[CORE DONE] tile_obuf[0] should now have correct data\n")

# Step 2: read tile_obuf[0] directly
obuf0 = runner.x.read(TILE_OBUF_BASE, 16 * 16)
print("=== Direct tile_obuf[0] read (words 0..15) ===")
for i in range(16):
    w = obuf0[i*16:(i+1)*16]
    print(f"  word {i:2d}: {w.hex()}")

# Step 3: zero HBM output area
runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * 256)

# Step 4: issue a single 256B CDMA: tile_obuf[0][word 0..15] -> HBM[0x100000]
# Build a minimal instruction stream: CDMA + WAIT_CDMA + END
insts = cdma_copy(TILE_OBUF_BASE, HBM_BASE + HBM_OFF_OUTPUT, 256)
insts.append(_header(OP_END, 0, 0))
data = inst_words_to_bin(insts)
total_words = len(data) // 4
runner.x.write(INST_BASE, data)
runner.start_decoder(total_words)
runner.poll_done(30.0)
print("\n[CDMA DONE] 256B tile_obuf[0] -> HBM\n")

# Step 5: read HBM and compare
hbm = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 256)
print("=== HBM readback vs tile_obuf[0] ===")
all_ok = True
for i in range(16):
    exp = obuf0[i*16:(i+1)*16]
    got = hbm[i*16:(i+1)*16]
    ok = "OK" if exp == got else "FAIL"
    if exp != got:
        all_ok = False
        diffs = [(b, exp[b], got[b]) for b in range(16) if exp[b] != got[b]]
        diff_str = " ".join(f"[{b}]:{e:02x}->{g:02x}" for b, e, g in diffs)
        print(f"  word {i:2d}: {ok}  {diff_str}")
    else:
        print(f"  word {i:2d}: {ok}")

print(f"\n{'PASS' if all_ok else 'FAIL'} - tile_obuf -> HBM single CDMA")
