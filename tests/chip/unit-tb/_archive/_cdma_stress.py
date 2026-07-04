"""
诊断 CDMA stuck 根因。
逐步施压，找出触发 stuck 的精确条件。
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import (
    XDMAWin, ChipRunnerWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE, TILE_OBUF_BASE, TILE_OBUF_SIZE,
    inst_words_to_bin,
)
from hbm_flow import cdma_copy, _header, OP_NOP, OP_END

xdma = XDMAWin(verbose=False)

def cdma_health():
    """快速检查: HBM->HBM 1KB 是否正确"""
    pat = bytes(range(16)) * 64
    xdma.write(HBM_BASE + 0x300000, pat)
    xdma.write(HBM_BASE + HBM_OFF_OUTPUT, b'\x00' * 1024)
    insts = cdma_copy(HBM_BASE + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024)
    insts += [0xF0000000]
    ib = inst_words_to_bin(insts)
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 3:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2:
            break
        time.sleep(0.005)
    got = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 1024)
    return got == pat

def run_n_back_to_back(n, nbytes, label):
    """连续 n 次 HBM->HBM CDMA，各间隔 WAIT_CDMA"""
    insts = []
    for i in range(n):
        src = HBM_BASE + 0x300000 + i * nbytes
        dst = HBM_BASE + 0x400000 + i * nbytes
        xdma.write(src, bytes(range(16)) * (nbytes // 16))
        insts += cdma_copy(src, dst, nbytes)
    insts += [0xF0000000]
    ib = inst_words_to_bin(insts)
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 30:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2:
            break
        time.sleep(0.005)
    ok = cdma_health()
    status = "OK   " if ok else "STUCK"
    print(f"  [{status}] {label}")
    return ok

# 测试1: 连续 N 次 HBM->HBM (1KB)
print("=== Test1: Back-to-back HBM->HBM (1KB each) ===")
for n in [1, 4, 8, 16, 32, 64]:
    if not run_n_back_to_back(n, 1024, f"n={n} x 1KB"):
        print("  -> CDMA stuck after this test, need re-flash")
        sys.exit(1)

# 测试2: 大尺寸单次传输
print("\n=== Test2: Large single transfer ===")
for nbytes in [4096, 16384, 65536, 262144, 819200]:
    name = f"single {nbytes//1024}KB"
    if not run_n_back_to_back(1, nbytes, name):
        print("  -> CDMA stuck after this test")
        sys.exit(1)

# 测试3: tile_obuf -> HBM (模拟多 tile drain)
print("\n=== Test3: tile_obuf -> HBM (multi-tile drain simulation) ===")
# 写 tile_obuf via preload，然后 CDMA drain
for n_tiles in [1, 2, 4, 8]:
    n_tile_words = 256  # 256x16B = 4KB per tile
    insts = []
    for t in range(n_tiles):
        src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dst = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
        insts += cdma_copy(src, dst, n_tile_words * 16)
    insts += [0xF0000000]
    ib = inst_words_to_bin(insts)
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 30:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2:
            break
        time.sleep(0.005)
    ok = cdma_health()
    status = "OK   " if ok else "STUCK"
    print(f"  [{status}] {n_tiles} tiles x {n_tile_words} words ({n_tiles * n_tile_words * 16 // 1024}KB total)")
    if not ok:
        print("  -> CDMA stuck!")
        sys.exit(1)

print("\n=== All tests passed, CDMA stable ===")
