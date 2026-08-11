"""Operator-rule table used by the lowering pass.

Each entry is keyed by ONNX op_type and returns either:
  - None  → fail-loud (unsupported, look up message in hw_caps.yaml)
  - dict with 'check(op, hw)' and 'emit(op, hw, ctx)' callables.

For now this is a thin pure-Python module; rule callables are imported by
`lower.py`.
"""
from __future__ import annotations

from typing import Any, Dict
import os
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
from chip_config import DCIM_CH_IN  # noqa: E402


def conv_check(layer: Dict[str, Any], hw: Dict[str, Any]) -> None:
    """Validate a Conv layer against hw_caps.Conv requires; raise UnsupportedOp."""
    from ..errors import UnsupportedOp
    req = hw["op_lowering"]["Conv"]["requires"]
    group = int(layer.get("group", 1))
    kh = int(layer["kernel_h"])
    kw = int(layer["kernel_w"])
    strides = layer.get("stride", [1, 1])
    pads = layer.get("padding", [0, 0, 0, 0])
    name = layer["name"]
    if group != req["group"]:
        raise UnsupportedOp(name, "Conv",
            f"group={group} not supported (only group=1).  Options: (a) implement grouped conv lowering, (b) host fallback")
    if max(kh, kw) > req["kernel_max"]:
        raise UnsupportedOp(name, "Conv",
            f"kernel={kh}x{kw} > hw kernel_max={req['kernel_max']}.  Options: (a) tile by spatial, (b) extend im2col_unit")
    if max(strides) > req["stride_max"]:
        raise UnsupportedOp(name, "Conv",
            f"stride={strides} > {req['stride_max']}.  Options: (a) split layer, (b) widen im2col stride field")
    if max(pads) > req["pad_max"]:
        raise UnsupportedOp(name, "Conv",
            f"pad={pads} > {req['pad_max']}.  Options: (a) explicit pad in OBUF, (b) widen pad field")
    # acc_depth check
    acc_depth = (kh * kw * int(layer["in_channels"]) + DCIM_CH_IN - 1) // DCIM_CH_IN
    acc_max = int(hw["units"]["dcim"]["acc_depth_max"])
    if acc_depth > acc_max:
        raise UnsupportedOp(name, "Conv",
            f"acc_depth={acc_depth} > {acc_max}.  Options: (a) split CH_IN into multiple matmul + add, "
            f"(b) raise DCIM_ACC_MAX")


def maxpool_check(node: Dict[str, Any], hw: Dict[str, Any]) -> None:
    from ..errors import UnsupportedOp
    req = hw["op_lowering"]["MaxPool"]["requires"]
    kernel = node.get("kernel_shape", [1, 1])
    stride = node.get("strides", [1, 1])
    pads = node.get("pads", [0, 0, 0, 0])
    if list(kernel) != list(req["kernel"]):
        raise UnsupportedOp(node["name"], "MaxPool",
            f"kernel={kernel} != hw fixed {req['kernel']}.  mp_unit_fixed is hard-coded to 5x5.  "
            f"Options: (a) modify rtl/vpu/mp_unit_fixed.sv to be parametric, (b) split into multiple 5x5 mp")
    if max(stride) != req["stride"]:
        raise UnsupportedOp(node["name"], "MaxPool",
            f"stride={stride} != hw fixed {req['stride']}")
    if max(pads) != req["pad"]:
        raise UnsupportedOp(node["name"], "MaxPool",
            f"pads={pads} != hw fixed {req['pad']}")


def resize_check(node: Dict[str, Any], hw: Dict[str, Any]) -> None:
    from ..errors import UnsupportedOp
    req = hw["op_lowering"]["Resize"]["requires"]
    mode = node.get("mode", "nearest")
    if mode != req["mode"]:
        raise UnsupportedOp(node["name"], "Resize",
            f"mode={mode} != {req['mode']}.  us_unit_fixed supports nearest only")
