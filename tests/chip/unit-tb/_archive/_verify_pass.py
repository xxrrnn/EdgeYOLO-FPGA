"""Verbose verify: show exp vs got bytes for dcim_tiny hbm, prove PASS is genuine."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, HBM_BASE, HBM_OFF_OUTPUT
from xdma_win import DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE, TILE_OBUF_CHK_SENTINEL
from hbm_flow import hbm_drain_remap, build_hbm_output_drain, DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")
runner = ChipRunnerWin(verbose=False)

# Run once with hbm
runner.run_case(run_dir, staging="hbm")

# Recompute the same got_raw that read_check uses
exp_raw = hex_to_bin(run_dir / "expected.hex")[:128*16]
checks = runner._parse_checks_meta(run_dir)
chk = checks[0]
dst_off = chk["dst_off"]
wpt = chk["wpt"] or DCIM_INT8_OUT_WORDS_PER_TILE
n_words = chk["n_words"]

matmul_n = _matmul_n_from_manifest(run_dir)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
stride = DCIM_NUM_TILES * wpt
n_pixels = (n_words + stride - 1) // stride
n_tile_words = n_pixels * wpt
flat_bytes = active_tiles * n_tile_words * 16

flat_raw = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, flat_bytes)
got_raw = hbm_drain_remap(run_dir, flat_raw)

print(f"active_tiles={active_tiles}, n_tile_words={n_tile_words}, flat_bytes={flat_bytes}")
print(f"\n{'word':>5}  {'exp (hex)':36s}  {'got (hex)':36s}  match")
print("-" * 85)

mismatches = 0
SHOW = set(range(5)) | {4, 31, 32, 95, 96, 127}
for i in range(n_words):
    exp = exp_raw[i*16:(i+1)*16]
    got = got_raw[i*16:(i+1)*16]
    ok = exp == got
    if not ok:
        mismatches += 1
    if i in SHOW or not ok:
        tag = "OK  " if ok else "FAIL"
        print(f"{i:5d}  {exp.hex():36s}  {got.hex():36s}  {tag}")

print(f"\nTotal mismatches: {mismatches}/128")
if mismatches == 0:
    print("CONFIRMED PASS: exp == got for all 128 words")
