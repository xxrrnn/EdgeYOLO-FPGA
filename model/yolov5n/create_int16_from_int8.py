"""create_int16_from_int8.py
将 INT8 parsed 参数升位为 INT16 格式，用于验证 INT16 硬件通路。

原理：
  INT8 模型已验证正确（E2E 19 detections）。
  只需将 weight_int8 的 dtype 从 int8 拓宽为 int16（值不变），
  golden_conv_forward 的 float32 matmul 即可处理 int16 dtype，
  结果与 INT8 完全等价（bit-exact）。

输出目录：model/yolov5n/parsed_int16_from_int8/
运行：
  cd model/yolov5n
  python create_int16_from_int8.py
"""
import json
import numpy as np
from pathlib import Path
import shutil

BASE = Path(__file__).resolve().parents[2]
SRC_DIR = Path(__file__).resolve().parent / 'parsed'
DST_DIR = Path(__file__).resolve().parent / 'parsed_int16_from_int8'
DST_WEIGHTS = DST_DIR / 'weights'

def main():
    DST_WEIGHTS.mkdir(parents=True, exist_ok=True)

    # 1. 拷贝并修改 network.json
    src_net = json.load(open(str(SRC_DIR / 'network.json')))

    # 修改 bit_width 和 input_act_scale
    # INT8 input scale: 1/127 ≈ 0.007874
    input_act_scale = 1.0 / 127.0

    dst_net = dict(src_net)
    dst_net['model'] = 'yolov5n-int16-from-int8'
    dst_net['bit_width'] = 16
    dst_net['input_act_scale'] = input_act_scale

    # 各层无需修改（act_scale, dqa_scale 等全部保持不变）
    # 只需让 golden 知道这是 int16 模式（通过 weight dtype 判断）

    with open(str(DST_DIR / 'network.json'), 'w') as f:
        json.dump(dst_net, f, indent=2)
    print(f"[OK] network.json -> {DST_DIR / 'network.json'}")

    # 2. 遍历所有 NPZ，将 weight_int8 dtype 升位为 int16
    src_weights = sorted((SRC_DIR / 'weights').glob('*.npz'))
    print(f"Found {len(src_weights)} NPZ files to convert...")

    for src_npz_path in src_weights:
        data = dict(np.load(str(src_npz_path), allow_pickle=False))

        if 'weight_int8' in data:
            w = data['weight_int8']
            if w.dtype == np.int8:
                # 升位：值不变，dtype 从 int8 → int16
                data['weight_int8'] = w.astype(np.int16)

        dst_npz_path = DST_WEIGHTS / src_npz_path.name
        np.savez_compressed(str(dst_npz_path), **data)

    print(f"[OK] Converted {len(src_weights)} weight NPZ files -> {DST_WEIGHTS}")

    # 3. 验证第一层
    npz0 = np.load(str(DST_WEIGHTS / 'model_0_conv.npz'))
    print(f"\nVerification - model.0.conv:")
    print(f"  weight_int8 dtype: {npz0['weight_int8'].dtype}")
    print(f"  weight_int8 range: [{npz0['weight_int8'].min()}, {npz0['weight_int8'].max()}]")
    print(f"  dqa_scale[:3]: {npz0['dqa_scale'][:3]}")
    print(f"  act_scale: {float(npz0['act_scale']):.6f}")

    net_loaded = json.load(open(str(DST_DIR / 'network.json')))
    print(f"\n  network.json bit_width: {net_loaded['bit_width']}")
    print(f"  network.json input_act_scale: {net_loaded['input_act_scale']:.8e}")

    print(f"\n[DONE] INT16-from-INT8 model ready at: {DST_DIR}")
    print(f"\nUsage:")
    print(f"  cd tests/chip/unit-tb")
    print(f"  python e2e_detect.py --images <img_dir> --dry-run --int16 --conf 0.25")

if __name__ == '__main__':
    main()
