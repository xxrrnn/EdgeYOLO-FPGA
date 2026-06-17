"""Check the last few instructions of mini_2conv original inst.hex."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

OP_NAMES = {0x0:'NOP',0x1:'CDMA',0x2:'VPU',0x3:'WAIT_CDMA',0x4:'WAIT_VPU',
            0x9:'DCIM_LAYER',0xF:'END'}

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')
words = parse_inst_words(run_dir / 'inst.hex')
print(f"Original inst.hex: {len(words)} words")

# Show last 30 instructions
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

print(f"\nTotal distinct instructions: {len(all_insts)}")
print("\nLast 15 instructions:")
for idx, w, op, bwords, body in all_insts[-15:]:
    opname = OP_NAMES.get(op, f'0x{op:x}')
    if op == 0x0 and bwords == 0:
        opname = 'NOP'
    elif op == 0x2 and body:
        units = {7:'IM2COL',0:'RELU',1:'DQA',2:'QA',3:'AD',4:'MP',5:'US',6:'CONCAT'}
        opname = f'VPU({units.get(body[0], body[0])})'
    elif op == 0x1 and len(body) >= 5:
        src = (body[0] << 32) | body[1]
        dst = (body[2] << 32) | body[3]
        nb = body[4]
        opname = f'CDMA src=0x{src:010x} dst=0x{dst:010x} len={nb}B'
    print(f"  [{idx:4d}] {opname}")
