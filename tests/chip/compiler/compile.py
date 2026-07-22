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
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CHIP_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CHIP_DIR))

from compiler import _mini_yaml as mini_yaml
from compiler.lowering.lower import lower
from compiler.codegen.encode_isa import (
    encode_ops,
    encode_plan,
    write_program_hex,
    write_program_bin,
)
from compiler.packer.weights_packer import pack_all_layers as pack_weights
from compiler.packer.wb_packer import pack_all_layers as pack_wbs


NETWORK_CONFIG = {
    "yolov5n": {
        "parsed_dir":  "model/yolov5n/parsed",
        "parsed_dir_int16": "model/yolov5n/parsed_int16_widened",
        "weight_key":  "weight_int8",
    },
    "resnet18": {
        "parsed_dir":  "model/resnet18/parsed_vai",
        "parsed_dir_int16": "model/resnet18/parsed_vai_int16_widened",
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


def runtime_warnings(plan: dict) -> list[str]:
    """Cheap checks for artifacts that compile but cannot run on current RTL."""
    warnings: list[str] = []
    ibuf_size = int(plan["address_map"].get("ibuf_size", 0))
    tile_obuf_size = int(plan["address_map"].get("tile_obuf_size", 0))
    current_layer = "unknown"
    for idx, op in enumerate(plan.get("ops", [])):
        current_layer = op.get("layer", current_layer)
        if op.get("kind") != "cdma_copy":
            continue
        dst = op.get("dst")
        if isinstance(dst, (list, tuple)) and len(dst) == 2 and dst[0] == "ibuf":
            dst_off = int(dst[1])
            length = int(op.get("length", 0))
            tile_rel = dst_off % ibuf_size if ibuf_size else dst_off
            end = tile_rel + length
            if ibuf_size and end > ibuf_size:
                is_weight_load = (
                    isinstance(op.get("src"), (list, tuple))
                    and len(op.get("src")) == 2
                    and op.get("src")[0] == "hbm"
                )
                fix = "needs output-channel/weight-section tiling" if is_weight_load else "needs OH/input tiling"
                warnings.append(
                    f"op[{idx}] layer={current_layer} copies {length}B "
                    f"to IBUF+0x{dst_off:x} (tile_rel=0x{tile_rel:x}), "
                    f"ending at 0x{end:x} > ibuf_size 0x{ibuf_size:x}; {fix}"
                )
        src = op.get("src")
        if isinstance(src, (list, tuple)) and len(src) == 2 and src[0] == "tile_obuf":
            src_off = int(src[1])
            length = int(op.get("length", 0))
            tile_rel = src_off % tile_obuf_size if tile_obuf_size else src_off
            end = tile_rel + length
            if tile_obuf_size and end > tile_obuf_size:
                warnings.append(
                    f"op[{idx}] layer={current_layer} reads {length}B "
                    f"from TILE_OBUF+0x{src_off:x} (tile_rel=0x{tile_rel:x}), "
                    f"ending at 0x{end:x} > tile_obuf_size 0x{tile_obuf_size:x}; needs OH/output tiling"
                )
    return warnings


def insert_weight_load_ops(plan: dict, weights_info: dict, *, hbm_off: int = 0x200000) -> None:
    """Insert per-layer HBM->IBUF weight refresh ops before each layer first runs.

    `weights.bin` is a concatenated blob uploaded once to HBM at `hbm_off`.
    Each layer's packed section is copied into IBUF offset 0 before the layer's
    first op.  This keeps the one-shot program within the 512KB IBUF window
    instead of trying to upload the whole model into IBUF.
    """
    sections = weights_info.get("__section_offsets", {})
    if not sections:
        return

    rec_by_name = {rec["name"]: rec for rec in plan["weights_layout"]["layers"]}
    ibuf_size = int(plan["address_map"].get("ibuf_size", 0x80000))
    loaded: set[tuple[str, int]] = set()
    out_ops: list[dict] = []

    for op in plan.get("ops", []):
        layer = op.get("layer")
        tile_start = int(op.get("weight_tile_start", 0))
        tile_count_hint = int(op.get("weight_tile_count", 8))
        load_key = (layer, tile_start)
        if layer in sections and load_key not in loaded:
            rec = rec_by_name[layer]
            nbytes = int(weights_info[layer]["bytes"])
            per_tile = int(rec.get("per_tile_bytes", nbytes))
            tiles_total = int(rec.get("tiles_needed", 1))
            tile_count = min(max(tiles_total - tile_start, 0), max(1, tile_count_hint))
            for tile in range(tile_count):
                src = hbm_off + int(sections[layer]) + (tile_start + tile) * per_tile
                dst = tile * ibuf_size + int(rec.get("ibuf_byte_off", 0))
                out_ops.append({
                    "kind": "cdma_copy",
                    "layer": layer,
                    "weight_tile_start": tile_start,
                    "comment": f"load weights for {layer} tile{tile_start + tile}->local{tile}",
                    "src": ("hbm", src),
                    "dst": ("ibuf", dst),
                    "length": per_tile,
                })
                out_ops.append({"kind": "wait_cdma", "layer": layer, "weight_tile_start": tile_start})
            loaded.add(load_key)
        out_ops.append(op)

    plan["ops"] = out_ops
    plan.setdefault("host_io", {})["weights_hbm_off"] = hbm_off
    plan.setdefault("compile_meta", {})["weights_loaded_from_hbm"] = True


def op_word_count(op: dict) -> int:
    """Instruction word count for one encoded op."""
    kind = op.get("kind")
    if kind in {"nop", "end", "wait_vpu", "wait_cdma", "wait_dcim", "sync", "dcim_exec"}:
        return 1
    if kind == "cdma_copy":
        return 6
    if kind == "cdma_stride":
        return 9
    if kind == "vpu_exec":
        return 13
    if kind == "dcim_layer":
        # header + 8 scalar words + wei/out base for each tile.
        return 1 + 8 + 16
    if kind == "dcim_cfg":
        return 1 + 2 * len(op.get("pairs", []))
    return 1


def split_program_segments(plan: dict, max_words: int) -> list[list[dict]]:
    """Split ops into INST_BRAM-sized segments at completed-operation barriers."""
    if max_words <= 1:
        return []

    core_ops = list(plan.get("ops", []))
    if core_ops and core_ops[-1].get("kind") == "end":
        core_ops = core_ops[:-1]

    barrier_kinds = {"wait_vpu", "wait_cdma", "wait_dcim", "sync", "nop"}
    segments: list[list[dict]] = []
    start = 0
    end_op = {"kind": "end"}

    while start < len(core_ops):
        used = op_word_count(end_op)
        last_barrier = None
        i = start
        while i < len(core_ops):
            next_used = used + op_word_count(core_ops[i])
            if next_used > max_words:
                break
            used = next_used
            if core_ops[i].get("kind") in barrier_kinds:
                last_barrier = i + 1
            i += 1

        if i == len(core_ops):
            cut = i
        elif last_barrier is not None and last_barrier > start:
            cut = last_barrier
        else:
            layer = core_ops[start].get("layer", "unknown")
            raise RuntimeError(
                f"single unsplittable op group near op[{start}] layer={layer} "
                f"does not fit in {max_words} words"
            )

        segment = core_ops[start:cut] + [end_op]
        actual_words = len(encode_ops(plan, segment))
        if actual_words > max_words:
            raise RuntimeError(
                f"internal segmenter error: segment {len(segments)} is "
                f"{actual_words} words > max {max_words}"
            )
        segments.append(segment)
        start = cut

    return segments


def write_program_segments(plan: dict, out_dir: Path, max_words: int) -> dict | None:
    """Write segmented programs when the monolithic stream does not fit INST_BRAM."""
    words = encode_plan(plan)
    if len(words) <= max_words:
        plan.setdefault("compile_meta", {})["program_segments"] = 1
        return None

    segments = split_program_segments(plan, max_words)
    seg_dir = out_dir / "program_segments"
    seg_dir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "mode": "segmented_inst_bram",
        "inst_size_words": max_words,
        "total_words": len(words),
        "segments": [],
    }
    for idx, ops in enumerate(segments):
        seg_words = encode_ops(plan, ops)
        stem = f"segment_{idx:03d}"
        write_program_hex(seg_words, str(seg_dir / f"{stem}.hex"))
        write_program_bin(seg_words, str(seg_dir / f"{stem}.bin"))
        manifest["segments"].append({
            "index": idx,
            "words": len(seg_words),
            "bytes": len(seg_words) * 4,
            "bin": f"program_segments/{stem}.bin",
            "hex": f"program_segments/{stem}.hex",
        })

    plan.setdefault("compile_meta", {})["program_segments"] = len(segments)
    plan["compile_meta"]["program_segment_max_words"] = max_words
    return manifest


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
    ap.add_argument("--dcim-loop", choices=["layer", "legacy"], default="layer",
                    help="full lowering DCIM loop mode: layer=OP_DCIM_LAYER fast path, legacy=expanded DCIM_EXEC debug path")
    args = ap.parse_args()

    cfg = NETWORK_CONFIG[args.network]
    parsed_key = f"parsed_dir_{args.mode}"
    parsed_dir = Path(args.parsed or (REPO / cfg.get(parsed_key, cfg["parsed_dir"])))
    network_json = parsed_dir / "network.json"
    weights_dir = parsed_dir / "weights"

    if not network_json.exists():
        print(f"ERROR: {network_json} not found. Run the frontend first.", file=sys.stderr)
        sys.exit(1)

    network = json.loads(network_json.read_text())
    network["_parsed_dir"] = str(parsed_dir)
    model_info = network.setdefault("model_info", {})
    model_info.setdefault("name", network.get("model", args.network))
    if "input_shape" in network and "input_shape" not in model_info:
        model_info["input_shape"] = network["input_shape"]
    model_info.setdefault("output_shape", network.get("output_shape", []))

    hw = mini_yaml.load_file(args.hw_caps)

    # ---- 1. Lower ----
    if args.full:
        from compiler.lowering.lower_full import lower_full
        plan = lower_full(network, hw, mode=args.mode, max_layers=args.max_layers, dcim_loop=args.dcim_loop)
    else:
        plan = lower(network, hw, mode=args.mode, max_layers=args.max_layers)

    # ---- 2. Pack weights (only valid if .npz has the requested weight_key) ----
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
        insert_weight_load_ops(plan, weights_info)

    # ---- 3. Codegen (program) ----
    words = encode_plan(plan)

    # ---- 4. Write outputs ----
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    write_program_hex(words, str(out_dir / "program.hex"))
    write_program_bin(words, str(out_dir / "program.bin"))

    inst_size = int(plan["address_map"].get("inst_size", 0))
    segment_manifest = None
    if inst_size:
        segment_manifest = write_program_segments(plan, out_dir, inst_size // 4)
    if segment_manifest:
        (out_dir / "program_manifest.json").write_text(json.dumps(segment_manifest, indent=2))
    else:
        manifest_path = out_dir / "program_manifest.json"
        if manifest_path.exists():
            manifest_path.unlink()
        seg_dir = out_dir / "program_segments"
        if seg_dir.exists():
            shutil.rmtree(seg_dir)

    (out_dir / "plan.json").write_text(json.dumps(plan, indent=2, default=str))

    if can_pack:
        (out_dir / "weights.bin").write_bytes(weights_bytes)
        (out_dir / "weights_layout.json").write_text(json.dumps(weights_info, indent=2))
        (out_dir / "wb.bin").write_bytes(wb_bytes)
        (out_dir / "wb_layout.json").write_text(json.dumps(wb_info, indent=2))

    (out_dir / "memory_map.md").write_text(memory_map_md(plan))
    warnings = runtime_warnings(plan)
    program_bytes = len(words) * 4
    if inst_size and program_bytes > inst_size and not segment_manifest:
        warnings.append(
            f"program.bin is {program_bytes}B > inst_size 0x{inst_size:x}; "
            "needs instruction compression, larger INST_BRAM, or segmented execution"
        )
    if warnings:
        (out_dir / "runtime_warnings.txt").write_text("\n".join(warnings) + "\n")
    else:
        warn_path = out_dir / "runtime_warnings.txt"
        if warn_path.exists():
            warn_path.unlink()

    # ---- 5. Print summary ----
    print(f"OK: {args.network} compiled to {out_dir}")
    print(f"  program: {len(words)} words ({len(words) * 4} bytes)")
    print(f"  conv layers compiled: {plan['compile_meta']['num_conv_layers_compiled']}"
          f" / {plan['compile_meta']['num_conv_layers_total']}")
    if can_pack:
        print(f"  weights.bin: {len(weights_bytes)} bytes")
        print(f"  wb.bin:      {len(wb_bytes)} bytes")
    if segment_manifest:
        print(f"  program segments: {len(segment_manifest['segments'])} "
              f"(max {segment_manifest['inst_size_words']} words)")
    if plan["unsupported"]:
        print(f"  unsupported nodes: {len(plan['unsupported'])} (see memory_map.md)")
    if warnings:
        print(f"  runtime warnings: {len(warnings)} (see runtime_warnings.txt)")


if __name__ == "__main__":
    main()
