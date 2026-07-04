"""
Deep root cause analysis for three distinct failure modes found in L2.

Issue A: DCIM multi-tile hbm FAIL (preload OK)
  - conv1_c64_to32: N=32, active_tiles=2, always 192/256 pass (tile0's 3/4 data OK?)
  - conv3_c128_to128: N=128, active_tiles=8, always 128/256 pass (tile0 OK only?)
  - Hypothesis: remap or HBM staging size error

Issue B: DQA/QA c>=32 hbm FAIL (preload OK), got=all-zero
  - dqa_c32: 10/120 pass (first 10 words from HBM OK, rest zero)
  - qa_c64: 0/60 pass (nothing written)
  - Hypothesis: HBM output staging zero-region too small, drain CDMA writes beyond it

Issue C: im2col c>=32 preload FAIL
  - im2col_3x3_s2_c32 preload: 238/256 (18 words wrong, got=non-zero but wrong)
  - Hypothesis: residual data in VPU_BUF from previous run contaminates result
"""
import sys, struct
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT,
    VPU_BUF_BASE, DCIM_NUM_TILES,
    DCIM_INT8_OUT_WORDS_PER_TILE,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
)
from hbm_flow import (
    build_hbm_output_drain, hbm_drain_remap,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
)
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

# ═══════════════════════════════════════════════════════════════════
# ISSUE A: DCIM multi-tile drain remap analysis
# ═══════════════════════════════════════════════════════════════════
print("=" * 70)
print("ISSUE A: DCIM multi-tile HBM drain analysis")
print("=" * 70)

for module, variant, quant in [
    ("dcim_matmul", "conv1_c64_to32", "int8"),       # N=32, 2 active tiles
    ("dcim_matmul", "conv3_c128_to128", "int8"),      # N=128, 8 active tiles
]:
    rd = generate_case(module, variant, quant=quant)
    checks_line = next(
        l for l in (rd / "checks.txt").read_text().splitlines()
        if l.strip() and not l.startswith("#")
    )
    parts = checks_line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])
    wpt = int(parts[5]) if len(parts) > 5 else DCIM_INT8_OUT_WORDS_PER_TILE

    matmul_n = _matmul_n_from_manifest(rd)
    active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
    stride = DCIM_NUM_TILES * wpt
    n_pixels = (n_words + stride - 1) // stride
    n_tile_words = n_pixels * wpt
    total_hbm_bytes = active_tiles * n_tile_words * 16

    # Check how many bytes were zero-staged vs how many drain CDMA will write
    # From upload_hbm: only zeros n_words * 16 bytes
    staged_zeros = n_words * 16
    drain_writes = total_hbm_bytes

    print(f"\n{variant}: N={matmul_n} active_tiles={active_tiles} wpt={wpt}")
    print(f"  n_words={n_words}  n_pixels={n_pixels}  n_tile_words={n_tile_words}")
    print(f"  HBM zero-staged:  {staged_zeros:6} bytes ({n_words} words × 16)")
    print(f"  Drain CDMA total: {drain_writes:6} bytes ({active_tiles} tiles × {n_tile_words} words × 16)")

    if drain_writes > staged_zeros:
        print(f"  *** STAGING UNDERSIZE: drain writes {drain_writes - staged_zeros} bytes BEYOND staged region!")
    elif drain_writes == staged_zeros:
        print(f"  Staging size OK (equal)")
    else:
        print(f"  Staging oversized (OK)")

    # Also check remap: does the remap invert correctly?
    # Run preload to get tile_obuf data, then manually simulate drain+remap
    runner.upload_preload(rd)
    inst_words = runner.upload_inst_raw(rd)
    runner.start_decoder(inst_words)
    runner.poll_done(timeout_s=60.0)

    # Read each active tile's obuf
    tile_data = []
    for t in range(active_tiles):
        d = xdma.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, n_tile_words * 16)
        tile_data.append(d)

    # Simulate the remap: construct flat bytes as drain would produce
    flat = b"".join(tile_data)
    remapped = hbm_drain_remap(rd, flat)

    from xdma_win import hex_to_bin, compare_result
    exp = hex_to_bin(rd / "expected.hex")[:n_words * 16]
    cmp = compare_result(variant, exp, remapped, n_words, is_fp32=False)
    remap_status = "PASS" if cmp["pass"] else f"FAIL ({cmp['passed']}/{cmp['total_words']})"
    print(f"  Simulated remap check: {remap_status}")
    if not cmp["pass"] and cmp["first_mismatch"]:
        m = cmp["first_mismatch"]
        print(f"    first_mismatch @ word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")

