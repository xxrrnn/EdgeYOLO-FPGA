"""
pytorch_detect.py - 使用 PyTorch QAT 模型进行推理，对比 FPGA/Golden 结果

用法：
  python pytorch_detect.py --images <path> --max 5 --conf 0.15
"""
from __future__ import annotations
import sys, time, argparse
from pathlib import Path
import numpy as np
import torch

_THIS = Path(__file__).resolve().parent
REPO_ROOT = _THIS.parents[2]

# Add quantized-yolov5 to path
QAT_ROOT = REPO_ROOT / "model" / "algorithm" / "quantized-yolov5"
sys.path.insert(0, str(QAT_ROOT))
sys.path.insert(0, str(QAT_ROOT / "models"))

from models.yolo import Model

WEIGHTS_PATH = QAT_ROOT / "runs" / "train" / "infrared_qat_int8" / "weights" / "best.pt"
MODEL_YAML = str(QAT_ROOT / "models" / "yolov5n-quant-infrared-int8.yaml")
IMG_SIZE = 320
CLASS_NAMES = ['person', 'car', 'bicycle']
COLORS = [(0, 255, 0), (255, 0, 0), (0, 0, 255)]


def letterbox(img, new_shape=(320, 320), color=(114, 114, 114)):
    """Resize and pad image to target shape."""
    shape = img.shape[:2]  # H, W
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
    new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
    dw = (new_shape[1] - new_unpad[0]) / 2
    dh = (new_shape[0] - new_unpad[1]) / 2

    from PIL import Image
    pil_img = Image.fromarray(img)
    pil_img = pil_img.resize(new_unpad, Image.BILINEAR)
    img_resized = np.array(pil_img)

    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    img_padded = np.full((new_shape[0], new_shape[1], 3), color[0], dtype=np.uint8)
    img_padded[top:top + img_resized.shape[0], left:left + img_resized.shape[1]] = img_resized

    return img_padded, r, (dw, dh)


def xywh2xyxy(x):
    y = x.clone()
    y[:, 0] = x[:, 0] - x[:, 2] / 2
    y[:, 1] = x[:, 1] - x[:, 3] / 2
    y[:, 2] = x[:, 0] + x[:, 2] / 2
    y[:, 3] = x[:, 1] + x[:, 3] / 2
    return y


def nms(boxes, scores, iou_thres):
    """Simple NMS."""
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
        w = np.maximum(0, xx2 - xx1)
        h = np.maximum(0, yy2 - yy1)
        inter = w * h
        iou = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        inds = np.where(iou <= iou_thres)[0]
        order = order[inds + 1]
    return keep


def postprocess(pred, conf_thres=0.15, iou_thres=0.45):
    """Post-process model output to detections."""
    pred = pred.cpu().numpy()
    if pred.ndim == 3:
        pred = pred[0]  # (N, 8) for 3 classes: x,y,w,h,obj,c0,c1,c2

    # obj conf filter
    obj_conf = pred[:, 4]
    mask = obj_conf > conf_thres
    pred = pred[mask]
    if len(pred) == 0:
        return np.zeros((0, 7))

    # class scores
    cls_scores = pred[:, 5:] * pred[:, 4:5]
    cls_id = cls_scores.argmax(axis=1)
    cls_conf = cls_scores[np.arange(len(cls_scores)), cls_id]

    # conf filter
    mask2 = cls_conf > conf_thres
    pred = pred[mask2]
    cls_id = cls_id[mask2]
    cls_conf = cls_conf[mask2]

    if len(pred) == 0:
        return np.zeros((0, 7))

    # xywh -> xyxy
    boxes = pred[:, :4].copy()
    boxes_xyxy = np.zeros_like(boxes)
    boxes_xyxy[:, 0] = boxes[:, 0] - boxes[:, 2] / 2
    boxes_xyxy[:, 1] = boxes[:, 1] - boxes[:, 3] / 2
    boxes_xyxy[:, 2] = boxes[:, 0] + boxes[:, 2] / 2
    boxes_xyxy[:, 3] = boxes[:, 1] + boxes[:, 3] / 2

    # NMS per class
    results = []
    for c in range(len(CLASS_NAMES)):
        c_mask = cls_id == c
        if not c_mask.any():
            continue
        c_boxes = boxes_xyxy[c_mask]
        c_scores = cls_conf[c_mask]
        keep = nms(c_boxes, c_scores, iou_thres)
        for k in keep:
            results.append([*c_boxes[k], c_scores[k], c_scores[k], c])

    if not results:
        return np.zeros((0, 7))
    return np.array(results)


