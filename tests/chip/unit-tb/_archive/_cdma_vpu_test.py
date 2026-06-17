"""对比 dqa (VPU_BUF+0x400) 和 add (VPU_BUF+0x800) 的手动 drain CDMA"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import (
    XDMAWin, ChipRunnerWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE, inst_words_to_bin,
)
from hbm_flow import cdma_copy, _header, OP_NOP

xdma = XDMAWin(verbose=False)

def run_drain_test(label, src_addr, dst_addr, nbytes):
    """手动 drain CDMA，返回是否匹配"""
    # Write pattern to src
    pattern = bytes(range(16)) * (nbytes // 16)
    xdma.write(src_addr, pattern)
    # Zero dst
    xdma.write(dst_addr, b'\x00' * nbytes)
    
    insts = cdma_copy(src_addr, dst_addr, nbytes)
    insts += [0xF0000000]
    ib = inst_words_to_bin(insts)
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    
    t0 = time.time()
    while time.time() - t0 < 5:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st & 2:
            break
        time.sleep(0.01)
    
    got = xdma.read(dst_addr, nbytes)
    ok = got == pattern
    print(f"  {label}: src=0x{src_addr:011x} dst=0x{dst_addr:011x} nbytes={nbytes} -> {'MATCH' if ok else 'FAIL'} (first4={got[:4].hex()})")
    return ok

print("=== Manual CDMA drain tests ===")
# Test VPU_BUF+0x0 -> HBM
run_drain_test("VPU_BUF+0x0   -> HBM+OUTPUT", VPU_BUF_BASE + 0x0,   HBM_BASE + HBM_OFF_OUTPUT, 1024)
run_drain_test("VPU_BUF+0x400 -> HBM+OUTPUT", VPU_BUF_BASE + 0x400, HBM_BASE + HBM_OFF_OUTPUT, 1024)
run_drain_test("VPU_BUF+0x800 -> HBM+OUTPUT", VPU_BUF_BASE + 0x800, HBM_BASE + HBM_OFF_OUTPUT, 1024)
run_drain_test("HBM+0x300000  -> HBM+OUTPUT", HBM_BASE   + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024)
