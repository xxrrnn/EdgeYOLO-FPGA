"""Verify: mini_3conv uses 2-tile DCIM (same bug as dcim_model_1_conv?) and mini_2conv uses 1-tile."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

OP_NAMES = {0x0:'NOP',0x1:'CDMA',0x2:'VPU',0x3:'WAIT_CDMA',0x4:'WAIT_VPU',
            0x5:'SYNC',0x6:'DCIM_EXEC',0x7:'WAIT_DCIM',0x8:'DCIM_CFG',0x9:'DCIM_LAYER',0xF:'END'}

for case in ['mini_2conv_c16', 'mini_3conv_residual_c32']:
    path = Path(f'tests/chip/unit-tb/runs/mini_network_{case}_qint8/inst.hex')
    words = parse_inst_words(path)
    print(f'\n{case}:')
    i = 0
    while i < len(words):
        w = words[i]
        op = (w >> 28) & 0xF
        blen = w & 0xFFFFFF
        bwords = blen // 4
        if op == 0x9:  # DCIM_LAYER
            body = words[i+1:i+1+bwords]
            num_px = body[0]
            mode   = body[1]
            tmask  = body[2]
            acc = (mode >> 8) & 0xFF
            mode_val = mode & 0xFF
            act_stride = body[5]
            out_stride = body[6]
            n_tiles = bin(tmask).count('1')
            print(f'  DCIM_LAYER: num_px={num_px} tile_mask=0x{tmask:x} n_tiles={n_tiles} '
                  f'acc={acc} mode=0x{mode_val:x} act_stride={act_stride} out_stride={out_stride}')
        i += 1 + bwords
        if op == 0xF:
            break
