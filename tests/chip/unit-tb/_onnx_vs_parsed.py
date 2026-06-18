"""对比 ONNX 中的量化参数与 parsed 目录中的参数
确认 parse_onnx.py 正确提取了所有参数，与原始 ONNX 完全一致。
"""
import os
import numpy as np
import onnx
from onnx import numpy_helper

model = onnx.load('model/yolov5n/best.quant.onnx')

tensors = {}
for node in model.graph.node:
    if node.op_type == 'Constant':
        out_name = node.output[0]
        for attr in node.attribute:
            if attr.name == 'value':
                tensors[out_name] = numpy_helper.to_array(attr.t)

parsed_dir = 'model/yolov5n/parsed/weights'

def layer_to_npz_fname(layer):
    return layer.replace('.', '_') + '.npz'

layers_to_check = [
    'model.0.conv', 'model.1.conv', 'model.2.cv1.conv', 'model.2.cv2.conv',
    'model.2.cv3.conv', 'model.2.m.0.cv1.conv', 'model.2.m.0.cv2.conv',
    'model.3.conv', 'model.4.cv1.conv', 'model.4.cv2.conv', 'model.4.cv3.conv',
    'model.4.m.0.cv1.conv', 'model.4.m.0.cv2.conv',
    'model.4.m.1.cv1.conv', 'model.4.m.1.cv2.conv',
    'model.5.conv', 'model.6.cv1.conv', 'model.6.cv2.conv', 'model.6.cv3.conv',
    'model.6.m.0.cv1.conv', 'model.6.m.0.cv2.conv',
    'model.6.m.1.cv1.conv', 'model.6.m.1.cv2.conv',
    'model.6.m.2.cv1.conv', 'model.6.m.2.cv2.conv',
    'model.7.conv', 'model.8.cv1.conv', 'model.8.cv2.conv', 'model.8.cv3.conv',
    'model.8.m.0.cv1.conv', 'model.8.m.0.cv2.conv',
    'model.9.cv1.conv', 'model.9.cv2.conv',
    'model.10.conv', 'model.13.cv1.conv', 'model.13.cv2.conv', 'model.13.cv3.conv',
    'model.13.m.0.cv1.conv', 'model.13.m.0.cv2.conv',
    'model.14.conv', 'model.17.cv1.conv', 'model.17.cv2.conv', 'model.17.cv3.conv',
    'model.17.m.0.cv1.conv', 'model.17.m.0.cv2.conv',
    'model.18.conv', 'model.20.cv1.conv', 'model.20.cv2.conv', 'model.20.cv3.conv',
    'model.20.m.0.cv1.conv', 'model.20.m.0.cv2.conv',
    'model.21.conv', 'model.23.cv1.conv', 'model.23.cv2.conv', 'model.23.cv3.conv',
    'model.23.m.0.cv1.conv', 'model.23.m.0.cv2.conv',
]

print('=== ONNX vs Parsed 参数对比 ===\n')
all_match = True
n_checked = 0

for layer in layers_to_check:
    npz_path = os.path.join(parsed_dir, layer_to_npz_fname(layer))
    if not os.path.exists(npz_path):
        print(f'[{layer}] npz NOT FOUND: {layer_to_npz_fname(layer)}')
        all_match = False
        continue
    npz = np.load(npz_path)

    w_key = f'w__{layer}__int'
    s_key = f'w__{layer}__scale'
    parts = layer.split('.')
    if parts[-1] == 'conv':
        act_key = 'a__' + '.'.join(parts[:-1]) + '.act__scale'
    else:
        act_key = f'a__{layer}.act__scale'

    w_onnx = tensors.get(w_key)
    s_onnx = tensors.get(s_key)
    a_onnx = tensors.get(act_key)

    w_parsed = npz['weight_int8']
    w_scale_parsed = npz['weight_scale']
    act_scale_parsed = float(npz['act_scale'])

    w_match = np.array_equal(w_onnx, w_parsed) if w_onnx is not None else False
    ws_match = np.allclose(s_onnx.flatten(), w_scale_parsed.flatten(), rtol=1e-6) if s_onnx is not None else False
    a_close = np.isclose(float(a_onnx), act_scale_parsed, rtol=1e-6) if a_onnx is not None else False

    ok = w_match and ws_match and a_close
    if not ok:
        all_match = False
        print(f'[{layer}] MISMATCH: w={w_match}, ws={ws_match}, act={a_close}')
        if not w_match and w_onnx is not None:
            diff = w_onnx.astype(np.int16) - w_parsed.astype(np.int16)
            print(f'  weight diff: max_abs={np.max(np.abs(diff))}, nonzero={np.count_nonzero(diff)}/{diff.size}')
        if not ws_match and s_onnx is not None:
            d = np.abs(s_onnx.flatten() - w_scale_parsed.flatten())
            print(f'  w_scale diff max={np.max(d):.6e}')
        if not a_close and a_onnx is not None:
            print(f'  act_scale: onnx={float(a_onnx):.8e} vs parsed={act_scale_parsed:.8e}')
    else:
        n_checked += 1

print(f'\n--- Summary: {n_checked}/{len(layers_to_check)} layers EXACT MATCH ---')
if all_match:
    print('ALL LAYERS MATCH! parsed 目录参数与 ONNX 完全一致。')
else:
    print('存在不匹配，请检查上方输出。')
