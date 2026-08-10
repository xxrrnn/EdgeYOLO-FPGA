#!/usr/bin/env python3
"""Smoke-test a genuine signed INT16 QDQ model through the ResNet frontend."""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tests" / "chip"))
sys.path.insert(0, str(REPO / "tests" / "chip" / "compiler" / "frontend"))
sys.path.insert(0, str(REPO / "tests" / "chip" / "unit-tb"))

from compiler.model_contract import validate_model_precision  # noqa: E402
from parse_resnet18_qdq import parse_resnet18_qdq, save  # noqa: E402


def _native_qdq_model() -> onnx.ModelProto:
    initializers = [
        numpy_helper.from_array(np.array(1.0 / 32768.0, np.float32), "x_scale"),
        numpy_helper.from_array(np.array(0, np.int16), "x_zp"),
        numpy_helper.from_array(np.array([[[[30000]]]], np.int16), "weight_q"),
        numpy_helper.from_array(np.array([1.0 / 32768.0], np.float32), "w_scale"),
        numpy_helper.from_array(np.array([0], np.int16), "w_zp"),
        numpy_helper.from_array(np.array(1.0 / 16384.0, np.float32), "y_scale"),
        numpy_helper.from_array(np.array(0, np.int16), "y_zp"),
    ]
    nodes = [
        helper.make_node("DequantizeLinear", ["input_q", "x_scale", "x_zp"], ["input_f"], name="input.DQ"),
        helper.make_node(
            "DequantizeLinear", ["weight_q", "w_scale", "w_zp"], ["weight_f"],
            name="conv1.weight.DQ", axis=0,
        ),
        helper.make_node("Conv", ["input_f", "weight_f"], ["conv_f"], name="conv1/Conv"),
        helper.make_node("QuantizeLinear", ["conv_f", "y_scale", "y_zp"], ["output_q"], name="output.Q"),
    ]
    graph = helper.make_graph(
        nodes,
        "native_w16a16_smoke",
        [helper.make_tensor_value_info("input_q", TensorProto.INT16, [1, 1, 1, 1])],
        [helper.make_tensor_value_info("output_q", TensorProto.INT16, [1, 1, 1, 1])],
        initializer=initializers,
    )
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 21)])


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="edgeyolo-native-int16-frontend-") as temp:
        root = Path(temp)
        onnx_path = root / "resnet18_w16a16.onnx"
        parsed_dir = root / "parsed_int16"
        onnx.save(_native_qdq_model(), onnx_path)

        layers, weights, topology, model, add_scales, mode = parse_resnet18_qdq(
            onnx_path, mode="int16"
        )
        assert mode == "int16"
        save(parsed_dir, layers, weights, topology, model, add_scales, mode)

        network = json.loads((parsed_dir / "network.json").read_text())
        packed = np.load(parsed_dir / "weights" / "conv1_Conv.npz")["weight_int8"]
        assert packed.dtype == np.int16
        assert packed.shape == (1, 1, 1, 1)  # compiler-native OHWI
        assert int(packed[0, 0, 0, 0]) == 30000
        evidence = validate_model_precision(
            network, parsed_dir / "weights", mode="int16", weight_key="weight_int8"
        )
        assert evidence["quantization_semantics"] == "native_w16a16"
        assert evidence["accumulator_bits"] == 64
        assert evidence["exercises_values_outside_int8"]

        import resnet_e2e

        selected = resnet_e2e.configure_resnet_precision("int16", parsed_override=parsed_dir)
        input_q = resnet_e2e.preprocess_resnet18(
            np.zeros((256, 256, 3), dtype=np.uint8), selected
        )
        assert input_q.dtype == np.int16
        assert int(np.max(np.abs(input_q.astype(np.int64)))) > 127

    print("ResNet native INT16 frontend: PASS")


if __name__ == "__main__":
    main()
