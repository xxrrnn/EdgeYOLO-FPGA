"""
YOLOv5n 检测头 (model.24) — Host 端实现

检测头在 host CPU 上执行（非 FPGA），接收 backbone+neck 的 INT8 输出，
执行 3 个 1×1 Conv（无 ReLU、无再量化），输出 FP32 预测结果。

输出格式 (每个尺度)：
  shape = (H, W, num_anchors, num_classes + 5)
  = (H, W, 3, 8)  # 3 anchors × (4 bbox + 1 obj + 3 classes)

用法：
    from detect_head import DetectHead
    head = DetectHead('model/yolov5n/parsed/weights')
    raw_preds = head.forward(feat_p3, feat_p4, feat_p5)
    boxes = head.postprocess(raw_preds, conf_thres=0.25, iou_thres=0.45)
"""
import numpy as np
from pathlib import Path
from typing import List, Tuple

# YOLOv5n-320 anchors (pre-defined, 3 scales × 3 anchors × 2)
# From the model config (typically in yaml)
ANCHORS = np.array([
    # P3/8 (40×40)
    [[10, 13], [16, 30], [33, 23]],
    # P4/16 (20×20)
    [[30, 61], [62, 45], [59, 119]],
    # P5/32 (10×10)
    [[116, 90], [156, 198], [373, 326]],
], dtype=np.float32)

STRIDES = np.array([8, 16, 32], dtype=np.float32)
NUM_CLASSES = 3
NUM_ANCHORS = 3


