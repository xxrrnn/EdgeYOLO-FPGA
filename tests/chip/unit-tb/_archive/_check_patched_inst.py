"""Check patched inst for mini_2conv hbm - verify drain CDMA is present."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from hbm_flow import patch_inst_for_hbm
from xdma_win import parse_inst_words, inst_words_to_bin

OP_NAMES = {0x0:'NOP',0x1:'CDMA',0x2:'VPU',0x3:'WAIT_CDMA',0x4:'WAIT_VPU',
            0x5:'SYNC',0x6:'DCIM_EXEC',0x7:'WAIT_DCIM',0x8:'DCIM_CFG',0x9:'DCIM_LAYER',0xF:'END'}

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')

patched_bytes = patch_inst_for_hbm(run_dir, drain_output=True)
patched_words = list(int.from_bytes(patched_bytes[i:i+4], 'little') for i in range(0, len(patched_bytes), 4))

print(f"Patched inst: {len(patched_words)} words ({len(patched_bytes)} bytes)")

# Find last 20 instructions (end of patched sequence)
print("\nLast 20 instructions in patched sequence:")
words = patched_words
i = 0
all_insts = []
while i < len(words):
    w = words[i]
    op = (w >> 28) & 0xF
    blen = w & 0xFFFFFF
    bwords = blen // 4
    body = words[i+1:i+1+bwords]
    all_insts.append((i, w, op, bwords, body))
    i += 1 + bwords
    if op == 0xF:
        break

for idx, w, op, bwords, body in all_insts[-20:]:
    opname = OP_NAMES.get(op, f'0x{op:X}')
    if op == 0x0 and bwords == 0:
        # count consecutive NOPs
        continue
    if op == 0x1:
        if len(body) >= 5:
            src = (body[0] << 32) | body[1]
            dst = (body[2] << 32) | body[3]
            nb = body[4]
            print(f"  [{idx:4d}] CDMA_COPY src=0x{src:010x} dst=0x{dst:010x} len={nb}B")
        else:
            print(f"  [{idx:4d}] CDMA body={[hex(x) for x in body]}")
    elif op == 0xF:
        print(f"  [{idx:4d}] END")
    else:
        print(f"  [{idx:4d}] {opname} bwords={bwords}")

# Count NOPs near end
nop_count = 0
for idx, w, op, bwords, body in reversed(all_insts):
    if op == 0x0 and bwords == 0:
        nop_count += 1
    else:
        break
print(f"\nTrailing NOPs before END: {nop_count}")
