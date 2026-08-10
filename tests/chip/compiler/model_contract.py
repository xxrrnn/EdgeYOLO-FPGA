"""Validation for the quantized-model/RTL precision contract.

The NPZ key is historically named ``weight_int8`` for every precision.  Its
dtype, rather than the key spelling, is the storage contract: int8 for W8A8
and int16 for native W16A16.  Keeping that key avoids changing host-visible
files or the established layer/address mapping.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np


NATIVE_INT16_SEMANTICS = {"int16", "native_int16", "native_w16a16", "w16a16"}
WIDENED_INT16_SEMANTICS = {
    "int8_values_widened_to_int16",
    "int16_widened",
    "widened_int16",
}


def _safe_name(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def _semantics(network: dict[str, Any]) -> str:
    value = network.get("quantization_semantics")
    if value is None:
        value = network.get("model_info", {}).get("quantization", {}).get("semantics")
    return str(value or "").strip().lower()


def validate_model_precision(
    network: dict[str, Any],
    weights_dir: Path,
    *,
    mode: str,
    weight_key: str = "weight_int8",
    allow_widened_int16: bool = False,
) -> dict[str, Any]:
    """Validate all Conv weights and return evidence recorded in ``plan.json``.

    Native INT16 is accepted only when it is explicit in metadata or when the
    supplied INT16 tensors actually exercise values outside the INT8 range.
    This prevents an accidental ``astype(int16)`` from being presented as a
    native W16A16 model.  Legacy widened artifacts remain available behind the
    explicit ``allow_widened_int16`` switch.
    """
    if mode not in {"int8", "int16"}:
        raise ValueError(f"unsupported hardware mode {mode!r}")

    semantics = _semantics(network)
    widened = bool(network.get("int16_from_int8")) or semantics in WIDENED_INT16_SEMANTICS
    expected_dtype = np.dtype(np.int16 if mode == "int16" else np.int8)
    checked = 0
    max_abs = 0

    for layer in network.get("layers", []):
        if str(layer.get("type", "conv")).lower() != "conv":
            continue
        name = str(layer["name"])
        path = weights_dir / f"{_safe_name(name)}.npz"
        if not path.is_file():
            raise FileNotFoundError(f"missing quantized weights for {name}: {path}")
        with np.load(path) as data:
            if weight_key not in data.files:
                raise KeyError(f"{path}: missing {weight_key!r}; keys={list(data.files)}")
            weight = data[weight_key]
            if weight.dtype != expected_dtype:
                raise TypeError(
                    f"{name}: {mode} requires {expected_dtype.name} weights, "
                    f"got {weight.dtype} in {path}"
                )
            declared_shape = layer.get("weight_shape")
            if declared_shape is not None and tuple(int(x) for x in declared_shape) != weight.shape:
                raise ValueError(
                    f"{name}: weight_shape metadata {declared_shape} does not match "
                    f"the packed OHWI tensor {list(weight.shape)}"
                )
            if weight.size:
                layer_max = int(np.max(np.abs(weight.astype(np.int64))))
                max_abs = max(max_abs, layer_max)
            if "weight_zero_point" in data.files and np.any(data["weight_zero_point"] != 0):
                raise ValueError(
                    f"{name}: asymmetric weight zero-point is unsupported; "
                    "the DCIM datapath requires signed symmetric quantization"
                )
        checked += 1

    if checked == 0:
        raise ValueError("parsed model contains no Conv layers to validate")

    if mode == "int16":
        if widened and not allow_widened_int16:
            raise ValueError(
                "the selected model is INT8 values widened to INT16, not native W16A16; "
                "select the explicit widened mode or provide a native INT16 parsed model"
            )
        explicit_native = semantics in NATIVE_INT16_SEMANTICS
        range_evidence = max_abs > 127
        if not widened and not explicit_native and not range_evidence:
            raise ValueError(
                "cannot prove native W16A16 semantics: add "
                "quantization_semantics='native_w16a16' to network.json or provide "
                "INT16 weights containing values outside the INT8 range"
            )

        for layer in network.get("layers", []):
            if float(layer.get("act_zero_point", 0.0)) != 0.0:
                raise ValueError(
                    f"{layer.get('name', '<unnamed>')}: native INT16 activation "
                    "zero-point must be 0"
                )
            if float(layer.get("in_act_zero_point", 0.0)) != 0.0:
                raise ValueError(
                    f"{layer.get('name', '<unnamed>')}: native INT16 input "
                    "zero-point must be 0"
                )

        quant = network.get("model_info", {}).get("quantization", {})
        if quant:
            for field in ("weight_bits", "activation_bits"):
                if field in quant and int(quant[field]) != 16:
                    raise ValueError(f"native W16A16 requires {field}=16, got {quant[field]}")
            if not widened and "accumulator_bits" in quant and int(quant["accumulator_bits"]) != 64:
                raise ValueError(
                    "native W16A16 requires accumulator_bits=64 to match the RTL DQA contract"
                )

        resolved = "int16_widened" if widened else "native_w16a16"
    else:
        if semantics in NATIVE_INT16_SEMANTICS or widened:
            raise ValueError(f"INT16 model semantics {semantics or 'widened'} cannot run in int8 mode")
        resolved = "native_w8a8"

    return {
        "hardware_mode": mode,
        "quantization_semantics": resolved,
        "weight_dtype": expected_dtype.name,
        "weight_key": weight_key,
        "conv_layers_checked": checked,
        "max_abs_weight": max_abs,
        "exercises_values_outside_int8": bool(max_abs > 127),
        "accumulator_bits": 64 if mode == "int16" else 32,
    }
