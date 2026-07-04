import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')
words = parse_inst_words(run_dir / 'inst.hex')

# Find DCIM_LAYER at word 21
for target in [21, 138]:
    w = words[target]
    op = (w >> 28) & 0xF
    blen = w & 0xFFFFFF
    bwords = blen // 4
    body = words[target+1:target+1+bwords]
    print(f"DCIM_LAYER at word {target}: op=0x{op:x} blen={blen} bwords={bwords}")
    for j, v in enumerate(body):
        print(f"  body[{j:2d}] = 0x{v:08x}  ({v})")
    print()
