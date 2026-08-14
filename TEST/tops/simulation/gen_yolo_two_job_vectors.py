#!/usr/bin/env python3
"""Dump YOLO model.0.conv OH-tile0/tile1 IBUF+golden for the two-job Verilator TB."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(REPO / "tests" / "chip" / "unit-tb"))

from golden_module_tb import (  # noqa: E402
    bytes_to_128_words,
    conv_meta,
    im2col,
    int32_to_words,
    load_network,
    pack_weight_tile,
    write_hex,
)
from run import load_image, preprocess_yolov5n  # noqa: E402

YOLO_PARSED = REPO / "model" / "yolov5n_coco50k_qat" / "parsed_int8"
YOLO_IMG = REPO / "examples" / "coco" / "000000000139.jpg"
OUT_DIR = REPO / "output" / "tops" / "simulation" / "yolo_two_job"
OH_TILE_ROWS = 25  # compiler: 6*25 + 10, first two tiles are 25*160 = 4000 px


def main() -> int:
    net = load_network(str(YOLO_PARSED / "network.json"))
    meta = conv_meta(net, "model.0.conv")
    img = load_image(str(YOLO_IMG))
    feat, _ratio, _pad, _orig = preprocess_yolov5n(img)
    cols = im2col(feat, meta)
    npz = np.load(meta.npz_path)
    w = npz["weight_int8"].reshape(meta.out_ch, -1).astype(np.int32)
    acc = meta.acc_depth
    k_pad = acc * 64
    if w.shape[1] < k_pad:
        w = np.pad(w, ((0, 0), (0, k_pad - w.shape[1])))
    ow = (feat.shape[1] + meta.pad_w0 + meta.pad_w1 - meta.kw) // meta.stride_w + 1
    n_pix = OH_TILE_ROWS * ow
    assert cols.shape[0] >= 2 * n_pix, cols.shape
    assert acc == 2 and n_pix == 4000, (acc, n_pix, ow)

    wei = [f"{e:032x}" for e in pack_weight_tile(meta, npz["weight_int8"], 0)]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_hex(OUT_DIR / "wei.hex", wei)

    stats = {}
    for job, sl in (("0", slice(0, n_pix)), ("1", slice(n_pix, 2 * n_pix))):
        tile_cols = cols[sl]
        act = bytes_to_128_words(tile_cols.astype(np.int8).tobytes())
        exp = (tile_cols.astype(np.int32) @ w.T).astype(np.int32)
        write_hex(OUT_DIR / f"act{job}.hex", act)
        write_hex(OUT_DIR / f"exp{job}.hex", int32_to_words(exp))
        stats[job] = {
            "act_words": len(act),
            "exp_words": n_pix * 4,
            "exp_range": [int(exp.min()), int(exp.max())],
            "pix0_exp": exp[0].tolist(),
            "pix211_exp": exp[211].tolist() if exp.shape[0] > 211 else None,
        }
        print(
            f"job{job} pixels={n_pix} act_words={len(act)} "
            f"exp_range=[{exp.min()},{exp.max()}] mean={exp.mean():.3f}",
            flush=True,
        )

    meta_out = {
        "pixels": n_pix,
        "acc_depth": acc,
        "ow": int(ow),
        "oh_tile_rows": OH_TILE_ROWS,
        "weight_words": len(wei),
        "act_stride_words": acc * 4,
        "weight_base": n_pix * acc * 4,
        "jobs": stats,
    }
    (OUT_DIR / "meta.json").write_text(json.dumps(meta_out, indent=2) + "\n")
    print(f"wrote {OUT_DIR} wei_words={len(wei)} weight_base={meta_out['weight_base']}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
