"""
Analyze VPU_BUF->HBM drain for dqa/qa cases, and analyze im2col hbm path.
Also check if CDMA cooldown between consecutive runs causes partial tile failures.
"""
import sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    inst_words_to_bin,
)
from hbm_flow import (
    build_hbm_output_drain, cdma_copy,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
    OP_END, OP_WAIT_CDMA,
)
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

def analyze(mod, var, label=""):
    rd = generate_case(mod, var)
    drain_insts, hbm_off = build_hbm_output_drain(rd)
    chk_line = next(
        l for l in (rd / "checks.txt").read_text().splitlines()
        if l.strip() and not l.startswith("#")
    )
    parts = chk_line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])
    is_vpu = dst_off < 0x800000

    # Decode first drain CDMA
    if len(drain_insts) >= 6:
        sm, sl = drain_insts[1], drain_insts[2]
        dm, dl = drain_insts[3], drain_insts[4]
        nb = drain_insts[5]
        src = (sm << 32) | sl
        dst = (dm << 32) | dl
    else:
        src = dst = nb = 0

    r_pre = runner.run_case(rd, staging="preload", timeout_s=60.0)[0]
    r_hbm = runner.run_case(rd, staging="hbm", timeout_s=60.0)[0]
    pre_s = "PASS" if r_pre["pass"] else f"FAIL {r_pre['passed']}/{r_pre['total_words']}"
    hbm_s = "PASS" if r_hbm["pass"] else f"FAIL {r_hbm['passed']}/{r_hbm['total_words']}"

    # Read HBM after hbm run
    hbm_data = xdma.read(HBM_BASE + hbm_off, n_words * 16)
    nz = sum(1 for i in range(0, len(hbm_data), 16) if any(hbm_data[i:i+16]))

    tag = label or f"{mod}/{var}"
    print(f"\n{tag}")
    print(f"  dst_off=0x{dst_off:x}  is_vpu_buf={is_vpu}  n_words={n_words}")
    print(f"  drain CDMA[0]: src=0x{src:011x}  dst=0x{dst:011x}  nb={nb}")
    print(f"  preload={pre_s}  hbm={hbm_s}")
    print(f"  HBM @ 0x{HBM_BASE+hbm_off:011x}: {nz}/{n_words} non-zero after hbm run")
    return r_hbm["pass"]

print("=" * 65)
print("Section 1: VPU_BUF drain path (dqa/qa)")
print("=" * 65)
analyze("dqa", "dqa_c32_mid")
analyze("qa",  "qa_c64_clip")

print()
print("=" * 65)
print("Section 2: im2col hbm path")
print("=" * 65)
analyze("im2col", "im2col_6x6_s2_c3")
analyze("im2col", "im2col_1x1_c512")

print()
print("=" * 65)
print("Section 3: dcim multi-tile consecutive (cooldown?)")
print("=" * 65)
# Run the same 4-tile case 3 times in a row
from gen_data import generate_case as gc
rd4 = gc("dcim_matmul", "conv3_s2_c32_to64")
for i in range(3):
    r = runner.run_case(rd4, staging="hbm", timeout_s=60.0)[0]
    s = "PASS" if r["pass"] else f"FAIL {r['passed']}/{r['total_words']}"
    print(f"  conv3_s2_c32_to64 run#{i+1}: {s}")

print("\nDone.")
