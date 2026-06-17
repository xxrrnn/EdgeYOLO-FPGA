"""Full decode of mini_network inst.hex."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import parse_inst_words

OP_NAMES = {
    0x0: 'NOP', 0x1: 'CDMA', 0x2: 'VPU_EXEC', 0x3: 'WAIT_CDMA',
    0x4: 'WAIT_VPU', 0x5: 'SYNC', 0x6: 'DCIM_EXEC', 0x7: 'WAIT_DCIM',
    0x8: 'DCIM_CFG', 0x9: 'DCIM_LAYER', 0xF: 'END',
}

VPU_UNITS = {7: 'IM2COL', 0: 'RELU', 1: 'DQA', 2: 'QA', 3: 'AD', 4: 'MP', 5: 'US', 6: 'CONCAT'}


def decode_inst(words, start, max_insts=20):
    i = start
    count = 0
    while i < len(words) and count < max_insts:
        w = words[i]
        op = (w >> 28) & 0xF
        flags = (w >> 24) & 0xF
        body_bytes = w & 0xFFFFFF
        body_words = body_bytes // 4
        body = words[i+1:i+1+body_words]

        if op == 0xF:  # END
            print(f'  [{i:3d}] END')
            break
        elif op == 0x0 and body_bytes == 0:  # NOP
            nops = 0
            j = i
            while j < len(words) and (words[j] >> 28) == 0 and (words[j] & 0xFFFFFF) == 0:
                nops += 1
                j += 1
            print(f'  [{i:3d}] NOP ×{nops}')
            i = j
            count += 1
            continue
        elif op == 0x1:  # CDMA
            if body_words == 3:
                src = body[0]
                dst = body[1]
                length = body[2]
                print(f'  [{i:3d}] CDMA_COPY  src=0x{src:08x}  dst=0x{dst:08x}  len={length}B')
            elif body_words >= 5:
                src = body[0]; dst = body[1]; cp = body[2]; ss = body[3]; ds = body[4]
                cnt = body[5] if len(body) > 5 else '?'
                print(f'  [{i:3d}] CDMA_STRIDE  src=0x{src:08x} dst=0x{dst:08x} copy={cp}B '
                      f'src_stride={ss} dst_stride={ds} count={cnt}')
            else:
                print(f'  [{i:3d}] CDMA? body_words={body_words}: {[hex(x) for x in body]}')
        elif op == 0x2:  # VPU_EXEC
            unit = body[0] if body else '?'
            src = body[1] if len(body) > 1 else '?'
            dst = body[9] if len(body) > 9 else '?'
            uname = VPU_UNITS.get(unit, f'unit={unit}')
            print(f'  [{i:3d}] VPU_EXEC  {uname}  src=0x{src:08x}  dst=0x{dst:08x} (flags=0x{flags:x})')
        elif op == 0x9:  # DCIM_LAYER
            np_ = body[0]; mode = body[1]; tmask = body[2]
            act_base = body[4]; act_str = body[5]; out_str = body[6]
            print(f'  [{i:3d}] DCIM_LAYER  num_px={np_} mode=0x{mode:x} tile_mask=0x{tmask:x} '
                  f'act_base={act_base} act_stride={act_str} out_stride={out_str}')
        elif op == 0x3:
            print(f'  [{i:3d}] WAIT_CDMA')
        elif op == 0x4:
            print(f'  [{i:3d}] WAIT_VPU')
        elif op == 0x7:
            print(f'  [{i:3d}] WAIT_DCIM')
        else:
            print(f'  [{i:3d}] {OP_NAMES.get(op, hex(op))} body_words={body_words}')

        i += 1 + body_words
        count += 1


for case in ['mini_2conv_c16', 'mini_3conv_residual_c32']:
    path = Path(f'tests/chip/unit-tb/runs/mini_network_{case}_qint8/inst.hex')
    words = parse_inst_words(path)
    print(f'\n{"="*60}')
    print(f'{case}: {len(words)} words')
    print(f'{"="*60}')
    decode_inst(words, 0, max_insts=25)
