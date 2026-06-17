"""Careful im2col preload test with detailed output analysis."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin
import struct

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
runner = ChipRunnerWin(verbose=False)

# Run preload mode (direct write to VPU_BUF, no CDMA involved)
print("Running im2col preload...")
results = runner.run_case(run_dir, staging="preload")
r = results[0]
print(f"Result: {'PASS' if r['pass'] else 'FAIL'} ({r['passed']}/{r['total_words']})")

if not r["pass"]:
    exp = hex_to_bin(run_dir / "expected.hex")
    # Print all mismatches
    mismatches = r.get("all_mismatches", [])
    print(f"\nTotal mismatches: {len(mismatches)}")
    
    # Group mismatches by pattern
    all_zero_got = 0
    nonzero_exp_got = 0
    for m in mismatches[:20]:
        w = m["word"]
        e = bytes.fromhex(m["expected"])
        g = bytes.fromhex(m["got"])
        exp_zero = all(b == 0 for b in e)
        got_zero = all(b == 0 for b in g)
        if got_zero and not exp_zero:
            all_zero_got += 1
        elif not got_zero and not exp_zero:
            nonzero_exp_got += 1
        tag = ""
        if got_zero and not exp_zero:
            tag = " [got=ZEROS, exp!=0]"
        elif exp_zero and not got_zero:
            tag = " [exp=ZEROS, got!=0]"
        print(f"  word {w:3d}: exp={m['expected'][:16]}... got={m['got'][:16]}...{tag}")
    
    if len(mismatches) > 20:
        print(f"  ... ({len(mismatches)-20} more)")
    
    # Summary patterns
    zero_exp = sum(1 for m in mismatches if all(b == 0 for b in bytes.fromhex(m["expected"])))
    zero_got = sum(1 for m in mismatches if all(b == 0 for b in bytes.fromhex(m["got"])))
    print(f"\nPattern analysis:")
    print(f"  exp=0 but got!=0: {zero_exp} words (im2col wrote where it shouldn't)")
    print(f"  got=0 but exp!=0: {zero_got} words (im2col didn't write where it should)")
    print(f"  both nonzero but different: {len(mismatches) - zero_exp - zero_got} words (wrong data)")
