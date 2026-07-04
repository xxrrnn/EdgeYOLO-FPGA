import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')
words = parse_inst_words(run_dir / 'inst.hex')

# Decode VPU(AD) instructions (word 103 and 220)
for target_word in [103, 220]:
    w = words[target_word]
    op = (w >> 28) & 0xF
    blen = w & 0xFFFFFF
    bwords = blen // 4
    body = words[target_word+1:target_word+1+bwords]
    print(f"VPU instruction at word {target_word}: op=0x{op:x} bwords={bwords}")
    for j, v in enumerate(body):
        print(f"  body[{j:2d}] = 0x{v:08x}")
    # Fields: unit, src1, src2, ?, ?, ?, ?, ?, dst, ...
    UNIT_NAMES = {0:'RELU',1:'DQA',2:'QA',3:'AD',4:'MP',5:'US',6:'CONCAT',7:'IM2COL'}
    if len(body) >= 9:
        unit = UNIT_NAMES.get(body[0], body[0])
        src1 = body[1]
        src2 = body[2]
        dst  = body[8]
        print(f"  -> unit={unit} src1=0x{src1:08x} src2=0x{src2:08x} dst=0x{dst:08x}")
    print()
