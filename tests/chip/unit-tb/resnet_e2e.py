"""ResNet18 E2E runner for FPGA / dry-run.

The runner keeps ResNet-specific graph wiring out of the repository-level
``run.py`` entrypoint.  Conv layers are executed through ``FPGAOps`` so
``runner=None`` gives the same numpy golden dry-run behavior as YOLO.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
from typing import Iterable

import numpy as np

_THIS = Path(__file__).resolve().parent
REPO_ROOT = _THIS.parents[2]
sys.path.insert(0, str(_THIS))
sys.path.insert(0, str(REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb"))

import golden_module_tb
from ops import FPGAOps, HostOps, conv_meta, _net, set_network_json
from golden_module_tb import out_hw as _out_hw

RESNET_DIR = REPO_ROOT / "model" / "resnet18"
PARSED_VAI = RESNET_DIR / "parsed_vai"                   # Vitis AI quantized (INT8, correct model)
PARSED_VAI_INT16 = RESNET_DIR / "parsed_vai_int16_widened"  # VAI weights widened to int16 dtype
ONNX_VAI = (REPO_ROOT / "model" / "algorithm" / "Resnet18-quantization"
            / "resnet18" / "quantize_result" / "ResNet_int.onnx")
IMG_SIZE = 224
CLASS_NAMES = [f"class_{i}" for i in range(1000)]

def _load_class_names() -> list[str]:
    """Load ImageNet class names from JSON file."""
    global CLASS_NAMES
    label_path = RESNET_DIR / "imagenet_labels.json"
    if label_path.exists():
        import json as _json
        CLASS_NAMES = _json.loads(label_path.read_text())
    return CLASS_NAMES

_load_class_names()
_ADD_SCALE_CACHE: dict[str, float] | None = None
_OP_SCALE_CACHE: dict[str, dict[str, float]] = {}


def _safe_name(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def _weights_ready(parsed_dir: Path) -> bool:
    weights_dir = parsed_dir / "weights"
    return (parsed_dir / "network.json").exists() and weights_dir.exists() and any(weights_dir.glob("*.npz"))


def prepare_vai_int16() -> Path:
    """Create ResNet INT16 weights by widening VAI INT8 weights to int16 dtype.

    Numerically identical to VAI INT8; used to exercise the FPGA INT16 datapath.
    """
    if not _weights_ready(PARSED_VAI):
        raise FileNotFoundError(
            "ResNet VAI parsed weights are missing. Run:\n"
            "  python tests/chip/compiler/frontend/parse_resnet18_vai.py"
        )

    PARSED_VAI_INT16.mkdir(parents=True, exist_ok=True)
    (PARSED_VAI_INT16 / "weights").mkdir(parents=True, exist_ok=True)

    net = json.loads((PARSED_VAI / "network.json").read_text())
    net.setdefault("model_info", {}).setdefault("quantization", {})
    net["model_info"]["quantization"]["activation_bits"] = 16
    net["model_info"]["quantization"]["weight_bits"] = 16
    net["model_info"]["name"] = "resnet18-vai-int16-widened"
    net["int16_from_int8"] = True
    (PARSED_VAI_INT16 / "network.json").write_text(json.dumps(net, indent=2))

    src_pre = PARSED_VAI / "input_mean_std.json"
    if src_pre.exists():
        shutil.copyfile(src_pre, PARSED_VAI_INT16 / "input_mean_std.json")

    for src in (PARSED_VAI / "weights").glob("*.npz"):
        data = np.load(src)
        out = {}
        for key in data.files:
            arr = data[key]
            if key == "weight_int8":
                out[key] = arr.astype(np.int16)
            else:
                out[key] = arr
        np.savez_compressed(PARSED_VAI_INT16 / "weights" / src.name, **out)

    return PARSED_VAI_INT16


def configure_resnet_precision(precision: str) -> Path:
    if precision in ("vai", "int8_vai"):
        parsed = PARSED_VAI
        if not _weights_ready(parsed):
            raise FileNotFoundError(
                "ResNet VAI parsed weights not found. Run:\n"
                "  python tests/chip/compiler/frontend/parse_resnet18_vai.py"
            )
    elif precision == "int16":
        parsed = prepare_vai_int16()
    else:
        raise ValueError(f"unsupported ResNet precision: {precision!r}  (use 'vai' or 'int16')")

    if not _weights_ready(parsed):
        raise FileNotFoundError(f"ResNet parsed weights not found: {parsed / 'weights'}")

    set_network_json(str(parsed / "network.json"))
    return parsed


def load_image(path: str) -> np.ndarray:
    from PIL import Image

    return np.array(Image.open(path).convert("RGB"))


def preprocess_resnet18(img_rgb: np.ndarray, parsed_dir: Path) -> np.ndarray:
    """ImageNet preprocessing + quantization to int8/int16 input tensor."""
    from PIL import Image

    pre_path = parsed_dir / "input_mean_std.json"
    pre = json.loads(pre_path.read_text()) if pre_path.exists() else {
        "mean": [0.485, 0.456, 0.406],
        "std": [0.229, 0.224, 0.225],
        "resize": 256,
        "crop": 224,
    }

    pil = Image.fromarray(img_rgb)
    resize = int(pre.get("resize", 256))
    pil = pil.resize((resize, resize), Image.BILINEAR)
    left = max(0, (resize - IMG_SIZE) // 2)
    top = max(0, (resize - IMG_SIZE) // 2)
    pil = pil.crop((left, top, left + IMG_SIZE, top + IMG_SIZE))

    arr = np.array(pil).astype(np.float32) / 255.0
    mean = np.array(pre.get("mean", [0.485, 0.456, 0.406]), dtype=np.float32)
    std = np.array(pre.get("std", [0.229, 0.224, 0.225]), dtype=np.float32)
    normalized = (arr - mean) / std

    input_scale = _infer_input_scale(parsed_dir)
    # INT16-from-INT8: input is quantized with INT8 range [-128, 127] and cast to int16.
    # Clip range stays INT8 to keep numerical equivalence with INT8 mode.
    is_int16_from_int8 = "int16_from_int8" in parsed_dir.name
    is_int16 = "int16" in parsed_dir.name and not is_int16_from_int8
    if is_int16_from_int8:
        clip_lo, clip_hi = -128, 127
        dtype = np.int16
    elif is_int16:
        clip_lo, clip_hi = -32768, 32767
        dtype = np.int16
    else:
        clip_lo, clip_hi = -128, 127
        dtype = np.int8
    return np.clip(np.round(normalized / input_scale), clip_lo, clip_hi).astype(dtype)


def _infer_input_scale(parsed_dir: Path) -> float:
    """Infer first-layer activation scale from dqa_scale / weight_scale."""
    net = json.loads((parsed_dir / "network.json").read_text())
    first = next(layer["name"] for layer in net["layers"] if layer.get("type") == "conv")
    data = np.load(parsed_dir / "weights" / f"{_safe_name(first)}.npz")
    if "dqa_scale" in data.files and "weight_scale" in data.files:
        w_scale = np.array(data["weight_scale"]).reshape(-1)
        dqa = np.array(data["dqa_scale"]).reshape(-1)
        valid = np.abs(w_scale) > 1e-12
        if np.any(valid):
            return float(np.median(dqa[valid] / w_scale[valid]))
    # Covers ImageNet normalized range roughly [-2.2, 2.7].
    return 2.64 / 127.0


def _conv_auto(fpga: FPGAOps, layer_name: str, feat: np.ndarray, case_name: str) -> np.ndarray:
    from ops import _safe_int8_tile_size
    meta = conv_meta(_net(), layer_name)
    h, w, _ = feat.shape
    oh, ow = _out_hw(h, w, meta)
    ibuf_act = 4 * 512 * 16

    weight_path = Path(golden_module_tb.WEIGHT_DIR) / f"{_safe_name(layer_name)}.npz"
    is_int16 = np.load(weight_path)["weight_int8"].dtype == np.int16
    max_pix = max(1, ibuf_act // ((meta.acc_depth_int16 if is_int16 else meta.acc_depth) * 16))
    # INT16: 64ch max per tile (8 tiles × 8ch); INT8: respect hardware SRAM depth constraint
    if is_int16:
        tile_limit = 64
    else:
        tile_limit = _safe_int8_tile_size(meta.acc_depth)

    if meta.out_ch > tile_limit:
        out = fpga.conv_tiled(feat, layer_name, case_name=case_name, tile_size=tile_limit)
    elif oh * ow > max_pix:
        out = fpga.conv_oh_tiled(feat, layer_name, case_name=case_name, max_pixels=max_pix)
    else:
        out = fpga.conv(feat, layer_name, case_name=case_name)
    return _clip_int16_from_int8(out)


def _clip_int16_from_int8(feat: np.ndarray) -> np.ndarray:
    """ResNet INT16 mode is INT8 weights bit-extended to int16.

    To compare directly with the INT8/PT model, keep integer values in INT8
    range while storing them as int16 for the next FPGA INT16 layer.
    """
    if feat.dtype == np.int16:
        return np.clip(feat, -128, 127).astype(np.int16)
    return feat


def _layer_scale(parsed_dir: Path, layer_name: str) -> float:
    data = np.load(parsed_dir / "weights" / f"{_safe_name(layer_name)}.npz")
    return float(data["act_scale"]) if "act_scale" in data.files else 1.0


def _add_output_scales(parsed_dir: Path | None = None) -> dict[str, float]:
    """Load Add output scales from parsed_dir/add_output_scales.json, or fall back to ONNX."""
    global _ADD_SCALE_CACHE

    # Try parsed_dir JSON first (preferred; no ONNX needed)
    dirs_to_try = []
    if parsed_dir is not None:
        dirs_to_try.append(parsed_dir)
    dirs_to_try += [PARSED_VAI, PARSED_VAI_INT16]
    for d in dirs_to_try:
        sc_file = d / "add_output_scales.json"
        if sc_file.exists():
            return json.loads(sc_file.read_text())

    if _ADD_SCALE_CACHE is not None:
        return _ADD_SCALE_CACHE
    _ADD_SCALE_CACHE = {}
    onnx_path = ONNX_VAI if ONNX_VAI.exists() else ONNX_QDQ
    if not onnx_path.exists():
        return _ADD_SCALE_CACHE
    import onnx as _onnx

    model = _onnx.load(str(onnx_path))
    for node in model.graph.node:
        if node.op_type == "Add":
            name = node.name.strip("/").replace("/", ".")
            scale, _ = _find_output_quant_from_model(model, node.output[0])
            _ADD_SCALE_CACHE[name] = scale
    return _ADD_SCALE_CACHE


def _op_output_scales(op_type: str, parsed_dir: Path | None = None) -> dict[str, float]:
    if op_type in _OP_SCALE_CACHE:
        return _OP_SCALE_CACHE[op_type]
    scales: dict[str, float] = {}

    # For MaxPool: try network.json first
    if op_type == "MaxPool":
        dirs_to_try = ([parsed_dir] if parsed_dir else []) + [PARSED_VAI, PARSED_VAI_INT16]
        for d in dirs_to_try:
            net_file = d / "network.json"
            if net_file.exists():
                net = json.loads(net_file.read_text())
                mps = net.get("maxpool_output_scale")
                if mps is not None:
                    scales["maxpool.MaxPool"] = float(mps)
                    _OP_SCALE_CACHE[op_type] = scales
                    return scales

    onnx_path = ONNX_VAI if ONNX_VAI.exists() else ONNX_QDQ
    if not onnx_path.exists():
        _OP_SCALE_CACHE[op_type] = scales
        return scales
    import onnx as _onnx

    model = _onnx.load(str(onnx_path))
    for node in model.graph.node:
        if node.op_type == op_type:
            name = node.name.strip("/").replace("/", ".")
            scale, _ = _find_output_quant_from_model(model, node.output[0])
            scales[name] = scale
    _OP_SCALE_CACHE[op_type] = scales
    return scales


def _find_output_quant_from_model(model, tensor_name: str, depth: int = 0):
    if depth > 8:
        return 1.0, False
    for node in [n for n in model.graph.node if tensor_name in n.input]:
        if node.op_type == "QuantizeLinear":
            sc = _const_value(model, node.input[1])
            if sc is not None:
                return float(np.array(sc).flatten()[0]), False
        if node.op_type in {"Relu", "Cast", "DequantizeLinear", "Identity"}:
            scale, _ = _find_output_quant_from_model(model, node.output[0], depth + 1)
            if scale != 1.0:
                return scale, node.op_type == "Relu"
    return 1.0, False


def _residual_add_quant(a: np.ndarray, a_scale: float,
                        b: np.ndarray, b_scale: float,
                        out_scale: float) -> np.ndarray:
    fp32 = a.astype(np.float32) * float(a_scale) + b.astype(np.float32) * float(b_scale)
    fp32 = np.maximum(fp32, 0.0)
    is_int16 = a.dtype == np.int16 or b.dtype == np.int16
    dtype = np.int16 if is_int16 else np.int8
    # ResNet INT16 is INT8 widened; keep values numerically INT8-equivalent.
    return np.clip(np.round(fp32 / float(out_scale)), -128, 127).astype(dtype)


def maxpool_3x3_s2(feat: np.ndarray) -> np.ndarray:
    padded = np.pad(feat, ((1, 1), (1, 1), (0, 0)), mode="constant", constant_values=0)
    oh = (padded.shape[0] - 3) // 2 + 1
    ow = (padded.shape[1] - 3) // 2 + 1
    out = np.empty((oh, ow, feat.shape[2]), dtype=feat.dtype)
    for y in range(oh):
        for x in range(ow):
            out[y, x] = padded[y * 2:y * 2 + 3, x * 2:x * 2 + 3].max(axis=(0, 1))
    return out


def maxpool_3x3_s2_quant(feat: np.ndarray, in_scale: float, out_scale: float) -> np.ndarray:
    pooled = maxpool_3x3_s2(feat)
    if abs(float(in_scale) - float(out_scale)) < 1e-12:
        return pooled
    is_int16 = pooled.dtype == np.int16
    dtype = np.int16 if is_int16 else np.int8
    return np.clip(np.round(pooled.astype(np.float32) * float(in_scale) / float(out_scale)),
                   -128, 127).astype(dtype)


def _block(fpga: FPGAOps, parsed_dir: Path, x: np.ndarray, x_scale: float,
           prefix: str, case_prefix: str, downsample: str | None = None) -> tuple[np.ndarray, float]:
    if downsample is None:
        identity, identity_scale = x, x_scale
    else:
        identity = _conv_auto(fpga, downsample, x, f"{case_prefix}_down")
        identity_scale = _layer_scale(parsed_dir, downsample)

    conv1 = f"{prefix}.conv1.Conv"
    conv2 = f"{prefix}.conv2.Conv"
    y = _conv_auto(fpga, conv1, x, f"{case_prefix}_conv1")
    y = _conv_auto(fpga, conv2, y, f"{case_prefix}_conv2")

    add_name = f"{prefix}.Add"
    out_scale = _add_output_scales(parsed_dir).get(add_name, _layer_scale(parsed_dir, conv2))
    out = _residual_add_quant(y, _layer_scale(parsed_dir, conv2), identity, identity_scale, out_scale)
    return _clip_int16_from_int8(out), out_scale


def run_backbone(parsed_dir: Path, img_tensor: np.ndarray, runner, dry_run: bool,
                 runs_base: Path, verify: bool = True,
                 weight_hbm_map: "dict | None" = None) -> np.ndarray:
    fpga = FPGAOps(runner=None if dry_run else runner, runs_base=str(runs_base),
                   verbose=False, verify=verify, weight_hbm_map=weight_hbm_map)

    x = _conv_auto(fpga, "conv1.Conv", img_tensor, "resnet_conv1")
    x_scale = _layer_scale(parsed_dir, "conv1.Conv")
    pool_scale = _op_output_scales("MaxPool", parsed_dir).get("maxpool.MaxPool", x_scale)
    x = maxpool_3x3_s2_quant(x, x_scale, pool_scale)
    x_scale = pool_scale
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer1.0", "resnet_l10")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer1.1", "resnet_l11")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer2.0", "resnet_l20", downsample="layer2.0.downsample.0.Conv")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer2.1", "resnet_l21")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer3.0", "resnet_l30", downsample="layer3.0.downsample.0.Conv")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer3.1", "resnet_l31")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer4.0", "resnet_l40", downsample="layer4.0.downsample.0.Conv")
    x, x_scale = _block(fpga, parsed_dir, x, x_scale, "layer4.1", "resnet_l41")
    return x


def _last_act_scale(parsed_dir: Path) -> float:
    """Get the scale of the final backbone output (after last Add+ReLU)."""
    scales = _add_output_scales(parsed_dir)
    last_add = "layer4.1.Add"
    if last_add in scales:
        return scales[last_add]
    data = np.load(parsed_dir / "weights" / "layer4_1_conv2_Conv.npz")
    return float(data["act_scale"]) if "act_scale" in data.files else 1.0


def _const_value(model, name: str):
    from onnx import numpy_helper

    for init in model.graph.initializer:
        if init.name == name:
            return numpy_helper.to_array(init)
    for node in model.graph.node:
        if name in node.output:
            if node.op_type == "Constant":
                for attr in node.attribute:
                    if attr.name == "value":
                        return numpy_helper.to_array(attr.t)
            if node.op_type == "Cast" and node.input:
                return _const_value(model, node.input[0])
    return None


def _producer(model, name: str):
    for node in model.graph.node:
        if name in node.output:
            return node
    return None


def _dequant_const(model, tensor_name: str):
    dq = _producer(model, tensor_name)
    if dq is None or dq.op_type != "DequantizeLinear":
        arr = _const_value(model, tensor_name)
        return arr.astype(np.float32) if arr is not None else None
    raw = _const_value(model, dq.input[0])
    scale = _const_value(model, dq.input[1])
    zp = _const_value(model, dq.input[2]) if len(dq.input) > 2 else 0
    if raw is None or scale is None:
        return None
    scale_arr = np.array(scale, dtype=np.float32)
    zp_arr = np.array(zp, dtype=np.float32)
    if raw.ndim >= 2 and scale_arr.ndim == 1 and scale_arr.shape[0] == raw.shape[0]:
        scale_arr = scale_arr.reshape((-1,) + (1,) * (raw.ndim - 1))
        zp_arr = zp_arr.reshape((-1,) + (1,) * (raw.ndim - 1))
    return (raw.astype(np.float32) - zp_arr) * scale_arr


def load_fc_from_parsed(parsed_dir: Path) -> tuple[np.ndarray, np.ndarray] | None:
    """Load FC (fully-connected) layer weights from parsed_dir/weights/fc.npz."""
    fc_path = parsed_dir / "weights" / "fc.npz"
    if fc_path.exists():
        data = np.load(fc_path)
        return data["weight"].astype(np.float32), data["bias"].astype(np.float32)
    return None


def load_fc_from_onnx() -> tuple[np.ndarray, np.ndarray] | None:
    onnx_path = ONNX_VAI if ONNX_VAI.exists() else ONNX_QDQ
    if not onnx_path.exists():
        return None
    import onnx as _onnx

    model = _onnx.load(str(onnx_path))
    gemm = next((node for node in model.graph.node if node.op_type == "Gemm"), None)
    if gemm is None or len(gemm.input) < 2:
        return None
    weight = _dequant_const(model, gemm.input[1])
    bias = _dequant_const(model, gemm.input[2]) if len(gemm.input) > 2 else None
    if weight is None:
        return None
    if bias is None:
        bias = np.zeros(weight.shape[0], dtype=np.float32)
    trans_b = 0
    for attr in gemm.attribute:
        if attr.name == "transB":
            trans_b = int(attr.i)
    if trans_b:
        weight = weight.T
    return weight.astype(np.float32), bias.astype(np.float32)


def classify(feature: np.ndarray, parsed_dir: Path) -> np.ndarray:
    gap = feature.astype(np.float32).mean(axis=(0, 1)) * _last_act_scale(parsed_dir)
    fc = load_fc_from_parsed(parsed_dir) or load_fc_from_onnx()
    if fc is None:
        return gap
    weight, bias = fc
    if weight.shape[0] == gap.shape[0]:
        logits = gap @ weight + bias
    else:
        logits = gap @ weight.T + bias
    return logits.astype(np.float32)


def draw_classification(img_rgb: np.ndarray, top5: Iterable[tuple[int, float]], title: str) -> np.ndarray:
    from PIL import Image, ImageDraw, ImageFont

    panel_h = 120
    pil = Image.fromarray(img_rgb)
    canvas = Image.new("RGB", (pil.width, pil.height + panel_h), (25, 25, 25))
    canvas.paste(pil, (0, panel_h))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    draw.text((10, 8), title, fill=(255, 255, 180), font=font)
    for i, (idx, score) in enumerate(top5):
        draw.text((10, 32 + i * 16), f"top{i+1}: {CLASS_NAMES[idx]}  score={score:.4g}",
                  fill=(230, 230, 230), font=font)
    return np.array(canvas)


def run_single_image(img_path: str, runner, dry_run: bool, precision: str = "int8",
                     runs_base: str | Path | None = None, verify: bool = True,
                     preload_weights: bool = True):
    """Run ResNet18 E2E on a single image.

    preload_weights: if True (default), dry-run once to generate case files then
                     batch-upload all weights to HBM pool before inference.
    """
    import time as _time
    parsed = configure_resnet_precision(precision)
    img_rgb = load_image(img_path)
    q_input = preprocess_resnet18(img_rgb, parsed)
    rb = Path(runs_base) if runs_base is not None else _THIS / "runs" / "e2e" / f"resnet18_{precision}"

    # Clear FPGA HBM weight cache and on-chip TILE_IBUF before each run.
    if runner is not None and not dry_run:
        if hasattr(runner, 'clear_weight_cache'):
            runner.clear_weight_cache()
        if hasattr(runner, 'x'):
            from xdma_win import TILE_IBUF_BASE, TILE_IBUF_SIZE
            NTILES = 8
            runner.x.write(TILE_IBUF_BASE, b'\x00' * (NTILES * TILE_IBUF_SIZE))

    # Phase 1+2: generate case files then batch-upload weights.
    # Always regenerate to ensure case files match current weight config (vai/int8/int16).
    weight_hbm_map = None
    if preload_weights and not dry_run and runner is not None:
        print("[preload] Generating case files (dry-run)...", flush=True)
        run_backbone(parsed, q_input, runner=None, dry_run=True, runs_base=rb,
                     verify=False)
        if rb.exists():
            run_dirs = [d for d in sorted(rb.iterdir())
                        if d.is_dir() and (d / "preload.txt").exists()]
            if run_dirs and hasattr(runner, 'preload_all_weights'):
                print("[preload] Uploading all weights to HBM pool...", flush=True)
                t_pre = _time.time()
                weight_hbm_map = runner.preload_all_weights(run_dirs)
                print(f"[preload] Done in {_time.time()-t_pre:.1f}s", flush=True)

    feature = run_backbone(parsed, q_input, runner, dry_run, rb, verify=verify,
                           weight_hbm_map=weight_hbm_map)
    logits = classify(feature, parsed)
    order = np.argsort(logits)[-5:][::-1]
    top5 = [(int(i), float(logits[i])) for i in order]
    img_out = draw_classification(img_rgb, top5, f"ResNet18 {precision.upper()} {'DRY-RUN' if dry_run else 'FPGA'}")
    return img_out, top5, logits
