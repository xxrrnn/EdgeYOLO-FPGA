import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

OP_NAMES = {0x0:'NOP',0x1:'CDMA',0x2:'VPU',0x3:'WAIT_CDMA',0x4:'WAIT_VPU',
            0x5:'SYNC',0x6:'DCIM_EXEC',0x7:'WAIT_DCIM',0x8:'DCIM_CFG',
            0x9:'DCIM_LAYER',0xF:'END'}
UNIT_NAMES = {0:'RELU',1:'DQA',2:'QA',3:'AD',4:'MP',5:'US',6:'CONCAT',7:'IM2COL'}

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')
words = parse_inst_words(run_dir / 'inst.hex')
print(f"inst.hex: {len(words)} words")
print()

i = 0
while i < len(words):
    w = words[i]
    op = (w >> 28) & 0xF
    blen = w & 0xFFFFFF
    bwords = blen // 4
    body = words[i+1:i+1+bwords]
    opname = OP_NAMES.get(op, f'0x{op:x}')
    if op == 0x0 and bwords == 0:
        i += 1
        continue
    elif op == 0x1 and len(body) >= 5:
        src = (body[0] << 32) | body[1]
        dst = (body[2] << 32) | body[3]
        nb = body[4]
        print(f'[{i:3d}] CDMA src=0x{src:011x} dst=0x{dst:011x} len={nb}B')
    elif op == 0x2 and body:
        unit = UNIT_NAMES.get(body[0], body[0])
        src_rel = body[1] if len(body) > 1 else 0
        dst_rel = body[8] if len(body) > 8 else 0
        print(f'[{i:3d}] VPU({unit}) src=0x{src_rel:08x} dst=0x{dst_rel:08x}')
    elif op == 0x9:
        tile_mask = (body[2] << 32) | body[3] if len(body) >= 4 else 0
        n_tiles = bin(tile_mask).count('1')
        print(f'[{i:3d}] DCIM_LAYER tile_mask=0x{tile_mask:x} n_tiles={n_tiles}')
    elif op == 0xF:
        print(f'[{i:3d}] END')
        break
    else:
        print(f'[{i:3d}] {opname}')
    i += 1 + bwords
