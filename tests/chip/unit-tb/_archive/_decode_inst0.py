"""decode_inst0.py - 解码 model.0 conv pipeline 的 inst.hex"""
from pathlib import Path

run_dir = Path('runs/conv_pipeline_pipe_model0_conv_32x32_qint8')
words = [int(l.strip(), 16) for l in open(run_dir/'inst.hex') if l.strip()]

OP_NAMES = {1:'CDMA', 2:'WAIT_CDMA', 3:'DCIM', 4:'VPU_EXEC', 5:'WAIT_VPU', 6:'END', 7:'NOP'}
UNIT_NAMES = {1:'DQA', 2:'QA', 3:'MP', 4:'NOP', 5:'IM2COL', 6:'US', 7:'ADD'}

i = 0
while i < len(words):
    w = words[i]
    op = (w >> 28) & 0xF
    flags = (w >> 24) & 0xF
    blen = w & 0xFFFFFF
    name = OP_NAMES.get(op, f'OP{op}')

    if op == 4:  # VPU_EXEC
        body = words[i+1:i+1+blen]
        unit_id = body[0] if body else -1
        uname = UNIT_NAMES.get(unit_id, f'UNIT{unit_id}')
        if unit_id == 5:  # IM2COL
            c = body[3]; h = body[4]; w2 = body[5]
            bias = body[6]; scale = body[7]; dst_off = body[8]; ab = body[9]
            kh=(ab>>24)&0xFF; kw2=(ab>>16)&0xFF; sh=(ab>>12)&0xF; sw=(ab>>8)&0xF; ph=(ab>>4)&0xF; pw=ab&0xF
            print(f'[{i:3d}] VPU_EXEC(IM2COL) c={c} h={h} w={w2} dst=0x{dst_off:x}')
            print(f'       kh={kh} kw={kw2} stride={sh},{sw} pad={ph},{pw} ab=0x{ab:08x}')
        else:
            print(f'[{i:3d}] VPU_EXEC({uname}) blen={blen} body[1:]={[hex(x) for x in body[1:4]]}')
        i += 1 + blen
    elif op == 1:  # CDMA
        body = words[i+1:i+1+blen]
        cdma_type = (body[0] >> 28) & 0xF if body else 0
        print(f'[{i:3d}] CDMA blen={blen} body0=0x{body[0]:08x}')
        i += 1 + blen
    elif op in (2, 5, 6, 7):
        print(f'[{i:3d}] {name}')
        i += 1
    elif op == 3:  # DCIM
        body = words[i+1:i+1+blen]
        m_val = body[0] if body else 0
        print(f'[{i:3d}] DCIM blen={blen} M={m_val}')
        i += 1 + blen
    else:
        print(f'[{i:3d}] OP{op} flags={flags} blen={blen}')
        i += 1 + max(blen, 0)
