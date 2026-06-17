"""Dump the patched instruction stream for dcim_tiny to check drain CDMA."""
from pathlib import Path
from hbm_flow import build_hbm_output_drain, patch_inst_for_hbm
from xdma_win import HBM_BASE, HBM_OFF_OUTPUT, TILE_OBUF_BASE, TILE_OBUF_SIZE

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")

drain_insts, hbm_out_off = build_hbm_output_drain(run_dir)

OP_CDMA_COPY = 0x1
OP_WAIT_CDMA = 0x3
OP_END = 0xF

print("=== DRAIN CDMA instructions ===")
print(f"Total words: {len(drain_insts)}")
print()

HBM_OUT = HBM_BASE + HBM_OFF_OUTPUT
TARGET = HBM_OUT + 66 * 16  # 0x100000 + 0x420 = 0x100420

i = 0
cdma_count = 0
while i < len(drain_insts):
    op = (drain_insts[i] >> 28) & 0xF
    length = drain_insts[i] & 0xFFFFFF
    if op == OP_CDMA_COPY:
        src_hi = drain_insts[i+1]
        src_lo = drain_insts[i+2]
        dst_hi = drain_insts[i+3]
        dst_lo = drain_insts[i+4]
        nbytes = drain_insts[i+5]
        src = (src_hi << 32) | src_lo
        dst = (dst_hi << 32) | dst_lo
        hbm_i = (dst - HBM_OUT) // 16  # which word index in HBM
        tile = (src - TILE_OBUF_BASE) // TILE_OBUF_SIZE
        tile_word = (src - (TILE_OBUF_BASE + tile * TILE_OBUF_SIZE)) // 16
        flag = " <== WORD 66" if dst == TARGET else ""
        print(f"  CDMA[{cdma_count:3d}] tile_obuf[{tile}][word {tile_word:3d}] -> HBM[{hbm_i:3d}] ({nbytes}B){flag}")
        cdma_count += 1
        i += 6
    else:
        i += 1

print(f"\nTotal CDMA copy instructions: {cdma_count}")

# Check for duplicate HBM destinations
from collections import Counter
hbm_dsts = {}
i = 0
cdma_n = 0
while i < len(drain_insts):
    op = (drain_insts[i] >> 28) & 0xF
    if op == OP_CDMA_COPY:
        dst_hi = drain_insts[i+3]
        dst_lo = drain_insts[i+4]
        dst = (dst_hi << 32) | dst_lo
        if dst in hbm_dsts:
            hbm_dsts[dst].append(cdma_n)
        else:
            hbm_dsts[dst] = [cdma_n]
        cdma_n += 1
        i += 6
    else:
        i += 1

dups = {k: v for k, v in hbm_dsts.items() if len(v) > 1}
if dups:
    print("\n=== DUPLICATE HBM destinations ===")
    for addr, idxs in dups.items():
        wi = (addr - HBM_OUT) // 16
        print(f"  HBM[{wi}] = 0x{addr:x}: written by CDMA {idxs}")
else:
    print("\nNo duplicate HBM destinations found.")