class DetectHead:
    """YOLOv5 Detect Head — host (CPU) implementation."""

    def __init__(self, weights_dir: str):
        wdir = Path(weights_dir)

        # Load network config to get the detect head input act_scale.
        # The correct act_scale is the output activation scale of model.17/20/23
        # cv3.conv (the layers feeding into detect head), stored in network.json.
        # NOTE: the 'act_scale' field inside model_24_m_*.npz is the DCIM hard-quant
        # scale (1/127 ≈ 0.007874), NOT the backbone activation scale — do NOT use it.
        import json
        net_json = wdir.parent / 'network.json'
        if net_json.exists():
            net_cfg = json.load(open(str(net_json)))
            self.num_classes = int(net_cfg.get("num_classes", NUM_CLASSES))
            layers_dict = {l["name"]: l for l in net_cfg.get("layers", [])}
            feed_layers = ["model.17.cv3.conv", "model.20.cv3.conv", "model.23.cv3.conv"]
            # Each scale corresponds to P3, P4, P5 respectively
            det_scales = [layers_dict[l]["act_scale"] for l in feed_layers if l in layers_dict]
        else:
            self.num_classes = NUM_CLASSES
            det_scales = []
        self.out_channels = NUM_ANCHORS * (self.num_classes + 5)

        # Fallback default (INT8 QONNX scale for yolov5n)
        default_scale = 0.07814328372478485

        self.convs = []
        for i in range(3):
            npz = np.load(wdir / f'model_24_m_{i}.npz')
            # Use the network.json-derived per-scale (accurate backbone output scale).
            # Do NOT use npz['act_scale']: it stores the DCIM hard-quant scale (≈1/127).
            act_scale = det_scales[i] if i < len(det_scales) else default_scale
            if 'weight_fp32' in npz:
                self.convs.append({
                    'weight_fp32': npz['weight_fp32'],   # (out_channels, Cin, 1, 1)
                    'bias': npz['bias'],                 # (out_channels,)
                    'act_scale': act_scale,
                })
            else:
                self.convs.append({
                    'weight_fp32': npz['weight_int8'].astype(np.float32),
                    'bias': npz['dqa_bias'],
                    'act_scale': act_scale,
                })
        self.det_act_scale = self.convs[0]['act_scale']  # for backwards compatibility

    def _conv1x1_dqa(self, feat_int8: np.ndarray, conv_idx: int) -> np.ndarray:
        """1×1 Conv (FP32 weights) on INT8 input → FP32 output.

        feat_int8: (H, W, Cin) INT8
        Returns: (H, W, out_channels) FP32
        """
        h, w, cin = feat_int8.shape
        c = self.convs[conv_idx]
        weight = c['weight_fp32']  # (out_channels, Cin, 1, 1) FP32
        bias = c['bias']           # (out_channels,) FP32
        act_scale = c['act_scale']

        # Dequantize input: FP32 = INT8 * act_scale
        # act_scale is the QONNX scale (0.07814), NOT hard_quant_scale (0.007874)
        feat_fp32 = feat_int8.reshape(-1, cin).astype(np.float32) * act_scale  # (H*W, Cin)
        w_flat = weight.reshape(self.out_channels, cin).astype(np.float32)

        # FP32 matmul
        out_fp32 = feat_fp32 @ w_flat.T + bias[None, :]  # (H*W, 24)
        return out_fp32.reshape(h, w, self.out_channels)

    def forward(self, feat_p3: np.ndarray, feat_p4: np.ndarray, feat_p5: np.ndarray) -> List[np.ndarray]:
        """Run detection head on 3 feature maps.

        feat_p3: (40, 40, 64) INT8  ← model.17 output
        feat_p4: (20, 20, 128) INT8 ← model.20 output
        feat_p5: (10, 10, 256) INT8 ← model.23 output

        Returns: list of 3 raw predictions, each (H, W, 3, 8) FP32
        """
        feats = [feat_p3, feat_p4, feat_p5]
        preds = []
        for i, feat in enumerate(feats):
            raw = self._conv1x1_dqa(feat, i)  # (H, W, out_channels)
            h, w, _ = raw.shape
            pred = raw.reshape(h, w, NUM_ANCHORS, self.num_classes + 5)
            preds.append(pred)
        return preds

    def decode(self, preds: List[np.ndarray], img_size: int = 320) -> np.ndarray:
        """Decode raw predictions to absolute bbox coordinates.

        Returns: (N_total, 8) array of [x1, y1, x2, y2, obj_conf, cls0, cls1, cls2]
                 where coordinates are in pixel space [0, img_size].
        """
        all_boxes = []
        for scale_idx, pred in enumerate(preds):
            h, w, na, nc5 = pred.shape
            stride = STRIDES[scale_idx]
            anchors = ANCHORS[scale_idx]  # (3, 2)

            # Grid
            gy, gx = np.meshgrid(np.arange(h), np.arange(w), indexing='ij')
            grid = np.stack([gx, gy], axis=-1).astype(np.float32)  # (H, W, 2)

            # Decode bbox (sigmoid for xy, exp for wh)
            xy = _sigmoid(pred[..., :2]) * 2 - 0.5  # (H, W, 3, 2)
            wh = (_sigmoid(pred[..., 2:4]) * 2) ** 2  # (H, W, 3, 2)

            # Add grid offset and scale
            xy = (xy + grid[:, :, None, :]) * stride  # absolute pixels
            wh = wh * anchors[None, None, :, :]       # absolute pixels

            # Convert to x1y1x2y2
            x1y1 = xy - wh / 2
            x2y2 = xy + wh / 2

            # Objectness and class scores
            obj = _sigmoid(pred[..., 4:5])       # (H, W, 3, 1)
            cls = _sigmoid(pred[..., 5:])        # (H, W, 3, nc)

            # Flatten
            n = h * w * na
            boxes = np.concatenate([
                x1y1.reshape(n, 2),
                x2y2.reshape(n, 2),
                obj.reshape(n, 1),
                cls.reshape(n, self.num_classes),
            ], axis=-1)  # (n, 4+1+nc)
            all_boxes.append(boxes)

        return np.concatenate(all_boxes, axis=0)  # (6300, 4+1+3)

    def postprocess(self, preds: List[np.ndarray], conf_thres: float = 0.25,
                    iou_thres: float = 0.45, img_size: int = 320) -> np.ndarray:
        """Full post-processing: decode + filter + NMS.

        Returns: (M, 7) array of [x1, y1, x2, y2, confidence, class_score, class_id]
        """
        decoded = self.decode(preds, img_size)  # (6300, 8)

        # Filter by objectness
        obj_scores = decoded[:, 4]
        mask = obj_scores > conf_thres
        candidates = decoded[mask]

        if len(candidates) == 0:
            return np.zeros((0, 7), dtype=np.float32)

        # Multiply obj × cls for final confidence
        cls_scores = candidates[:, 5:] * candidates[:, 4:5]  # (M, nc)
        class_ids = cls_scores.argmax(axis=1)
        class_confs = cls_scores[np.arange(len(cls_scores)), class_ids]

        # Filter by class confidence
        mask2 = class_confs > conf_thres
        candidates = candidates[mask2]
        class_ids = class_ids[mask2]
        class_confs = class_confs[mask2]

        if len(candidates) == 0:
            return np.zeros((0, 7), dtype=np.float32)

        # NMS per class
        boxes = candidates[:, :4]
        results = []
        for cls_id in range(self.num_classes):
            cls_mask = class_ids == cls_id
            if not cls_mask.any():
                continue
            cls_boxes = boxes[cls_mask]
            cls_conf = class_confs[cls_mask]
            keep = _nms(cls_boxes, cls_conf, iou_thres)
            for idx in keep:
                results.append(np.concatenate([
                    cls_boxes[idx],
                    [cls_conf[idx], cls_conf[idx], cls_id]
                ]))

        if not results:
            return np.zeros((0, 7), dtype=np.float32)
        return np.array(results, dtype=np.float32)


def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -50, 50)))


def _nms(boxes: np.ndarray, scores: np.ndarray, iou_thres: float) -> List[int]:
    """Simple NMS implementation."""
    x1 = boxes[:, 0]
    y1 = boxes[:, 1]
    x2 = boxes[:, 2]
    y2 = boxes[:, 3]
    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]
    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(i)
        if order.size == 1:
            break
        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])
        inter = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        iou = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        inds = np.where(iou <= iou_thres)[0]
        order = order[inds + 1]
    return keep
