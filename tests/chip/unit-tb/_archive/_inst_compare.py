"""
Compare patched inst tail (core end + barrier + drain CDMAs) between
a PASS case and FAIL cases, to determine if the issue is in test code
or RTL.
"""
import sys, struct
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import XDMAWin, ChipRunnerWin, DCIM_INT8_OUT_WORDS_PER_TILE, DCIM_NUM_TILES
from gen_data import generate_case
from hbm_flow import (
    patch_inst_for_hbm, build_hbm_output_drain, build_hbm_input_cdma,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
    OP_CDMA_COPY, OP_WAIT_CDMA, OP_WAIT_DCIM, OP_WAIT_VPU, OP_END, OP_NOP,
    parse_inst_words,
)

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

OP_NAMES = {
    0x0: "NOP", 0x1: "CDMA_COPY", 0x3: "WAIT_CDMA", 0x4: "WAIT_VPU",
    0x7: "WAIT_DCIM", 0xF: "END",
}

def decode_inst(words):
    """Decode instruction words into readable list."""
    out = []
    i = 0
    while i < len(words):
        w = words[i]
        op = (w >> 28) & 0xF
        name = OP_NAMES.get(op, f"OP{op:x}")
        if op == OP_CDMA_COPY and i + 5 < len(words):
            sm, sl = words[i+1], words[i+2]
            dm, dl = words[i+3], words[i+4]
            nb = words[i+5]
            src = (sm << 32) | sl
            dst = (dm << 32) | dl
            out.append(f"[{i:3d}] CDMA_COPY  src=0x{src:011x} dst=0x{dst:011x} nb={nb}")
            i += 6
        elif op == 0x3:  # WAIT_CDMA
            out.append(f"[{i:3d}] WAIT_CDMA")
            i += 1
        else:
            out.append(f"[{i:3d}] {name:12s}  0x{w:08x}")
            i += 1
    return out

def analyze_case(module, variant, quant="int8"):
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

    # Build patched inst
    core_words = parse_inst_words(rd / "inst.hex")
    while core_words and (core_words[-1] >> 28) & 0xF == 0xF:  # strip END
        core_words.pop()

    input_cdma = build_hbm_input_cdma(rd)
    drain_cdma, _ = build_hbm_output_drain(rd)
    barrier = [0x70000000]  # WAIT_DCIM

    patched = input_cdma + core_words + barrier + drain_cdma + [0xF0000000]

    print(f"\n{'='*65}")
    print(f"{module}/{variant}  N={matmul_n} active_tiles={active_tiles}")
    print(f"  core={len(core_words)}w  input_cdma={len(input_cdma)}w  drain={len(drain_cdma)}w")
    print(f"  n_tile_words={n_tile_words}")

    # Show core tail (last 8 instructions before barrier)
    core_decoded = decode_inst(core_words)
    print(f"\n  Core tail (last 8 of {len(core_decoded)} decoded lines):")
    for line in core_decoded[-8:]:
        print(f"    {line}")

    # Show barrier + drain
    barrier_drain = barrier + drain_cdma + [0xF0000000]
    bd_decoded = decode_inst(barrier_drain)
    print(f"\n  Barrier + drain ({len(bd_decoded)} lines):")
    for line in bd_decoded:
        print(f"    {line}")

    # Count WAIT_DCIM in core
    n_wait_dcim_core = sum(1 for w in core_words if (w >> 28) & 0xF == 0x7)
    print(f"\n  WAIT_DCIM count in core: {n_wait_dcim_core}")
    print(f"  Total patched inst words: {len(patched)}")

    # Actually run and check
    hbm_result = runner.run_case(rd, staging="hbm", timeout_s=120.0)
    pre_result = runner.run_case(rd, staging="preload", timeout_s=120.0)
    h = hbm_result[0]
    p = pre_result[0]
    pre_s = "PASS" if p["pass"] else f"FAIL {p['passed']}/{p['total_words']}"
    hbm_s = "PASS" if h["pass"] else f"FAIL {h['passed']}/{h['total_words']}"
    print(f"\n  preload: {pre_s}")
    print(f"  hbm:     {hbm_s}")
    return h["pass"]


print("Comparing PASS vs FAIL cases: inst tail analysis")

# PASS reference
analyze_case("dcim_matmul", "conv3_s2_c32_to64")  # N=64 acc=5 PASS

# FAIL cases
analyze_case("dcim_matmul", "conv1_c64_to32")      # N=32 acc=1 FAIL
analyze_case("dcim_matmul", "conv3_c128_to128")    # N=64 acc=9 FAIL

print("\nDone.")
