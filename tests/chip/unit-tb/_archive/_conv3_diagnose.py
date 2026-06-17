"""
conv3 3-Tile HBM drain diagnostic script.

Steps:
  1. Print patched inst drain CDMAs to verify addresses/sizes
  2. Run preload path, then read tile_obuf directly to confirm on-chip data OK
  3. Run hbm staging path, read HBM flat drain region tile-by-tile
  4. Compare tile_obuf (preload) vs HBM slot (hbm run) per tile
  5. Full remap result vs expected - per-word failure breakdown
"""
import sys
import struct
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from xdma_win import (
    ChipRunnerWin, XDMAWin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    hex_to_bin, inst_words_to_bin, parse_inst_words,
)
from hbm_flow import (
    patch_inst_for_hbm, build_hbm_output_drain, hbm_drain_remap,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
    cdma_copy, OP_CDMA_COPY, OP_WAIT_CDMA,
)

RUN_DIR = Path(__file__).resolve().parent / "runs" / "dcim_matmul_conv3_s2_c32_to64_qint8"
WPT = 4  # words per tile (from checks.txt)

x = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=x, verbose=False)

# ── 参数计算 ──────────────────────────────────────────────────────────────────
matmul_n = _matmul_n_from_manifest(RUN_DIR)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
stride = DCIM_NUM_TILES * WPT
n_words = 256
n_pixels = (n_words + stride - 1) // stride
n_tile_words = n_pixels * WPT

print(f"matmul_n={matmul_n}, active_tiles={active_tiles}, stride={stride}")
print(f"n_words={n_words}, n_pixels={n_pixels}, n_tile_words={n_tile_words}")
print(f"HBM drain region: {active_tiles} × {n_tile_words} words × 16B "
      f"= {active_tiles * n_tile_words * 16} B")

# ── Step 1: 打印 drain CDMA 指令 ──────────────────────────────────────────────
print("\n" + "="*60)
print("Step 1: Drain CDMA instructions (from build_hbm_output_drain)")
print("="*60)
drain_insts, _ = build_hbm_output_drain(RUN_DIR)
i = 0
while i < len(drain_insts):
    word = drain_insts[i]
    op = (word >> 28) & 0xF
    if op == OP_CDMA_COPY:
        length = word & 0xFFFFFF
        if i + 5 < len(drain_insts):
            sm, sl = drain_insts[i+1], drain_insts[i+2]
            dm, dl = drain_insts[i+3], drain_insts[i+4]
            nb = drain_insts[i+5]
            src = (sm << 32) | sl
            dst = (dm << 32) | dl
            print(f"  CDMA_COPY: src=0x{src:011x} -> dst=0x{dst:011x}  nbytes={nb} (0x{nb:x})")
        i += 7  # header + 5 args + WAIT_CDMA
    elif op == 0x3:
        print(f"  WAIT_CDMA")
        i += 1
    else:
        print(f"  OP=0x{op:x} word=0x{word:08x}")
        i += 1

# ── Step 2: 先用 preload 路径执行一次，确认 tile_obuf 里有正确数据 ────────────
print("\n" + "="*60)
print("Step 2: Run with preload staging -> verify tile_obuf content")
print("="*60)
runner.verbose = False
res_preload = runner.run_case(RUN_DIR, staging="preload", timeout_s=60.0)
pr = res_preload[0]
print(f"  preload result: {'PASS' if pr['pass'] else 'FAIL'} ({pr['passed']}/{pr['total_words']})")

# 读取各 tile_obuf（preload后片上数据已就绪，直读）
tile_data = []
for t in range(active_tiles):
    addr = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
    data = x.read(addr, n_tile_words * 16)
    tile_data.append(data)
    nonzero = sum(1 for j in range(0, len(data), 16) if any(data[j:j+16]))
    print(f"  tile_obuf[{t}]: addr=0x{addr:011x}, {n_tile_words} words, "
          f"{nonzero}/{n_tile_words} non-zero words")