def draw_boxes(img, detections):
    from PIL import Image, ImageDraw, ImageFont
    pil_img = Image.fromarray(img.copy())
    draw = ImageDraw.Draw(pil_img)
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for det in detections:
        x1, y1, x2, y2, conf, _, cls_id = det[:7]
        cls_id = int(cls_id)
        color = COLORS[cls_id % len(COLORS)]
        label = f"{CLASS_NAMES[cls_id]} {conf:.2f}"
        draw.rectangle([x1, y1, x2, y2], outline=color, width=2)
        tw = draw.textlength(label, font=font) if hasattr(draw, 'textlength') else len(label) * 7
        draw.rectangle([x1, y1 - 14, x1 + tw + 4, y1], fill=color)
        draw.text((x1 + 2, y1 - 13), label, fill=(255, 255, 255), font=font)
    return np.array(pil_img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", type=str, required=True)
    ap.add_argument("--max", type=int, default=5)
    ap.add_argument("--conf", type=float, default=0.15)
    ap.add_argument("--iou", type=float, default=0.45)
    args = ap.parse_args()

    out_dir = _THIS / "runs" / "e2e" / "pytorch"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\nLoading QAT model from {WEIGHTS_PATH.name}...")
    print(f"  YAML: {MODEL_YAML}")

    # Build model from yaml and load state_dict
    model = Model(MODEL_YAML, ch=3, nc=len(CLASS_NAMES))
    state_dict = torch.load(str(WEIGHTS_PATH), map_location='cpu')
    
    # Handle different checkpoint formats
    if isinstance(state_dict, dict) and 'model' in state_dict:
        state_dict = state_dict['model'].state_dict() if hasattr(state_dict['model'], 'state_dict') else state_dict['model']

    model.load_state_dict(state_dict, strict=False)
    model.eval()
    model.float()

    # Collect images
    img_dir = Path(args.images)
    if img_dir.is_file():
        img_paths = [img_dir]
    else:
        img_paths = sorted(img_dir.glob("*.jpg"))[:args.max]
        img_paths += sorted(img_dir.glob("*.png"))[:max(0, args.max - len(img_paths))]
        img_paths = img_paths[:args.max]

    print(f"\n{'='*70}")
    print(f"  PyTorch QAT Inference")
    print(f"  Images: {len(img_paths)}, conf>{args.conf}, iou>{args.iou}")
    print(f"  Output: {out_dir}")
    print(f"{'='*70}\n")

    total_dets = 0
    for idx, img_path in enumerate(img_paths):
        print(f"[{idx+1}/{len(img_paths)}] {img_path.name}...", end=" ", flush=True)

        from PIL import Image
        img_rgb = np.array(Image.open(str(img_path)).convert('RGB'))
        orig_shape = img_rgb.shape[:2]

        img_letterbox, ratio, (dw, dh) = letterbox(img_rgb, (IMG_SIZE, IMG_SIZE))

        # Normalize to [0,1] and convert to NCHW tensor
        img_tensor = torch.from_numpy(img_letterbox).float().permute(2, 0, 1).unsqueeze(0) / 255.0

        with torch.no_grad():
            pred = model(img_tensor)

        # pred might be a tuple
        if isinstance(pred, (list, tuple)):
            pred = pred[0]

        detections = postprocess(pred, conf_thres=args.conf, iou_thres=args.iou)

        # Scale back to original
        if len(detections) > 0:
            detections[:, [0, 2]] = (detections[:, [0, 2]] - dw) / ratio
            detections[:, [1, 3]] = (detections[:, [1, 3]] - dh) / ratio
            detections[:, [0, 2]] = np.clip(detections[:, [0, 2]], 0, orig_shape[1])
            detections[:, [1, 3]] = np.clip(detections[:, [1, 3]], 0, orig_shape[0])

        img_out = draw_boxes(img_rgb, detections)
        Image.fromarray(img_out).save(str(out_dir / f"{img_path.stem}_det.jpg"), quality=90)

        print(f"{len(detections)} detections")
        total_dets += len(detections)

    print(f"\n{'='*70}")
    print(f"  Total: {len(img_paths)} images, {total_dets} detections")
    print(f"  Output: {out_dir}")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()
