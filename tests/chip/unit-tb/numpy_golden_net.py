"""
numpy_golden_net.py  ——  YOLOv5n backbone+neck 纯 numpy 参考实现

直接从 npz 权重文件读取，逐层计算，与 FPGA 链式执行对比拓扑正确性。

用法：
    from numpy_golden_net import run_yolov5n_golden
    acts = run_yolov5n_golden(input_img_int8)  # 返回每层 INT8 输出
"""
from __future__ import annotations
import sys
import numpy as np
from pathlib import Path

_THIS = Path(__file__).resolve()
_REPO = _THIS.parents[3]
sys.path.insert(0, str(_THIS.parent))
sys.path.insert(0, str(_REPO / "rtl" / "tb" / "lite_bd" / "module_tb"))

from golden_module_tb import (
    load_network, conv_meta, out_hw, im2col,
    load_layer_npz_checked, dcim_effective_out_ch,
)

_NETWORK_JSON = str(_REPO / "model" / "yolov5n" / "parsed" / "network.json")
_net_cache = None


def _net():
    global _net_cache
    if _net_cache is None:
        _net_cache = load_network(_NETWORK_JSON)
    return _net_cache


def _conv_np(feat: np.ndarray, layer_name: str) -> np.ndarray:
    """单层 conv 的 numpy 参考（INT8 in → INT8 out，经 DQA + QA）。"""
    meta = conv_meta(_net(), layer_name)
    # 若 feat 的 in_ch 与 meta 不同（cout-tiling 中间激活），以 feat 为准
    h, w, c = feat.shape
    if c != meta.in_ch:
        import copy
        meta = copy.copy(meta)
        meta.in_ch = c

    oh, ow = out_hw(h, w, meta)
    npz = load_layer_npz_checked(meta, _net(), require_activation=True)
    weights = npz['weight_int8']
    scale   = npz['dqa_scale'].astype(np.float32)[:meta.out_ch]
    bias    = npz['dqa_bias'].astype(np.float32)[:meta.out_ch]
    qscale  = np.float32(1.0 / float(npz['act_scale']))

    cols = im2col(feat, meta)
    wflat = weights[:meta.out_ch].reshape(meta.out_ch, -1).astype(np.int32)
    K = meta.acc_depth * 64
    if wflat.shape[1] < K:
        wflat = np.pad(wflat, ((0, 0), (0, K - wflat.shape[1])))
    accum = cols.astype(np.int32) @ wflat.T
    dqa   = np.maximum(accum.astype(np.float32) * scale[None, :] + bias[None, :], 0.0)
    qa    = np.clip(np.round(dqa * qscale), -128, 127).astype(np.int8)
    return qa.reshape(oh, ow, meta.out_ch)


def _add_np(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.clip(a.astype(np.int16) + b.astype(np.int16), -128, 127).astype(np.int8)


def _concat_np(feats: list, axis: int = -1) -> np.ndarray:
    return np.concatenate(feats, axis=axis)


def _maxpool_np(feat: np.ndarray, k: int = 5) -> np.ndarray:
    pad = k // 2
    h, w, c = feat.shape
    padded = np.pad(feat.astype(np.int16),
                    [(pad, pad), (pad, pad), (0, 0)],
                    mode='constant', constant_values=-128)
    out = np.empty((h, w, c), dtype=np.int16)
    for i in range(h):
        for j in range(w):
            out[i, j] = padded[i:i+k, j:j+k, :].max(axis=(0, 1))
    return out.astype(np.int8)


def _upsample_np(feat: np.ndarray, scale: int = 2) -> np.ndarray:
    return np.repeat(np.repeat(feat, scale, axis=0), scale, axis=1)


def _c3_np(feat: np.ndarray, mid: str, n: int) -> np.ndarray:
    """YOLOv5 C3 block numpy 参考。"""
    p = f"model.{mid}"
    cv1 = _conv_np(feat, f"{p}.cv1.conv")
    cv2 = _conv_np(feat, f"{p}.cv2.conv")
    x = cv1
    for i in range(n):
        shortcut = x
        x = _conv_np(x, f"{p}.m.{i}.cv1.conv")
        x = _conv_np(x, f"{p}.m.{i}.cv2.conv")
        if shortcut.shape == x.shape:
            x = _add_np(shortcut, x)
    cat = _concat_np([x, cv2], axis=-1)
    return _conv_np(cat, f"{p}.cv3.conv")


def run_yolov5n_golden(input_img_int8: np.ndarray, verbose: bool = False) -> dict:
    """运行完整的 YOLOv5n backbone+neck（numpy 参考，无 FPGA）。

    input_img_int8 : INT8 (H, W, 3)
    返回: 各关键层的 INT8 激活字典，键与 _l4_full_network_test.py 对应
    """
    acts = {}

    def _c(name, feat):
        out = _conv_np(feat, name)
        if verbose:
            print(f"  [golden] {name}: {feat.shape} → {out.shape}")
        acts[name] = out
        return out

    x = input_img_int8
    x = _c("model.0.conv", x)
    x = _c("model.1.conv", x)

    acts["model.2"] = _c3_np(x, "2", n=1)
    if verbose: print(f"  [golden] model.2 (C3): → {acts['model.2'].shape}")
    x = acts["model.2"]

    x = _c("model.3.conv", x)

    acts["model.4"] = _c3_np(x, "4", n=2)
    if verbose: print(f"  [golden] model.4 (C3): → {acts['model.4'].shape}")
    x = acts["model.4"]

    x = _c("model.5.conv", x)

    acts["model.6"] = _c3_np(x, "6", n=3)
    if verbose: print(f"  [golden] model.6 (C3): → {acts['model.6'].shape}")
    x = acts["model.6"]

    x = _c("model.7.conv", x)

    acts["model.8"] = _c3_np(x, "8", n=1)
    if verbose: print(f"  [golden] model.8 (C3): → {acts['model.8'].shape}")
    x8 = acts["model.8"]

    # SPPF
    cv1_out = _c("model.9.cv1.conv", x8)
    mp1 = _maxpool_np(cv1_out, k=5)
    mp2 = _maxpool_np(mp1, k=5)
    mp3 = _maxpool_np(mp2, k=5)
    sppf_cat = _concat_np([cv1_out, mp1, mp2, mp3])
    x9 = _c("model.9.cv2.conv", sppf_cat)

    x10 = _c("model.10.conv", x9)

    # Neck FPN
    x_up1  = _upsample_np(x10, scale=2)
    cat_6  = _concat_np([x_up1, acts["model.6"]])
    acts["model.13"] = _c3_np(cat_6, "13", n=1)
    x13 = acts["model.13"]
    if verbose: print(f"  [golden] model.13 (C3): → {x13.shape}")

    x14 = _c("model.14.conv", x13)

    x_up2  = _upsample_np(x14, scale=2)
    cat_4  = _concat_np([x_up2, acts["model.4"]])
    acts["model.17"] = _c3_np(cat_4, "17", n=1)
    x17 = acts["model.17"]
    if verbose: print(f"  [golden] model.17 (C3): → {x17.shape}")

    # Neck PAN
    x18 = _c("model.18.conv", x17)
    cat_13 = _concat_np([x18, x13])
    acts["model.20"] = _c3_np(cat_13, "20", n=1)
    x20 = acts["model.20"]

    x21 = _c("model.21.conv", x20)
    cat_8  = _concat_np([x21, x8])
    acts["model.23"] = _c3_np(cat_8, "23", n=1)

    return acts
