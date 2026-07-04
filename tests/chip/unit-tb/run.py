"""
run.py - YOLOv5n / ResNet18 端到端推理 (真实图片)

流程:
    YOLOv5n: 图片 → letterbox(320×320) → /255 → QA(INT8) → FPGA backbone+neck → detect_head → NMS → boxes
    ResNet18: 图片 → resize(224×224) → normalize → QA(INT8) → FPGA 20 conv → GAP → FC → class

用法:
    # 单张图片推理 (dry-run)
    python run.py yolov5n --image path/to/image.jpg --dry-run

    # 批量验证集
    python run.py yolov5n --val-dir path/to/images/ --dry-run --max-images 5

    # FPGA 执行
    python run.py yolov5n --image path/to/image.jpg

    # ResNet18
    python run.py resnet18 --image path/to/image.jpg --dry-run
"""
from __future__ import annotations
import argparse, sys, time
from pathlib import Path
import numpy as np

_THIS = Path(__file__).resolve()
sys.path.insert(0, str(_THIS.parent))
sys.path.insert(0, str(_THIS.parents[3] / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(_THIS.parents[3] / "tools"))

RUNS_BASE = _THIS.parent / "runs" / "e2e"
IMG_SIZE_YOLO = 320
IMG_SIZE_RESNET = 224

# 重新 QAT 后 act_scale 会变化，从 parsed/network.json 读取第一层 act_scale
_YOLO_PARSED = _THIS.parents[3] / "model" / "yolov5n" / "parsed" / "network.json"
def _load_act_scale() -> float:
    """从 parsed network.json 读取 input_act_scale (用于量化输入图像)"""
    import json
    if _YOLO_PARSED.exists():
        with open(_YOLO_PARSED) as f:
            net = json.load(f)
        return net.get("input_act_scale", net["layers"][0]["act_scale"])
    return 0.007874  # 1/127 (signed Int8)

ACT_SCALE = _load_act_scale()


# ═══════════════════════════════════════════════════════════════════════════════
#  前处理
# ═══════════════════════════════════════════════════════════════════════════════

def load_image(path: str) -> np.ndarray:
    """读取图片为 RGB uint8 (H, W, 3)"""
    from PIL import Image
    img = Image.open(path).convert("RGB")
    return np.array(img)


def letterbox(img: np.ndarray, new_shape: int = 320, color: int = 114) -> tuple:
    """YOLOv5 letterbox: resize + pad 到正方形, 保持比例。

    Returns: (padded_img, ratio, (dw, dh))
        padded_img: uint8 (new_shape, new_shape, 3)
        ratio: scale factor
        (dw, dh): padding offsets (for coordinate mapping back)
    """
    h, w = img.shape[:2]
    r = min(new_shape / h, new_shape / w)
    new_h, new_w = int(round(h * r)), int(round(w * r))

    # resize using PIL (nearest or bilinear)
    from PIL import Image
    pil_img = Image.fromarray(img)
    pil_img = pil_img.resize((new_w, new_h), Image.BILINEAR)
    resized = np.array(pil_img)

    # pad to new_shape × new_shape
    dh = new_shape - new_h
    dw = new_shape - new_w
    top, left = dh // 2, dw // 2
    bottom, right = dh - top, dw - left

    padded = np.full((new_shape, new_shape, 3), color, dtype=np.uint8)
    padded[top:top+new_h, left:left+new_w, :] = resized

    return padded, r, (left, top)


def preprocess_yolov5n(img_rgb: np.ndarray) -> tuple:
    """YOLOv5n 前处理: letterbox → /255 → QA(INT8)

    Returns: (int8_input (320,320,3), ratio, (dw,dh), original_shape)
    """
    orig_shape = img_rgb.shape[:2]  # (H, W)
    padded, ratio, (dw, dh) = letterbox(img_rgb, IMG_SIZE_YOLO)

    # float32 归一化 [0, 1]
    fp32 = padded.astype(np.float32) / 255.0

    # 量化到 INT8 (signed): int8 = clip(round(fp32 / act_scale), -128, 127)
    # 对于 /255 后 [0,1] 的输入，量化后范围约 [0, 21]（signed 模式下 max_val≈6/127≈0.047）
    int8_input = np.clip(np.round(fp32 / ACT_SCALE), -128, 127).astype(np.int8)

    return int8_input, ratio, (dw, dh), orig_shape


def preprocess_resnet18(img_rgb: np.ndarray) -> np.ndarray:
    """ResNet18 前处理: resize(224) → ImageNet normalize → QA(INT8)"""
    from PIL import Image
    pil_img = Image.fromarray(img_rgb)
    pil_img = pil_img.resize((IMG_SIZE_RESNET, IMG_SIZE_RESNET), Image.BILINEAR)
    arr = np.array(pil_img).astype(np.float32) / 255.0

    # ImageNet normalization
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    normalized = (arr - mean) / std

    # QA: 需要 ResNet18 的 input act_scale
    # 从 parsed weights 获取
    weights_dir = _THIS.parents[3] / "model" / "resnet18" / "parsed" / "weights"
    npz = np.load(weights_dir / "conv1.npz")
    # input scale 通常在第一层的输入定义中
    # 对于ResNet18 W8A8, 假设输入 scale 使 [-128,127] 覆盖归一化后的范围
    # normalized range: roughly [-2.2, 2.7] (ImageNet stats)
    # 一个常见的 input_scale 是 max_abs/127 ≈ 2.7/127 ≈ 0.0213
    input_scale = 2.64 / 127.0  # 覆盖 normalized 范围
    int8_input = np.clip(np.round(normalized / input_scale), -128, 127).astype(np.int8)
    return int8_input


# ═══════════════════════════════════════════════════════════════════════════════
#  YOLOv5n 推理
# ═══════════════════════════════════════════════════════════════════════════════

def run_yolov5n_inference(runner, img_path: str, dry_run: bool):
    """单张图片 YOLOv5n 端到端推理"""
    from ops import FPGAOps, HostOps, C3Block, conv_meta, _net
    from detect_head import DetectHead
    from golden_module_tb import out_hw as _out_hw

    # 前处理
    img_rgb = load_image(img_path)
    int8_input, ratio, (dw, dh), orig_shape = preprocess_yolov5n(img_rgb)
    print(f"  Input: {img_path}")
    print(f"  Original: {orig_shape}, Letterbox: {int8_input.shape}")
    print(f"  INT8 range: [{int8_input.min()}, {int8_input.max()}], mean={int8_input.mean():.1f}")

    # FPGA backbone + neck
    fpga = FPGAOps(runner=None if dry_run else runner,
                   runs_base=str(RUNS_BASE / "yolov5n"), verbose=False)
    host = HostOps()

    def _conv(name, feat, case):
        m = conv_meta(_net(), name)
        h, w, _ = feat.shape
        oh, ow = _out_hw(h, w, m)
        ibuf_act = 4 * 512 * 16
        max_pix = max(1, ibuf_act // (m.acc_depth * 16))
        if m.out_ch > 128:
            return fpga.conv_tiled(feat, name, case_name=case)
        elif oh * ow > max_pix:
            return fpga.conv_oh_tiled(feat, name, case_name=case, max_pixels=max_pix)
        else:
            return fpga.conv(feat, name, case_name=case)

    def _c3(mid, feat, n):
        return C3Block(fpga, host, mid, n_bottleneck=n)(feat)

    print("  Running backbone+neck...")
    x = int8_input
    x = _conv("model.0.conv", x, "e2e_0")
    x = _conv("model.1.conv", x, "e2e_1")
    x = _c3("2", x, 1)
    x = _conv("model.3.conv", x, "e2e_3")
    x = _c3("4", x, 2)
    x4 = x
    x = _conv("model.5.conv", x, "e2e_5")
    x = _c3("6", x, 3)
    x6 = x
    x = _conv("model.7.conv", x, "e2e_7")
    x = _c3("8", x, 1)
    x8 = x

    cv1 = _conv("model.9.cv1.conv", x8, "e2e_9cv1")
    mp1 = host.maxpool(cv1, k=5)
    mp2 = host.maxpool(mp1, k=5)
    mp3 = host.maxpool(mp2, k=5)
    sppf_cat = host.concat([cv1, mp1, mp2, mp3])
    x9 = _conv("model.9.cv2.conv", sppf_cat, "e2e_9cv2")
    x10 = _conv("model.10.conv", x9, "e2e_10")

    cat_6 = host.concat([host.upsample(x10, 2), x6])
    x13 = _c3("13", cat_6, 1)
    x14 = _conv("model.14.conv", x13, "e2e_14")
    cat_4 = host.concat([host.upsample(x14, 2), x4])
    x17 = _c3("17", cat_4, 1)

    # hard_quant rescale: C3 output (scale=act_scale) -> Div/2 -> requant (scale=hard_quant_scale)
    import json as _json
    _net_cfg = _json.load(open(_YOLO_PARSED))
    _hq_scale = _net_cfg.get('hard_quant_scale', 0.007874015718698502)
    _act_s = _net_cfg['layers'][0]['act_scale']
    x17_hq = host.hard_quant(x17, _act_s, _hq_scale)

    x18 = _conv("model.18.conv", x17_hq, "e2e_18")
    x20 = _c3("20", host.concat([x18, x13]), 1)
    x20_hq = host.hard_quant(x20, _act_s, _hq_scale)
    x21 = _conv("model.21.conv", x20_hq, "e2e_21")
    x23 = _c3("23", host.concat([x21, x8]), 1)
    x23_hq = host.hard_quant(x23, _act_s, _hq_scale)

    # 后处理: detect head (receives hard_quant'd features)
    print("  Running detect head...")
    weights_dir = str(_THIS.parents[3] / "model" / "yolov5n" / "parsed" / "weights")
    head = DetectHead(weights_dir)
    raw_preds = head.forward(x17_hq, x20_hq, x23_hq)

    # Decode + NMS
    print("  Decoding + NMS...")
    detections = postprocess_yolov5n(raw_preds, ratio, dw, dh, orig_shape)

    # 输出结果
    print(f"\n  Detections: {len(detections)} objects")
    for i, det in enumerate(detections[:20]):
        x1, y1, x2, y2, conf, cls = det
        print(f"    [{i}] class={int(cls)}, conf={conf:.3f}, box=[{x1:.0f},{y1:.0f},{x2:.0f},{y2:.0f}]")

    # Dump 中间激活统计
    dump_path = RUNS_BASE / "dumps" / f"inference_{Path(img_path).stem}.txt"
    dump_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dump_path, "w") as f:
        f.write(f"Image: {img_path}\n")
        f.write(f"Original shape: {orig_shape}\n")
        f.write(f"INT8 input: range=[{int8_input.min()},{int8_input.max()}], mean={int8_input.mean():.2f}\n\n")
        f.write(f"Backbone+Neck output scales:\n")
        for name, arr in [("x17", x17), ("x20", x20), ("x23", x23)]:
            f.write(f"  {name}: shape={arr.shape}, range=[{arr.min()},{arr.max()}], "
                    f"mean={arr.mean():.2f}, non-zero={np.count_nonzero(arr)}/{arr.size}\n")
        f.write(f"\nDetections ({len(detections)}):\n")
        for det in detections:
            x1, y1, x2, y2, conf, cls = det
            f.write(f"  class={int(cls)}, conf={conf:.3f}, box=[{x1:.0f},{y1:.0f},{x2:.0f},{y2:.0f}]\n")
    print(f"  Dump: {dump_path}")
    return detections


def postprocess_yolov5n(raw_preds, ratio, dw, dh, orig_shape, conf_thres=0.25, iou_thres=0.45):
    """YOLOv5 后处理: decode boxes + NMS"""
    # raw_preds: list of 3 arrays, each (H, W, 3, 8) where 8 = [x,y,w,h,obj,cls0,cls1,cls2]
    # 对于红外数据集: nc=3 (person, bicycle, car) 或 nc=2 看模型
    # detect_head.py 已输出 decoded boxes

    all_boxes = []
    anchors = [
        [[10,13], [16,30], [33,23]],      # P3/8
        [[30,61], [62,45], [59,119]],      # P4/16
        [[116,90], [156,198], [373,326]],  # P5/32
    ]
    strides = [8, 16, 32]

    for si, pred in enumerate(raw_preds):
        h, w, na, no = pred.shape  # na=3 anchors, no=5+nc
        nc = no - 5

        for ay in range(h):
            for ax in range(w):
                for a in range(na):
                    box = pred[ay, ax, a]
                    obj_conf = sigmoid(box[4])
                    if obj_conf < conf_thres:
                        continue

                    # decode box
                    bx = (sigmoid(box[0]) * 2 - 0.5 + ax) * strides[si]
                    by = (sigmoid(box[1]) * 2 - 0.5 + ay) * strides[si]
                    bw = (sigmoid(box[2]) * 2) ** 2 * anchors[si][a][0]
                    bh = (sigmoid(box[3]) * 2) ** 2 * anchors[si][a][1]

                    # center to xyxy
                    x1 = bx - bw / 2
                    y1 = by - bh / 2
                    x2 = bx + bw / 2
                    y2 = by + bh / 2

                    # class scores
                    cls_scores = np.array([sigmoid(box[5 + c]) for c in range(nc)])
                    cls_conf = cls_scores.max()
                    cls_id = cls_scores.argmax()

                    final_conf = obj_conf * cls_conf
                    if final_conf < conf_thres:
                        continue

                    all_boxes.append([x1, y1, x2, y2, final_conf, cls_id])

    if not all_boxes:
        return np.zeros((0, 6))

    boxes = np.array(all_boxes)

    # Scale coords back to original image
    boxes[:, [0, 2]] = (boxes[:, [0, 2]] - dw) / ratio
    boxes[:, [1, 3]] = (boxes[:, [1, 3]] - dh) / ratio

    # Clip to image
    boxes[:, [0, 2]] = np.clip(boxes[:, [0, 2]], 0, orig_shape[1])
    boxes[:, [1, 3]] = np.clip(boxes[:, [1, 3]], 0, orig_shape[0])

    # NMS
    keep = nms(boxes[:, :4], boxes[:, 4], iou_thres)
    return boxes[keep]


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -50, 50)))


