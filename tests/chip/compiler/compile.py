#!/usr/bin/env python3
"""
compile.py - end-to-end compiler driver.

Usage:
    python tests/chip/compiler/compile.py --network yolov5n --out tests/chip/dist/yolov5n
    python tests/chip/compiler/compile.py --network resnet18 --out tests/chip/dist/resnet18 --max-layers 3

Outputs (in --out directory):
    plan.json           - the full execution plan (JSON, schema v1)
    program.hex         - INST_BRAM image (one 32-bit word per line, lower-case)
    program.bin         - same as program.hex but binary, little-endian
    weights.bin         - per-layer IBUF weight blobs, concatenated
    weights_layout.json - per-layer offsets / sizes / IBUF byte-off
    wb.bin              - per-layer WB sections, concatenated
    wb_layout.json      - per-layer offsets / sizes / WB byte-off
    features_template.bin - (optional) NHWC INT8 image template at OBUF[0]
    memory_map.md       - human-readable summary of the OBUF / IBUF / WB plan
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CHIP_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CHIP_DIR))

from compiler import _mini_yaml as mini_yaml
from compiler.lowering.lower import lower
from compiler.codegen.encode_isa import encode_plan, write_program_hex, write_program_bin
from compiler.packer.weights_packer import pack_all_layers as pack_weights
from compiler.packer.wb_packer import pack_all_layers as pack_wbs


NETWORK_CONFIG = {
    "yolov5n": {
        "parsed_dir":  "model/yolov5n/parsed",
        "weight_key":  "weight_int8",
    },
    "resnet18": {
        "parsed_dir":  "model/resnet18/parsed_qdq",
        "weight_key":  "weight_int8",
    },
}


def memory_map_md(plan: dict) -> str:
    lines = []
    lines.append(f"# EdgeYOLO-FPGA-lite compile output — {plan['network']}")
    lines.append("")
    lines.append(f"- mode: `{plan['mode']}`")
    lines.append(f"- input_shape: {plan['input_shape']}")
    lines.append(f"- output_shape: {plan['output_shape']}")
    lines.append(f"- compiled: {plan['compile_meta']}")
    lines.append("")
    lines.append("## Address map")
    for k, v in plan["address_map"].items():
        lines.append(f"- `{k}` = 0x{int(v):x}")
    lines.append("")
    lines.append("## Per-layer memory plan")
    lines.append("| layer | in_off | out_off | im2col_off | input HxW | output HxW | acc_depth | tiles |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for L in plan["memory_plan"]["layers"]:
        lines.append(
            f"| {L['name']} | 0x{L['input_off']:08x} | 0x{L['output_off']:08x} | 0x{L['im2col_off']:08x} | "
            f"{L['input_hw'][0]}x{L['input_hw'][1]} | {L['output_hw'][0]}x{L['output_hw'][1]} | "
            f"{L['acc_depth']} | {L['tiles_needed']} |"
        )
    lines.append("")
    lines.append("## Unsupported nodes (fail-loud)")
    if not plan["unsupported"]:
        lines.append("None.")
    else:
        for u in plan["unsupported"][:40]:
            lines.append(f"- {u}")
        if len(plan["unsupported"]) > 40:
            lines.append(f"- ...{len(plan['unsupported']) - 40} more")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="EdgeYOLO-FPGA-lite ONNX → ISA compiler")
    ap.add_argument("--network", required=True, choices=list(NETWORK_CONFIG),
                    help="which network to compile")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--mode", default="int8", choices=["int8", "int16"],
                    help="DCIM datapath mode")
    ap.add_argument("--max-layers", type=int, default=None,
                    help="compile only the first N conv layers (useful for RTL bring-up)")
    ap.add_argument("--hw-caps", default=str(CHIP_DIR / "compiler/lowering/hw_caps.yaml"),
                    help="path to hw_caps.yaml")
    ap.add_argument("--parsed", default=None,
                    help="override parsed/network.json directory")
    ap.add_argument("--full", action="store_true",
                    help="use full-network lowering (Add/Concat/US/MP)")
    args = ap.parse_args()

    cfg = NETWORK_CONFIG[args.network]
    parsed_dir = Path(args.parsed or (REPO / cfg["parsed_dir"]))
    network_json = parsed_dir / "network.json"
    weights_dir = parsed_dir / "weights"

    if not network_json.exists():
        print(f"ERROR: {network_json} not found. Run the frontend first.", file=sys.stderr)
        sys.exit(1)

    network = json.loads(network_json.read_text())
    network["model_info"].setdefault("name", args.network)

    hw = mini_yaml.load_file(args.hw_caps)

    # ---- 1. Lower ----
    if args.full:
        from compiler.lowering.lower_full import lower_full
        plan = lower_full(network, hw, mode=args.mode, max_layers=args.max_layers)
    else:
        plan = lower(network, hw, mode=args.mode, max_layers=args.max_layers)

    # ---- 2. Codegen (program) ----
    words = encode_plan(plan)

    # ---- 3. Pack weights (only valid if .npz has the requested weight_key) ----
    can_pack = True
    sample_layer = next(iter(plan["weights_layout"]["layers"]), None)
    if sample_layer is not None:
        safe = sample_layer["name"].replace(".", "_").replace("/", "_")
        import numpy as np
        z = np.load(weights_dir / f"{safe}.npz")
        if cfg["weight_key"] not in z.files:
            print(f"NOTE: {cfg['weight_key']!r} missing from {safe}.npz "
                  f"(keys: {z.files}); skipping weights.bin / wb.bin")
            can_pack = False

    weights_bytes = b""
    weights_info = {}
    wb_bytes = b""
    wb_info = {}
    if can_pack:
        weights_bytes, weights_info = pack_weights(plan, str(weights_dir),
                                                   mode=args.mode,
                                                   weight_key=cfg["weight_key"])
        wb_bytes, wb_info = pack_wbs(plan, str(weights_dir))

    # ---- 4. Write outputs ----
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "plan.json").write_text(json.dumps(plan, indent=2, default=str))
    write_program_hex(words, str(out_dir / "program.hex"))
    write_program_bin(words, str(out_dir / "program.bin"))

    if can_pack:
        (out_dir / "weights.bin").write_bytes(weights_bytes)
        (out_dir / "weights_layout.json").write_text(json.dumps(weights_info, indent=2))
        (out_dir / "wb.bin").write_bytes(wb_bytes)
        (out_dir / "wb_layout.json").write_text(json.dumps(wb_info, indent=2))

    (out_dir / "memory_map.md").write_text(memory_map_md(plan))

    # ---- 5. Print summary ----
    print(f"OK: {args.network} compiled to {out_dir}")
    print(f"  program: {len(words)} words ({len(words) * 4} bytes)")
    print(f"  conv layers compiled: {plan['compile_meta']['num_conv_layers_compiled']}"
          f" / {plan['compile_meta']['num_conv_layers_total']}")
    if can_pack:
        print(f"  weights.bin: {len(weights_bytes)} bytes")
        print(f"  wb.bin:      {len(wb_bytes)} bytes")
    if plan["unsupported"]:
        print(f"  unsupported nodes: {len(plan['unsupported'])} (see memory_map.md)")


if __name__ == "__main__":
    main()
