"""
postprocess.py - host-side post-processing for the two supported networks.

Driven by tools/runtime/configs/<network>.yaml, which lists:
  - input_shape, output_shape
  - input_dtype, output_dtype
  - class_names, anchors (yolov5n), nms_thresh, conf_thresh
  - top_k (resnet18)

Usage (programmatic):
    from runtime.postprocess import yolov5n_nms, resnet18_topk
    boxes = yolov5n_nms(fp32_output[..., :8], cfg)
    classes = resnet18_topk(fp32_logits, cfg)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np


def softmax(x: np.ndarray, axis=-1) -> np.ndarray:
    x = x - x.max(axis=axis, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)


def resnet18_topk(logits: np.ndarray, top_k: int = 5,
                  class_names: List[str] | None = None) -> List[Tuple[int, float, str]]:
    """Return top_k (class_idx, prob, name) by descending probability."""
    probs = softmax(logits.reshape(-1))
    idx = np.argsort(-probs)[:top_k]
    out = []
    for i in idx:
        name = class_names[i] if class_names and i < len(class_names) else f"class_{i}"
        out.append((int(i), float(probs[i]), name))
    return out


def yolov5n_decode(raw: np.ndarray, anchors: np.ndarray, stride: int, num_classes: int = 3
                   ) -> np.ndarray:
    """Decode one detection head's tensor [n_anchors, H, W, 5+num_classes] → [N, 6]
    where each row is (cx, cy, w, h, obj, cls_id).  Values in input space."""
    n_anc, H, W, dim = raw.shape
    grid_y, grid_x = np.meshgrid(np.arange(H), np.arange(W), indexing="ij")
    grid_x = grid_x[None, :, :, None]   # [1, H, W, 1]
    grid_y = grid_y[None, :, :, None]
    sig = 1.0 / (1.0 + np.exp(-raw))
    # YOLOv5 head: xy = (sig*2 - 0.5 + grid) * stride; wh = (sig*2)**2 * anchor
    xy = (sig[..., 0:2] * 2 - 0.5 + np.concatenate([grid_x, grid_y], -1)) * stride
    wh = (sig[..., 2:4] * 2) ** 2 * anchors.reshape(n_anc, 1, 1, 2)
    obj = sig[..., 4:5]
    cls = sig[..., 5:5 + num_classes]
    score = obj * cls.max(-1, keepdims=True)
    cls_id = cls.argmax(-1, keepdims=True).astype(np.float32)
    out = np.concatenate([xy, wh, score, cls_id], -1).reshape(-1, 6)
    return out


def iou_xywh(boxes: np.ndarray) -> np.ndarray:
    """All-pairs IOU on [N, 4] (cx, cy, w, h)."""
    x1 = boxes[:, 0] - boxes[:, 2] / 2
    y1 = boxes[:, 1] - boxes[:, 3] / 2
    x2 = boxes[:, 0] + boxes[:, 2] / 2
    y2 = boxes[:, 1] + boxes[:, 3] / 2
    inter_x1 = np.maximum(x1[:, None], x1[None, :])
    inter_y1 = np.maximum(y1[:, None], y1[None, :])
    inter_x2 = np.minimum(x2[:, None], x2[None, :])
    inter_y2 = np.minimum(y2[:, None], y2[None, :])
    iw = np.clip(inter_x2 - inter_x1, 0, None)
    ih = np.clip(inter_y2 - inter_y1, 0, None)
    inter = iw * ih
    area = (x2 - x1) * (y2 - y1)
    union = area[:, None] + area[None, :] - inter
    return inter / np.maximum(union, 1e-6)


def nms(boxes: np.ndarray, scores: np.ndarray, iou_thresh: float = 0.45) -> np.ndarray:
    """Greedy NMS.  boxes: [N,4] cxcywh, scores: [N]."""
    order = np.argsort(-scores)
    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(i)
        if order.size == 1:
            break
        ious = iou_xywh(np.concatenate([boxes[i:i + 1], boxes[order[1:]]], 0))[0, 1:]
        order = order[1:][ious <= iou_thresh]
    return np.array(keep, dtype=np.int64)


def yolov5n_nms(detections: np.ndarray, conf_thresh: float = 0.25,
                iou_thresh: float = 0.45) -> np.ndarray:
    """Filter by conf and run NMS.  Input: [N, 6] (cx,cy,w,h,score,class)."""
    mask = detections[:, 4] >= conf_thresh
    d = detections[mask]
    if d.size == 0:
        return d
    keep = nms(d[:, :4], d[:, 4], iou_thresh)
    return d[keep]


# ---- CLI ----
def main():
    import argparse
    ap = argparse.ArgumentParser(description="post-process FPGA output")
    ap.add_argument("--network", required=True, choices=["yolov5n", "resnet18"])
    ap.add_argument("--config", default=None,
                    help="optional configs/<net>.yaml override")
    ap.add_argument("--input", required=True, help="FP32 raw output from hw_runner")
    ap.add_argument("--shape", nargs="+", type=int, required=True,
                    help="logical output shape, e.g. --shape 1 6300 8 or --shape 1 1000")
    ap.add_argument("--top-k", type=int, default=5)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--iou", type=float, default=0.45)
    args = ap.parse_args()

    raw = np.fromfile(args.input, dtype=np.float32).reshape(args.shape)

    if args.network == "resnet18":
        results = resnet18_topk(raw, top_k=args.top_k)
        for cls, p, name in results:
            print(f"  class {cls:4d}  {p*100:6.2f}%  {name}")
        return

    if args.network == "yolov5n":
        # raw shape: [1, 6300, 8] (cx, cy, w, h, obj, class0..2)
        # 6300 = 3 anchors × (40^2 + 20^2 + 10^2) wait actually 6300 = 3 × (40*40 + 20*20 + 10*10)
        # = 3 × (1600+400+100) = 6300.  Strides: 8, 16, 32 for the three heads.
        # The compiled hardware outputs concatenated FP32 logits; assume the
        # detections are already decoded (Mul/Add nodes done elsewhere) and
        # we just need NMS.
        dets = raw.reshape(-1, raw.shape[-1])
        # treat last dim 5..7 as class scores
        scores = dets[:, 4]
        cls_id = dets[:, 5:].argmax(axis=-1).astype(np.float32)
        merged = np.concatenate([dets[:, :4], scores[:, None], cls_id[:, None]], -1)
        kept = yolov5n_nms(merged, args.conf, args.iou)
        print(f"  detections: {len(kept)}")
        for d in kept:
            print(f"    cx={d[0]:.1f} cy={d[1]:.1f} w={d[2]:.1f} h={d[3]:.1f} "
                  f"score={d[4]:.3f} class={int(d[5])}")


if __name__ == "__main__":
    main()
