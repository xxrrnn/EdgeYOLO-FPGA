"""
Analyze per-tile drain: after preload (tile_obuf populated),
issue drain CDMAs one-by-one and check which tiles make it to HBM.
"""
import sys, struct, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT, TILE_OBUF_BASE, TILE_OBUF_SIZE,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    inst_words_to_bin,
)
from hbm_flow import (
    cdma_copy, build_hbm_output_drain,
    _matmul_n_from_manifest, DCIM_INT8_OUT_CH_PER_TILE,
    OP_WAIT_CDMA, OP_END,
)
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

WPT = DCIM_INT8_OUT_WORDS_PER_TILE  # 4

def run_case_and_analyze(mod, var):
    rd = generate_case(mod, var)
    matmul_n = _matmul_n_from_manifest(rd)
    active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE

    # Determine n_tile_words from checks.txt
    chk_line = next(
        l for l in (rd / "checks.txt").read_text().splitlines()
        if l.strip() and not l.startswith("#")
    )
    parts = chk_line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])
    wpt_check = int(parts[5]) if len(parts) > 5 else WPT
    stride = DCIM_NUM_TILES * wpt_check
    n_px = (n_words + stride - 1) // stride
    n_tile_words = n_px * wpt_check

    print(f"\n{'='*65}")
    print(f"{mod}/{var}  N={matmul_n} active_tiles={active_tiles} n_tile_words={n_tile_words}")

    # Step 1: preload to populate tile_obuf
    runner.upload_preload(rd)
    n_inst = runner.upload_inst_raw(rd)
    runner.start_decoder(n_inst)
    runner.poll_done(timeout_s=60.0)

    # Read tile_obuf contents
    tile_data = []
    for t in range(active_tiles):
        d = xdma.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, n_tile_words * 16)
        nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
        tile_data.append(d)
        print(f"  tile_obuf[{t}]: {nz}/{n_tile_words} non-zero")

    # Step 2: Zero all HBM output slots
    total_hbm_bytes = active_tiles * n_tile_words * 16
    xdma.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * total_hbm_bytes)

    # Step 3: Issue drain CDMAs ALL AT ONCE (as hbm_flow does)
    drain_insts, _ = build_hbm_output_drain(rd)
    full_insts = drain_insts + [OP_END]
    ib = inst_words_to_bin(full_insts)
    nw = len(ib) // 4
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, nw)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 10.0:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st & 0x2:
            break
        time.sleep(0.002)

    # Check per-tile
    print(f"  All drains issued, decoder done={bool(st&2)}")
    for t in range(active_tiles):
        addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
        d = xdma.read(addr, n_tile_words * 16)
        nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
        match = d == tile_data[t]
        print(f"  HBM drain[{t}]: {nz}/{n_tile_words} non-zero, correct={match}")
        if not match and nz > 0:
            for i in range(n_tile_words):
                ew = tile_data[t][i*16:(i+1)*16]
                gw = d[i*16:(i+1)*16]
                if ew != gw:
                    print(f"    first diff @ word {i:3d}: exp={ew.hex()[:16]}.. got={gw.hex()[:16]}..")
                    break

    # Step 4: full hbm run
    r = runner.run_case(rd, staging="hbm", timeout_s=120.0)[0]
    hbm_s = "PASS" if r["pass"] else f"FAIL {r['passed']}/{r['total_words']}"
    print(f"  full hbm run: {hbm_s}")

run_case_and_analyze("dcim_matmul", "dcim_tiny_1x1")        # N=16, 1 tile
run_case_and_analyze("dcim_matmul", "conv6_s2_c3_to16")     # N=16, 1 tile?
run_case_and_analyze("dcim_matmul", "conv3_s2_c32_to64")    # N=64, 4 tiles
run_case_and_analyze("dcim_matmul", "conv3_c128_to128")     # N=128, 8 tiles

print("\nDone.")
