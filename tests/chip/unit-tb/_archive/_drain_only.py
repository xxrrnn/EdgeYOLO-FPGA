"""
Isolate: drain CDMA from tile_obuf to HBM.
1. Run preload path for conv3_s2 → tile_obuf has correct data
2. Manually issue ONLY the drain CDMA (no compute) via inst patch
3. Check if HBM got the data
4. If not: check if a HOST write to HBM works → isolate AXI path
"""
import sys, struct, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT, INST_BASE,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    inst_words_to_bin, hex_to_bin,
)
from hbm_flow import (
    build_hbm_output_drain, hbm_drain_remap,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
    OP_CDMA_COPY, OP_WAIT_CDMA, OP_END,
    cdma_copy, parse_inst_words,
)
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

rd = generate_case("dcim_matmul", "conv3_s2_c32_to64")
WPT = 4
matmul_n = _matmul_n_from_manifest(rd)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
stride = DCIM_NUM_TILES * WPT
n_words = 256
n_pixels = (n_words + stride - 1) // stride
n_tile_words = n_pixels * WPT

print(f"conv3_s2_c32_to64: active_tiles={active_tiles} n_tile_words={n_tile_words}")

# ── Step 1: preload → tile_obuf has correct data ──────────────────
print("\n[1] Preload run to populate tile_obuf...")
runner.upload_preload(rd)
n_inst = runner.upload_inst_raw(rd)
runner.start_decoder(n_inst)
runner.poll_done(timeout_s=60.0)
preload_results = runner.read_check(rd, from_hbm=False)
pr = preload_results[0]
pre_s = "PASS" if pr["pass"] else f"FAIL {pr['passed']}/{pr['total_words']}"
print(f"    preload check: {pre_s}")

# Read tile_obuf directly
tile_data = []
for t in range(active_tiles):
    d = xdma.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, n_tile_words * 16)
    nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
    print(f"    tile_obuf[{t}]: {nz}/{n_tile_words} non-zero words")
    tile_data.append(d)

# ── Step 2: Issue ONLY drain CDMA (no preceding compute) ─────────
print("\n[2] Issue drain CDMA only (tile_obuf → HBM, no compute)...")

# Clear HBM output region
out_bytes = active_tiles * n_tile_words * 16
xdma.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * out_bytes)
print(f"    Zeroed HBM output: {out_bytes}B @ 0x{HBM_OFF_OUTPUT:x}")

# Build drain-only inst: just drain CDMAs + END
drain_insts, _ = build_hbm_output_drain(rd)
drain_only = drain_insts + [0xF0000000]  # END
drain_bytes = inst_words_to_bin(drain_only)
n_drain_words = len(drain_bytes) // 4

xdma.write(INST_BASE, drain_bytes)
print(f"    Drain inst: {n_drain_words} words")

# Start decoder
xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_drain_words)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
time.sleep(0.001)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

# Poll done
t0 = time.time()
while time.time() - t0 < 10.0:
    st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
    if st & 0x2:
        break
    time.sleep(0.002)
print(f"    DECODER_STATUS = 0x{st:08x} (done={bool(st&2)})")

# Read HBM to see what was written
print("\n[3] Read HBM output after drain-only inst:")
for t in range(active_tiles):
    addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    d = xdma.read(addr, n_tile_words * 16)
    nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
    match = (d == tile_data[t])
    print(f"    HBM slot[{t}] @ 0x{addr:x}: {nz}/{n_tile_words} non-zero, matches tile_obuf={match}")
    if not match and nz > 0:
        # Show first diff
        for i in range(n_tile_words):
            if d[i*16:(i+1)*16] != tile_data[t][i*16:(i+1)*16]:
                print(f"      first diff @ word {i}: hbm={d[i*16:(i+1)*16].hex()[:16]}.. obuf={tile_data[t][i*16:(i+1)*16].hex()[:16]}..")
                break

# ── Step 3: Verify HOST write path to same HBM region works ──────
print("\n[4] Verify HOST DMA write to same HBM addresses works (sanity):")
test_word = bytes(range(16))
for t in range(active_tiles):
    addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    xdma.write(addr, test_word)
    rb = xdma.read(addr, 16)
    ok = rb == test_word
    print(f"    Host write HBM[{t}] @ 0x{addr:x}: {'OK' if ok else 'FAIL!'}")

# ── Step 4: Do full hbm run to confirm result ─────────────────────
print("\n[5] Full hbm run:")
result = runner.run_case(rd, staging="hbm", timeout_s=120.0)[0]
hbm_s = "PASS" if result["pass"] else f"FAIL {result['passed']}/{result['total_words']}"
print(f"    {hbm_s}")

# Read HBM raw after full run
print("\n[6] Read HBM output after full hbm run (checking if any data was written):")
for t in range(active_tiles):
    addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    d = xdma.read(addr, n_tile_words * 16)
    nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
    print(f"    HBM slot[{t}] @ 0x{addr:x}: {nz}/{n_tile_words} non-zero words")

print("\nDone.")
