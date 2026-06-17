"""Direct raw comparison for im2col preload."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, VPU_BUF_BASE

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
runner = ChipRunnerWin(verbose=False)

# checks.txt: dst_off=0x000900, n_words=256
DST_OFF = 0x000900
N_WORDS = 256

exp = hex_to_bin(run_dir / "expected.hex")[:N_WORDS * 16]

# Run preload
runner.upload_preload(run_dir)
n_inst = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_inst)
runner.poll_done(120.0)
print("[DONE] im2col preload+exec completed")

# Read VPU_BUF directly
got = runner.x.read(VPU_BUF_BASE + DST_OFF, N_WORDS * 16)

mismatches = []
for i in range(N_WORDS):
    e = exp[i*16:(i+1)*16]
    g = got[i*16:(i+1)*16]
    if e != g:
        mismatches.append((i, e, g))

print(f"Direct compare: {N_WORDS - len(mismatches)}/{N_WORDS} match")

if mismatches:
    print(f"\nMismatches ({len(mismatches)} total):")
    for i, e, g in mismatches[:30]:
        e_zero = all(b == 0 for b in e)
        g_zero = all(b == 0 for b in g)
        tag = ""
        if g_zero and not e_zero:
            tag = " [got=0, exp!=0]"
        elif e_zero and not g_zero:
            tag = " [exp=0, got!=0]"
        print(f"  word {i:3d}: exp={e.hex()} got={g.hex()}{tag}")
    if len(mismatches) > 30:
        print(f"  ... ({len(mismatches) - 30} more)")
    
    # Count patterns
    zero_exp = sum(1 for _, e, g in mismatches if all(b == 0 for b in e))
    zero_got = sum(1 for _, e, g in mismatches if all(b == 0 for b in g))
    print(f"\nPattern:")
    print(f"  exp=0 but got!=0: {zero_exp}")
    print(f"  got=0 but exp!=0: {zero_got}")
    print(f"  both nonzero: {len(mismatches) - zero_exp - zero_got}")
    
    # Check if mismatch positions have any pattern with row_stride
    # im2col: 12x12x3, k=6, s=2, p=2 → OH=4, OW=4, acc_depth=2
    # row_stride = ceil(6*6*3 / 64)*64 = ceil(108/64)*64 = 128 bytes = 8 words
    # Total output = OH*OW * row_stride = 4*4*128 = 2048 bytes = 128 words? But check_words=256
    # Actually manifest says "rows=36 acc_depth=2" so OH*OW=36/acc_depth? Let me just check
    print(f"\nMismatch word indices: {[i for i,_,_ in mismatches]}")