# ═══════════════════════════════════════════════════════════════════
# ISSUE B: DQA/QA output staging size analysis
# ═══════════════════════════════════════════════════════════════════
print("\n" + "=" * 70)
print("ISSUE B: DQA/QA HBM output staging size")
print("=" * 70)

for module, variant, quant in [
    ("dqa", "dqa_c16_small", "int8"),   # PASS baseline
    ("dqa", "dqa_c32_mid",   "int8"),   # FAIL
    ("qa",  "qa_c16_signed", "int8"),   # PASS baseline
    ("qa",  "qa_c64_clip",   "int8"),   # FAIL
]:
    rd = generate_case(module, variant, quant=quant)
    checks_line = next(
        l for l in (rd / "checks.txt").read_text().splitlines()
        if l.strip() and not l.startswith("#")
    )
    parts = checks_line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])

    # For VPU_BUF path (dst_off < 0x800000), drain = n_words * 16 bytes
    drain_bytes = n_words * 16

    # upload_hbm zeros: also n_words * 16 (from upload_hbm logic)
    staged_zeros = n_words * 16

    print(f"\n{module}/{variant}: dst_off=0x{dst_off:x} n_words={n_words}")
    print(f"  Zero-staged:  {staged_zeros} bytes")
    print(f"  Drain writes: {drain_bytes} bytes")
    print(f"  {'OK' if staged_zeros >= drain_bytes else 'UNDERSIZE'}")

    # Now check: what is the actual HBM staging offset?
    from xdma_win import HBM_OFF_OUTPUT
    print(f"  HBM output slot: 0x{HBM_OFF_OUTPUT:x}  "
          f"end=0x{HBM_OFF_OUTPUT + drain_bytes:x}")

    # Run hbm and read raw HBM to see what was written
    runner.upload_hbm(rd)
    runner.upload_inst(rd, drain_output=True)
    # upload_inst already writes inst; now just start
    # We need to re-upload inst to get n_words back
    from hbm_flow import patch_inst_for_hbm
    inst_bytes = patch_inst_for_hbm(rd, drain_output=True)
    n_inst = len(inst_bytes) // 4
    xdma.write(0x104000000, inst_bytes)
    runner.start_decoder(n_inst)
    runner.poll_done(timeout_s=30.0)

    # Read HBM output region
    raw = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, min(drain_bytes + 256, 4096))
    nonzero_words = sum(1 for i in range(0, len(raw), 16) if any(raw[i:i+16]))
    print(f"  HBM readback: {nonzero_words}/{len(raw)//16} words non-zero")
    if nonzero_words < n_words:
        print(f"  *** Only {nonzero_words} words written — drain CDMA incomplete!")

# ═══════════════════════════════════════════════════════════════════
# ISSUE C: im2col preload contamination check
# ═══════════════════════════════════════════════════════════════════
print("\n" + "=" * 70)
print("ISSUE C: im2col_3x3_s2_c32 preload contamination check")
print("=" * 70)

rd = generate_case("im2col", "im2col_3x3_s2_c32", quant="int8")
checks_line = next(
    l for l in (rd / "checks.txt").read_text().splitlines()
    if l.strip() and not l.startswith("#")
)
parts = checks_line.split()
dst_off = int(parts[2], 16)
n_words = int(parts[3])
print(f"dst_off=0x{dst_off:x}  n_words={n_words}")

# Zero out VPU_BUF output region before running
zero_buf = b"\x00" * (n_words * 16)
xdma.write(VPU_BUF_BASE + dst_off, zero_buf)
print(f"Zeroed VPU_BUF[0x{dst_off:x}..0x{dst_off + n_words*16:x}] ({n_words*16} bytes)")

# Now run preload
runner.upload_preload(rd)
inst_words = runner.upload_inst_raw(rd)
runner.start_decoder(inst_words)
runner.poll_done(timeout_s=180.0)

# Compare
from xdma_win import hex_to_bin, compare_result
got_raw = xdma.read(VPU_BUF_BASE + dst_off, n_words * 16)
exp_raw = hex_to_bin(rd / "expected.hex")[:n_words * 16]
cmp = compare_result("im2col_3x3_s2_c32", exp_raw, got_raw, n_words, is_fp32=False)
zero_result = "PASS" if cmp["pass"] else f"FAIL ({cmp['passed']}/{cmp['total_words']})"
print(f"After pre-zeroing: {zero_result}")
if not cmp["pass"] and cmp["first_mismatch"]:
    m = cmp["first_mismatch"]
    print(f"  first_mismatch @ word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")
    got_bytes = bytes.fromhex(m["got"]) if isinstance(m["got"], str) else b""
    if all(b == 0 for b in got_bytes):
        print("  *** got=all-zero: output region not written (im2col calculation issue?)")
    else:
        print("  *** got=non-zero but wrong: computation error")

print("\nDone.")