def nms(boxes, scores, iou_thres):
    """Simple NMS"""
    x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
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


# ═══════════════════════════════════════════════════════════════════════════════
#  ResNet18 推理
# ═══════════════════════════════════════════════════════════════════════════════

def run_resnet18_inference(runner, img_path: str, dry_run: bool):
    """单张图片 ResNet18 分类推理"""
    img_rgb = load_image(img_path)
    int8_input = preprocess_resnet18(img_rgb)
    print(f"  Input: {img_path}")
    print(f"  INT8 range: [{int8_input.min()}, {int8_input.max()}], mean={int8_input.mean():.1f}")

    # TODO: FPGA execution for ResNet18
    # For now, run numpy golden
    print("  Running ResNet18 (numpy golden)...")
    from _resnet18_test import conv_golden, maxpool_3x3, residual_add, relu_int8

    x = int8_input
    x = conv_golden(x, 'conv1', has_relu=True)
    x = maxpool_3x3(x)

    identity = x
    x = conv_golden(x, 'layer1.0.conv1', has_relu=True)
    x = conv_golden(x, 'layer1.0.conv2', has_relu=False)
    x = relu_int8(residual_add(x, identity))
    identity = x
    x = conv_golden(x, 'layer1.1.conv1', has_relu=True)
    x = conv_golden(x, 'layer1.1.conv2', has_relu=False)
    x = relu_int8(residual_add(x, identity))

    identity = conv_golden(x, 'layer2.0.downsample.0', has_relu=False)
    x2 = conv_golden(x, 'layer2.0.conv1', has_relu=True)
    x2 = conv_golden(x2, 'layer2.0.conv2', has_relu=False)
    x = relu_int8(residual_add(x2, identity))
    identity = x
    x = conv_golden(x, 'layer2.1.conv1', has_relu=True)
    x = conv_golden(x, 'layer2.1.conv2', has_relu=False)
    x = relu_int8(residual_add(x, identity))

    identity = conv_golden(x, 'layer3.0.downsample.0', has_relu=False)
    x2 = conv_golden(x, 'layer3.0.conv1', has_relu=True)
    x2 = conv_golden(x2, 'layer3.0.conv2', has_relu=False)
    x = relu_int8(residual_add(x2, identity))
    identity = x
    x = conv_golden(x, 'layer3.1.conv1', has_relu=True)
    x = conv_golden(x, 'layer3.1.conv2', has_relu=False)
    x = relu_int8(residual_add(x, identity))

    identity = conv_golden(x, 'layer4.0.downsample.0', has_relu=False)
    x2 = conv_golden(x, 'layer4.0.conv1', has_relu=True)
    x2 = conv_golden(x2, 'layer4.0.conv2', has_relu=False)
    x = relu_int8(residual_add(x2, identity))
    identity = x
    x = conv_golden(x, 'layer4.1.conv1', has_relu=True)
    x = conv_golden(x, 'layer4.1.conv2', has_relu=False)
    x = relu_int8(residual_add(x, identity))

    # GAP
    gap = x.astype(np.float32).mean(axis=(0, 1))  # (512,)
    print(f"  Final feature: {x.shape}, GAP: {gap.shape}")
    print(f"  GAP range: [{gap.min():.2f}, {gap.max():.2f}]")
    print(f"  Top-5 GAP indices: {gap.argsort()[-5:][::-1].tolist()}")
    return gap


# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    ap = argparse.ArgumentParser(description="End-to-end FPGA inference")
    ap.add_argument("network", choices=["yolov5n", "resnet18"])
    ap.add_argument("--image", type=str, help="Single image path")
    ap.add_argument("--val-dir", type=str, help="Validation image directory")
    ap.add_argument("--max-images", type=int, default=5)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--conf-thres", type=float, default=0.25)
    args = ap.parse_args()

    RUNS_BASE.mkdir(parents=True, exist_ok=True)

    runner = None
    if not args.dry_run:
        from xdma_win import ChipRunnerWin
        runner = ChipRunnerWin()

    mode = "DRY-RUN" if args.dry_run else "FPGA"
    print(f"\n{'='*70}")
    print(f"  {args.network.upper()} End-to-End Inference [{mode}]")
    print(f"{'='*70}")

    # 收集图片
    images = []
    if args.image:
        images = [args.image]
    elif args.val_dir:
        from glob import glob
        images = sorted(glob(str(Path(args.val_dir) / "*.jpg")))[:args.max_images]
    else:
        # 默认使用验证集
        default_dir = _THIS.parents[3] / "model" / "algorithm" / "Infrared-Object-Detection" / "datasets" / "infrared" / "images" / "val"
        if default_dir.exists():
            images = sorted(str(p) for p in default_dir.glob("*.jpg"))[:args.max_images]

    if not images:
        print("  ERROR: no images found!")
        return

    print(f"  Images: {len(images)}")
    t0 = time.time()

    for img_path in images:
        print(f"\n{'─'*70}")
        if args.network == "yolov5n":
            run_yolov5n_inference(runner, img_path, args.dry_run)
        else:
            run_resnet18_inference(runner, img_path, args.dry_run)

    elapsed = time.time() - t0
    print(f"\n{'='*70}")
    print(f"  Done. {len(images)} images in {elapsed:.1f}s")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()