# ── Step 3: 用 hbm staging 执行，然后逐 tile slot 读 HBM drain 区域 ──────────
print("\n" + "="*60)
print("Step 3: Run with hbm staging -> read HBM flat drain region tile by tile")
print("="*60)
runner.verbose = False

# 上传 HBM 数据 + patch后的 inst
runner.upload_hbm(RUN_DIR)
n_inst_words = runner.upload_inst(RUN_DIR, drain_output=True)
runner.start_decoder(n_inst_words)
runner.poll_done(timeout_s=60.0)
print("  decoder DONE")

# 逐 tile 读 HBM slot
# tile slot read
hbm_tile_data = []
for t in range(active_tiles):
    addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    data = x.read(addr, n_tile_words * 16)
    hbm_tile_data.append(data)
    nonzero = sum(1 for j in range(0, len(data), 16) if any(data[j:j+16]))
    status_str = "OK" if nonzero > 0 else "ALL ZERO -- drain CDMA FAILED"
    print(f"  HBM slot[{t}]: addr=0x{addr:011x}, {n_tile_words} words, "
          f"{nonzero}/{n_tile_words} non-zero words ({status_str})")

# ── Step 4: 比对 tile_obuf 直读 vs HBM drain 的每 tile 内容 ─────────────────
print("\n" + "="*60)
print("Step 4: Compare tile_obuf (preload read) vs HBM drain (hbm run) per tile")
print("="*60)
for t in range(active_tiles):
    tb = tile_data[t]
    hb = hbm_tile_data[t]
    mismatches = 0
    first_mm = None
    for w in range(n_tile_words):
        te = tb[w*16:(w+1)*16]
        he = hb[w*16:(w+1)*16]
        if te != he:
            mismatches += 1
            if first_mm is None:
                first_mm = (w, te.hex(), he.hex())
    status = "MATCH" if mismatches == 0 else f"MISMATCH ({mismatches}/{n_tile_words})"
    print(f"  tile {t}: {status}", end="")
    if first_mm:
        print(f"  first @ word {first_mm[0]}: obuf={first_mm[1][:16]}.. hbm={first_mm[2][:16]}..")
    else:
        print()

# ── Step 5: 逐 word 分析最终 remap 后的结果 ──────────────────────────────────
print("\n" + "="*60)
print("Step 5: Full hbm_drain_remap result vs expected - per-word summary")
print("="*60)
flat_bytes = b"".join(hbm_tile_data)
got_remapped = hbm_drain_remap(RUN_DIR, flat_bytes)
exp_bytes = hex_to_bin(RUN_DIR / "expected.hex")[:n_words * 16]

pass_words = []
fail_words = []
for w in range(n_words):
    eg = exp_bytes[w*16:(w+1)*16]
    gg = got_remapped[w*16:(w+1)*16]
    tile_for_word = (w % stride) // WPT
    px = w // stride
    intra = w % WPT
    if eg == gg:
        pass_words.append(w)
    else:
        fail_words.append((w, tile_for_word, px, intra, eg.hex(), gg.hex()))

print(f"  PASS: {len(pass_words)}/{n_words}  FAIL: {len(fail_words)}/{n_words}")

# Print first 20 failures
for w, t, px, intra, exp, got in fail_words[:20]:
    print(f"  FAIL word {w:3d} (tile={t} px={px} intra={intra}): "
          f"exp={exp[:16]}.. got={got[:16]}..")

if fail_words:
    tiles_with_fail = sorted(set(t for _, t, _, _, _, _ in fail_words))
    print(f"\n  Tiles with failures: {tiles_with_fail}")
    for t in range(active_tiles):
        n_fail_t = sum(1 for _, tt, _, _, _, _ in fail_words if tt == t)
        print(f"    tile {t}: {n_fail_t} failed words / {n_tile_words * n_pixels} expected")
