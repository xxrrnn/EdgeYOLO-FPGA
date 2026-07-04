import sys
from pathlib import Path
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

words = parse_inst_words(Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8/inst.hex'))
unit_map = {0:'RELU', 1:'DQA', 2:'QA', 3:'AD', 4:'MP', 5:'US', 6:'CONCAT', 7:'IM2COL'}

# Check word 220 (last VPU before END)
w = words[220]
blen = w & 0xFFFFFF
bwords = blen // 4
body = words[221:221+bwords]
print(f"word 220: 0x{w:08x} blen={blen} bwords={bwords}")
print(f"  body[0] (unit) = {body[0]} = {unit_map.get(body[0], '?')}")
print(f"  body[1] (src)  = 0x{body[1]:08x}")
if len(body) > 2:
    print(f"  body[2] (src2) = 0x{body[2]:08x}")
if len(body) > 8:
    print(f"  body[8] (dst)  = 0x{body[8]:08x}")
if len(body) > 12:
    print(f"  body[12] (flags) = 0x{body[12]:08x}")

print()
# Check word 196 (DQA)
w2 = words[196]
bwords2 = (w2 & 0xFFFFFF) // 4
body2 = words[197:197+bwords2]
print(f"word 196: unit={body2[0]}={unit_map.get(body2[0],'?')} src=0x{body2[1]:08x} dst=0x{body2[8]:08x}")

# Look for output address -> SLOT_C
print()
# SLOT_C is typically VPU_BUF + 0x200000
SLOT_C = 0x02200000  # relative to VPU_BUF_BASE 0x1_0200_0000
print(f"Expected SLOT_C relative = 0x{SLOT_C:08x}")
# Scan all VPU exec instructions for dst address
for j in range(len(words)):
    ww = words[j]
    op = (ww >> 28) & 0xF
    if op == 0x2:
        bl = (ww & 0xFFFFFF) // 4
        bd = words[j+1:j+1+bl]
        if len(bd) > 8:
            dst = bd[8]
            unit = unit_map.get(bd[0], str(bd[0]))
            print(f"  VPU({unit}) dst=0x{dst:08x}")
