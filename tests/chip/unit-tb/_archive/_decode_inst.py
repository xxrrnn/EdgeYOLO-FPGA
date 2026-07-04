"""Decode and verify DCIM_LAYER instruction body fields for model_0 and model_1."""
import sys
sys.path.insert(0, 'tools')
from chip_config import *


def parse_inst(fname):
    words = []
    with open(fname) as f:
        for line in f:
            line = line.strip()
            if line:
                words.append(int(line, 16))
    return words


cases = [
    ('model_0(acc=2,N=16)', 'tests/chip/unit-tb/runs/dcim_model_0_conv_debug/inst.hex', 2),
    ('model_1(acc=3,N=32)', 'tests/chip/unit-tb/runs/dcim_model_1_conv_debug/inst.hex', 3),
]

for label, path, expected_acc in cases:
    words = parse_inst(path)
    header = words[0]
    opcode = (header >> 28) & 0xF
    length = header & 0xFFFFFF
    body_words = length // 4
    print(f'{label}: opcode=0x{opcode:X} body_words={body_words}')
    body = words[1:1 + body_words]

    num_pixels   = body[0]
    mode_reg     = body[1]
    tile_mask_lo = body[2]
    tile_mask_hi = body[3]
    act_base     = body[4]
    act_stride   = body[5]
    out_stride   = body[6]
    reserved     = body[7]
    acc_depth    = (mode_reg >> 8) & 0xFF
    mode_val     = mode_reg & 0xFF

    print(f'  num_pixels={num_pixels}')
    print(f'  mode_reg=0x{mode_reg:08x}  acc_depth={acc_depth}  mode=0x{mode_val:x}')
    print(f'  tile_mask=0x{(tile_mask_hi << 32) | tile_mask_lo:016x}')
    print(f'  act_base={act_base}')
    print(f'  act_stride={act_stride} (0x{act_stride:x})')
    print(f'  out_stride={out_stride} (0x{out_stride:x})')

    expected_act = acc_depth * DCIM_INT8_ACT_WORDS
    expected_out = DCIM_INT8_OUT_WORDS_PER_TILE
    act_ok = act_stride == expected_act
    out_ok = out_stride == expected_out
    print(f'  EXPECTED act_stride={expected_act}(0x{expected_act:x})  {"OK" if act_ok else "WRONG!"}')
    print(f'  EXPECTED out_stride={expected_out}(0x{expected_out:x})  {"OK" if out_ok else "WRONG!"}')
    print()
