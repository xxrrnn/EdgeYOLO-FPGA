"""打印 add 的完整 hbm patch 指令序列"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')
from pathlib import Path
from hbm_flow import patch_inst_for_hbm, parse_inst_words, OP_END

run_dir = Path("tests/chip/unit-tb/runs/add_add_residual_16_qint8")
patched = patch_inst_for_hbm(run_dir)
words = [int.from_bytes(patched[i:i+4], 'little') for i in range(0, len(patched), 4)]

OP_NAMES = {
    0x0: 'NOP', 0x1: 'CFG_VPU', 0x2: 'WAIT_VPU', 0x3: 'WAIT_CDMA',
    0x4: 'DCIM_CFG', 0x5: 'WAIT_DCIM', 0x8: 'CDMA_COPY', 0xF: 'END',
}

i = 0
while i < len(words):
    op = (words[i] >> 28) & 0xF
    name = OP_NAMES.get(op, f'OP_{op:x}')
    if op == 0x1:  # CDMA_COPY = 0x10000014 -> opcode field
        # actually opcode is top nibble
        pass
    n_extra = (words[i] >> 20) & 0xFF if op not in (0x0, 0xF, 0x2, 0x3, 0x5) else 0
    if op == 0x1:
        n_extra = (words[i] >> 0) & 0xFF
    line = f"[{i:3d}] 0x{words[i]:08x}  {name}"
    if n_extra and i+1 < len(words):
        line += f"  payload={[hex(words[i+j+1]) for j in range(min(n_extra,6))]}"
    print(line)
    i += 1 + n_extra
    if i > 100:
        print("... (truncated)")
        break
