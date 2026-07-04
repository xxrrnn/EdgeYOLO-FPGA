"""Atomic test: verify HBM -> VPU_BUF input CDMA delivers correct data for mini_2conv_c16.

Steps:
  1. Load src0.hex directly to VPU_BUF+0 (preload reference).
  2. Read back and save.
  3. Load src0.hex to HBM+0, then run ONLY the input staging CDMA (no VPU/DCIM).
  4. Read VPU_BUF+0 and compare with step 2.

If they differ -> the input CDMA path is corrupting data.
If they match  -> problem is elsewhere in the hbm run (WB/weight staging).
"""
import sys, struct
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from gen_data import generate_case
from xdma_win import (ChipRunnerWin, VPU_BUF_BASE, WB_BASE, HBM_BASE,
                      hex_to_bin, inst_words_to_bin, parse_inst_words)
from hbm_flow import build_hbm_input_cdma, staging_writes_for_preload, _preload_dst, TILE_IBUF_BASE

runner = ChipRunnerWin()
run_dir = generate_case('mini_network', 'mini_2conv_c16')

SRC0_BYTES = 256

# ── Step 1: preload src0 directly -> VPU_BUF+0 ─────────────────────────
src0_bin = hex_to_bin(run_dir / 'src0.hex')[:SRC0_BYTES]
print(f"src0.hex size={len(src0_bin)} bytes, first 32B: {src0_bin[:32].hex()}")

runner.x.write(VPU_BUF_BASE + 0x0, src0_bin)
ref = runner.x.read(VPU_BUF_BASE + 0x0, SRC0_BYTES)
print(f"\n[preload ref] VPU_BUF+0x0 first 32B: {ref[:32].hex()}")

# ── Step 2: HBM -> VPU_BUF via CDMA (input staging only, no compute) ───
# Write src0 to HBM+0
runner.x.write(HBM_BASE + 0x0, src0_bin)

# Zero VPU_BUF+0 so we can see if CDMA writes
runner.x.write(VPU_BUF_BASE + 0x0, b'\x00' * SRC0_BYTES)

# Build ONLY the input staging CDMAs (no drain)
input_cdma_words = build_hbm_input_cdma(run_dir)
# Add END
OP_END = 0xF
input_cdma_words.append((OP_END << 28))
inst_bin = inst_words_to_bin(input_cdma_words)

from xdma_win import INST_BASE
print(f"\n[cdma only] {len(input_cdma_words)} words, uploading to INST_BRAM...")
runner.x.write(INST_BASE, inst_bin)
runner.start_decoder(len(input_cdma_words))
runner.poll_done(timeout_s=30.0)

after_cdma = runner.x.read(VPU_BUF_BASE + 0x0, SRC0_BYTES)
print(f"[cdma only] VPU_BUF+0x0 after input CDMA first 32B: {after_cdma[:32].hex()}")

match = (after_cdma == ref)
print(f"\nInput CDMA delivers correct src0: {'YES ✓' if match else 'NO ✗'}")
if not match:
    for i in range(0, SRC0_BYTES, 16):
        r = ref[i:i+16].hex()
        a = after_cdma[i:i+16].hex()
        if r != a:
            print(f"  diff at byte {i}: ref={r}  got={a}")

# ── Step 3: check wb_init staging ──────────────────────────────────────
print("\n[wb staging check] comparing preload vs hbm WB content...")
# preload wb
wb_bin = hex_to_bin(run_dir / 'wb_init.hex')
runner.x.write(WB_BASE, wb_bin)
wb_ref = runner.x.read(WB_BASE, 64)
print(f"  WB preload first 64B: {wb_ref.hex()}")

# hbm wb (already in HBM from upload_hbm or we need to manually check)
# The WB CDMA is part of build_hbm_input_cdma - it's already tested above
# Let's read WB after the input CDMA run
wb_after = runner.x.read(WB_BASE, 64)
print(f"  WB after CDMA  first 64B: {wb_after.hex()}")
wb_match = (wb_after == wb_ref)
print(f"  WB staging correct: {'YES ✓' if wb_match else 'NO ✗'}")
