"""Pack per-layer DQA scale / bias / QA scale / NN-LUT into WB byte sections.

Layout (must match `lower.emit_conv` WB sub-offsets):

  qa_scale_off     : float32  (1 element)
  pad to 16 bytes
  dqa_scale_off    : float32 × cout  (per output channel)
  pad to 16 bytes
  dqa_bias_off     : float32 × cout

Total section size: 16 + ceil(cout*4, 16) + ceil(cout*4, 16)

For SiLU/Sigmoid (NN-LUT) layers, the LUT segment table (16 segments × {bp, slope, intercept})
is appended after the bias.  We do not implement NN-LUT pack here yet because
neither yolov5n's first 3 layers nor resnet18 needs it for the MVP run; emitter
slot is reserved.
"""

from __future__ import annotations

import os
from typing import Dict, Tuple

import numpy as np


def _round16(x: int) -> int:
    return (x + 15) & ~15


def pack_layer_wb(qa_scale: float, dqa_scale: np.ndarray, dqa_bias: np.ndarray) -> bytes:
    """Return one layer's WB section as little-endian bytes."""
    cout = dqa_scale.shape[0]
    assert dqa_bias.shape == (cout,), (dqa_scale.shape, dqa_bias.shape)

    section = bytearray()

    # qa_scale (1 fp32), pad to 16
    section += np.float32(qa_scale).tobytes()
    while len(section) < 16:
        section += b"\x00"

    # dqa_scale[cout], pad to 16
    section += dqa_scale.astype(np.float32).tobytes()
    while len(section) % 16 != 0:
        section += b"\x00"

    # dqa_bias[cout]
    section += dqa_bias.astype(np.float32).tobytes()
    while len(section) % 16 != 0:
        section += b"\x00"

    return bytes(section)


def pack_all_layers(plan: dict, weights_npz_dir: str) -> Tuple[bytes, Dict[str, dict]]:
    """Concatenate all layers' WB sections in plan order.

    Returns (wb_bytes, info) where info[name] = {'offset': int, 'bytes': int}.
    The host uploads `wb_bytes` to VPU_BUF skip region starting at
        plan['wb_layout']['scratch_off_by_layer'][name] (chip-v2: 0x3C0000+).
    The program issues a CDMA copy per layer to bring each section into WB.
    """
    info: Dict[str, dict] = {}
    out = bytearray()
    cur = 0

    for rec in plan["wb_layout"]["layers"]:
        name = rec["name"]
        if rec.get("kind") == "qa_only":
            section = bytearray(np.float32(float(rec["qa_scale"])).tobytes())
            while len(section) < 16:
                section += b"\x00"
            section = bytes(section)
            if len(section) != rec["section_bytes"]:
                raise ValueError(
                    f"layer {name}: WB section size {len(section)} != reserved {rec['section_bytes']}"
                )
            info[name] = {"offset": cur, "bytes": len(section)}
            out += section
            cur += len(section)
            continue
        if rec.get("kind") == "qdq":
            channels = int(rec["channels"])
            dqa_scale = np.full((channels,), float(rec["dqa_scale"]), dtype=np.float32)
            dqa_bias = np.zeros((channels,), dtype=np.float32)
            section = pack_layer_wb(float(rec["qa_scale"]), dqa_scale, dqa_bias)
            if len(section) != rec["section_bytes"]:
                raise ValueError(
                    f"layer {name}: WB section size {len(section)} != reserved {rec['section_bytes']}"
                )
            info[name] = {"offset": cur, "bytes": len(section)}
            out += section
            cur += len(section)
            continue

        safe = name.replace(".", "_").replace("/", "_")
        npz_path = os.path.join(weights_npz_dir, f"{safe}.npz")
        if not os.path.exists(npz_path):
            raise FileNotFoundError(f"missing weight npz for layer {name}: {npz_path}")
        z = np.load(npz_path)

        dqa_scale = z["dqa_scale"].astype(np.float32)
        dqa_bias = z["dqa_bias"].astype(np.float32)
        if rec.get("qa_scale") is not None:
            qa_scale = float(rec["qa_scale"])
        elif "act_scale" in z.files:
            qa_scale = 1.0 / float(z["act_scale"])
        else:
            qa_scale = 1.0      # FP32 path: QA is a no-op multiply by 1

        section = pack_layer_wb(qa_scale, dqa_scale, dqa_bias)

        # Validate against the size that lower.py reserved.
        if len(section) != rec["section_bytes"]:
            raise ValueError(
                f"layer {name}: WB section size {len(section)} != reserved {rec['section_bytes']}.  "
                f"Lowering and packer drifted apart."
            )

        info[name] = {"offset": cur, "bytes": len(section)}
        out += section
        cur += len(section)

    return bytes(out), info
