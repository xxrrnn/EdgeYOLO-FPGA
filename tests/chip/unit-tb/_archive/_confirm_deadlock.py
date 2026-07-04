"""
精确确认 CDMA 死锁根因：
1. 触发一个 DMA 访问无效地址（会产生 AXI 错误响应）
2. 检查后续 CDMA 是否还能工作
3. 确认 SR 错误位导致 FSM 死锁的具体行为
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import (
    XDMAWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE, TILE_OBUF_BASE, TILE_OBUF_SIZE,
    inst_words_to_bin,
)
from hbm_flow import cdma_copy, _header, OP_NOP, OP_END

xdma = XDMAWin(verbose=False)

def run_insts(insts, timeout=5.0):
    ib = inst_words_to_bin(insts + [0xF0000000])
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < timeout:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2:
            return True
        time.sleep(0.005)
    return False  # timeout = stuck

def cdma_health():
    ok = run_insts(cdma_copy(HBM_BASE + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024))
    got = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 4)
    return ok and got != b'\x00\x00\x00\x00'

# 预先写入 pattern
xdma.write(HBM_BASE + 0x300000, bytes(range(16)) * 64)

print("=== 确认 CDMA 死锁触发条件 ===\n")

# --- 实验1: 正常 valid CDMA (baseline) ---
done = run_insts(cdma_copy(HBM_BASE + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024))
print(f"[实验1] 正常 HBM->HBM 1KB: done={done}, health={cdma_health()}")

# --- 实验2: tile_obuf -> HBM，tile_obuf 有数据 ---
xdma.write(TILE_OBUF_BASE, bytes(range(16)) * 256)  # 写 4KB 到 tile0
done = run_insts(cdma_copy(TILE_OBUF_BASE, HBM_BASE + HBM_OFF_OUTPUT, 4096))
got = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 16)
print(f"[实验2] tile_obuf[0]->HBM 4KB: done={done}, got={got[:4].hex()}, health={cdma_health()}")

# --- 实验3: 8 tiles 串行 drain，每次 4KB（模拟真实 dcim drain）---
print("\n[实验3] 8-tile 串行 drain（每 tile 4KB）:")
for t in range(8):
    xdma.write(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, bytes([t]*16) * 256)
insts = []
for t in range(8):
    src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
    dst = HBM_BASE + HBM_OFF_OUTPUT + t * 4096
    insts += cdma_copy(src, dst, 4096)
done = run_insts(insts, timeout=10.0)
health = cdma_health()
print(f"  done={done}, health={health}")
if not health:
    print("  !! CDMA STUCK 在 8-tile drain 后")

# --- 实验4: 大 tile_obuf drain（模拟 dcim_model_3_conv，M=1600）---
if health:
    print("\n[实验4] 大 tile_obuf drain（8 tiles × 51200/8=6400 words = 100KB/tile）:")
    N_WORDS = 6400  # 51200 / 8 tiles
    insts = []
    for t in range(8):
        src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dst = HBM_BASE + 0x200000 + t * N_WORDS * 16
        nbytes = N_WORDS * 16  # 102400 bytes = 100KB
        insts += cdma_copy(src, dst, nbytes)
    done = run_insts(insts, timeout=30.0)
    health2 = cdma_health()
    print(f"  done={done}, health={health2}")
    if not health2:
        print("  !! CDMA STUCK — 确认：大尺寸多 tile drain 触发死锁")
    else:
        print("  CDMA 仍然正常")
