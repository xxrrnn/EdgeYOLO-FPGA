"""Post-reset: confirm FPGA healthy, then run im2col ONCE and analyze failures."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, VPU_BUF_BASE

runner = ChipRunnerWin(verbose=False)
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")

# Step 1: sanity check with known-good test
print("=== Sanity check: dcim_tiny preload ===")
r = runner.run_case(base / "dcim_matmul_dcim_tiny_1x1_qint8", staging="preload")[0]
print(f"  dcim_tiny preload: {'PASS' if r['pass'] else 'FAIL'}")
if not r["pass"]:
    print("  FPGA not healthy! Abort.")
    exit(1)

# Step 2: run im2col preload ONCE
print("\n=== im2col preload (single run) ===")
im_dir = base / "im2col_im2col_6x6_s2_c3_qint8"
r = runner.run_case(im_dir, staging="preload")[0]
n_pass = r["passed"]
n_total = r["total_words"]
print(f"  Result: {'PASS' if r['pass'] else f'FAIL ({n_pass}/{n_total})'}")

if not r["pass"]:
    mismatches = r.get("mismatches", [])
    print(f"  Mismatches: {len(mismatches)}")
    
    exp = hex_to_bin(im_dir / "expected.hex")[:n_total * 16]
    
    # Analyze failure pattern
    # im2col layout: OH=6, OW=6, row_stride=128 bytes=8 words
    # output pixel (oh,ow) starts at word (oh*6+ow)*8
    ROW_STRIDE_WORDS = 8
    OH, OW = 6, 6
    
    for m in mismatches:
        w = m["word"]
        pixel = w // ROW_STRIDE_WORDS
        oh = pixel // OW
        ow = pixel % OW
        word_in_row = w % ROW_STRIDE_WORDS
        e = bytes.fromhex(m["expected"])
        g = bytes.fromhex(m["got"])
        e_z = all(b == 0 for b in e)
        g_z = all(b == 0 for b in g)
        tag = ""
        if e_z and not g_z:
            tag = " [exp=0, got!=0: spurious write]"
        elif g_z and not e_z:
            tag = " [got=0, exp!=0: missing write]"
        else:
            # Find byte-level diffs
            diffs = [(b, e[b], g[b]) for b in range(16) if e[b] != g[b]]
            tag = f" [{len(diffs)} bytes differ]"
        print(f"  word {w:3d} (oh={oh},ow={ow},row_word={word_in_row}): {tag}")
        if len(mismatches) > 30 and mismatches.index(m) == 29:
            print(f"  ... ({len(mismatches)-30} more)")
            break

# Step 3: verify FPGA still alive after im2col
print("\n=== Post-im2col sanity check ===")
r2 = runner.run_case(base / "dcim_matmul_dcim_tiny_1x1_qint8", staging="preload")[0]
print(f"  dcim_tiny preload: {'PASS' if r2['pass'] else 'FAIL'}")
if not r2["pass"]:
    print("  !! FPGA may be wedged after im2col !!")
