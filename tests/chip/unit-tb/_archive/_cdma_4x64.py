"""Test: 4 x 64B CDMAs (non-contiguous dst) after preload+exec, like the hbm drain."""
from pathlib import Path
import struct
from xdma_win import (
    ChipRunnerWin, XDMAWin, HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
    hex_to_bin, inst_words_to_bin,
)
from hbm_flow import cdma_copy, _header, OP_WAIT_CDMA, OP_WAIT_DCIM, OP_END

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")

runner = ChipRunnerWin(verbose=False)

PASS_count = 0
FAIL_count = 0

for trial in range(5):
    # Step 1: preload + run core only (no drain)
    runner.upload_preload(run_dir)
    n_words = runner.upload_inst_raw(run_dir)
    runner.clear_tile_obufs(128, wpt=4)
    runner.start_decoder(n_words)
    runner.poll_done(60.0)

    # Step 2: zero HBM output area
    runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * 2048)

    # Step 3: build 4 x 64B CDMAs matching the actual drain pattern
    # stride=32, wpt=4, active_tiles=1 => drain copies:
    #  tile_obuf[0][0..3] -> HBM[0..3]   (0x100000, n=64)
    #  tile_obuf[0][4..7] -> HBM[32..35]  (0x100200, n=64)
    #  tile_obuf[0][8..11]-> HBM[64..67]  (0x100400, n=64)
    #  tile_obuf[0][12..15]->HBM[96..99]  (0x100600, n=64)
    HBM_OUT = HBM_BASE + HBM_OFF_OUTPUT
    OBUF0 = TILE_OBUF_BASE
    insts = []
    insts += cdma_copy(OBUF0 + 0*16, HBM_OUT + 0*16,  64)  # words 0-3
    insts += cdma_copy(OBUF0 + 4*16, HBM_OUT + 32*16, 64)  # words 4-7 -> HBM[32-35]
    insts += cdma_copy(OBUF0 + 8*16, HBM_OUT + 64*16, 64)  # words 8-11 -> HBM[64-67]
    insts += cdma_copy(OBUF0 +12*16, HBM_OUT + 96*16, 64)  # words 12-15 -> HBM[96-99]
    insts.append(_header(OP_END, 0, 0))
    data = inst_words_to_bin(insts)
    runner.x.write(INST_BASE, data)
    runner.start_decoder(len(data) // 4)
    runner.poll_done(30.0)

    # Step 4: read tile_obuf[0] directly
    obuf0 = runner.x.read(TILE_OBUF_BASE, 16 * 16)

    # Step 5: read HBM and compare
    hbm = runner.x.read(HBM_OUT, 2048)

    # Check the 4 active blocks
    fails = []
    for wi, tw in [(0,0),(1,1),(2,2),(3,3),(32,4),(33,5),(34,6),(35,7),(64,8),(65,9),(66,10),(67,11),(96,12),(97,13),(98,14),(99,15)]:
        exp = obuf0[tw*16:(tw+1)*16]
        got = hbm[wi*16:(wi+1)*16]
        if exp != got:
            diffs = [(b, exp[b], got[b]) for b in range(16) if exp[b] != got[b]]
            diff_str = " ".join(f"[{b}]:{e:02x}->{g:02x}" for b,e,g in diffs)
            fails.append(f"  word {wi:3d} (obuf[{tw}]): {diff_str}")

    # Also check inactive words are still 0
    for wi in [4,5,6,7,8,9,10,11,68,69,70,100,101]:
        got = hbm[wi*16:(wi+1)*16]
        if any(b != 0 for b in got):
            fails.append(f"  word {wi:3d} (inactive, should=0): {got.hex()}")

    if fails:
        FAIL_count += 1
        print(f"Trial {trial+1}: FAIL")
        for f in fails: print(f)
    else:
        PASS_count += 1
        print(f"Trial {trial+1}: PASS")

print(f"\nTotal: {PASS_count}/5 PASS")
