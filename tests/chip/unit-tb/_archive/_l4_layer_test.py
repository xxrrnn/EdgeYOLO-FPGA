"""
_l4_layer_test.py  —  YOLOv5n L4 逐层渐进测试

策略：
  1. 用编译器编译前 N 层（--max-layers N）
  2. 对每一层：
     a. 生成 numpy golden 激活（前向传播）
     b. 把激活写入 VPU_BUF，运行 FPGA，读回结果
     c. 对比 golden 与 FPGA 输出

当前限制（L4-A，只跑无需 im2col-OH-tiling 的小层）：
  - model.0.conv: 160×160×3×6×6 im2col 需要 2.7MB IBUF，当前 IBUF 512KB → 需 OH-tiling（未实现）
  - 从 model.2.cv1 开始（1×1 kernel，acc_depth=1，无 im2col 问题）可直接跑

使用方法：
  cd tests/chip/unit-tb
  python _l4_layer_test.py --max-layers 6 --start-layer 2
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
CHIP = Path(__file__).resolve().parents[1]   # tests/chip/
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(CHIP))

from xdma_win import (
    ChipRunnerWin, VPU_BUF_BASE, WB_BASE, TILE_IBUF_BASE,
)
from xdma_win import XDMAWin as _XDMAWin

INST_BRAM_BASE = 0x1_0400_0000  # VPU_AXI 指令 BRAM

# ---------------------------------------------------------------------------
# numpy golden 单层 conv（INT8 激活 × INT8 权重 → INT32 → FP32）
# ---------------------------------------------------------------------------

def conv2d_golden(act_fp32: np.ndarray, layer: dict, weight_file: Path) -> np.ndarray:
    """
    纯 numpy 实现一层 conv（QA + im2col + DCIM + DQA）的 golden 输出（FP32）。

    act_fp32: NHWC FP32 输入激活，shape [H, W, C]
    layer:    从 network.json layers[] 读出的该层 dict
    weight_file: model_xxx_conv.npz 路径
    返回: NHWC FP32 输出激活 [OH, OW, cout]，经过 DQA 和 ReLU
    """
    z = np.load(weight_file)
    w_int8  = z["weight_int8"].astype(np.int32)   # [Cout, Cin, kH, kW]
    act_scale  = float(z["act_scale"])
    dqa_scale  = z["dqa_scale"].astype(np.float32)  # [Cout]
    dqa_bias   = z["dqa_bias"].astype(np.float32)   # [Cout]

    kh   = layer["kernel_h"]
    kw   = layer["kernel_w"]
    sh   = layer["stride"][0]
    sw   = layer["stride"][1]
    ph0, pw0, ph1, pw1 = (layer["padding"][0], layer["padding"][1],
                          layer["padding"][2], layer["padding"][3])
    H, W, Cin = act_fp32.shape
    Cout = layer["out_channels"]
    OH = (H + ph0 + ph1 - kh) // sh + 1
    OW = (W + pw0 + pw1 - kw) // sw + 1

    # QA: FP32 → INT8
    act_q = np.round(act_fp32 / act_scale).clip(-128, 127).astype(np.int8)

    # pad
    act_pad = np.pad(act_q,
                     ((ph0, ph1), (pw0, pw1), (0, 0)),
                     mode='constant').astype(np.int32)

    # im2col + matmul
    out_int32 = np.zeros((OH, OW, Cout), dtype=np.int32)
    for oh in range(OH):
        for ow in range(OW):
            patch = act_pad[oh*sh:oh*sh+kh, ow*sw:ow*sw+kw, :]   # [kH, kW, Cin]
            col   = patch.reshape(-1)                                # [kH*kW*Cin]
            for co in range(Cout):
                out_int32[oh, ow, co] = int(np.dot(w_int8[co].reshape(-1), col))

    # DQA: INT32 → FP32
    out_fp32 = out_int32.astype(np.float32) * dqa_scale[None, None, :] + dqa_bias[None, None, :]

    # ReLU（如果 has_activation）
    if layer.get("has_activation", False):
        out_fp32 = np.maximum(out_fp32, 0)

    return out_fp32


# ---------------------------------------------------------------------------
# FPGA 逐层执行
# ---------------------------------------------------------------------------

def run_layer_on_fpga(
    runner: ChipRunnerWin,
    layer_name: str,
    act_in_fp32: np.ndarray,
    plan_layer: dict,
    dist_dir: Path,
) -> np.ndarray:
    """
    在 FPGA 上运行一层并返回 FP32 输出。

    act_in_fp32: 输入激活 [H, W, Cin] FP32
    plan_layer:  plan.json memory_plan.layers[] 中该层的条目
    dist_dir:    编译器输出目录（含 program.bin, weights.bin, wb.bin）
    返回: FP32 输出激活 [OH, OW, Cout]
    """
    in_off  = int(plan_layer["input_off"])
    out_off = int(plan_layer["output_off"])
    OH, OW  = plan_layer["output_hw"]
    cout    = int(plan_layer["output_c"])

    # 1. 写入 program.bin（完整的逐层 ISA 序列）
    prog_bin = (dist_dir / "program.bin").read_bytes()
    runner.upload_inst_bin(prog_bin)

    # 2. 写入权重（写一次即可，但层间重用时 WB 需刷新）
    weights_bin = (dist_dir / "weights.bin").read_bytes()
    weights_layout = json.loads((dist_dir / "weights_layout.json").read_text())
    wb_bin = (dist_dir / "wb.bin").read_bytes()
    wb_layout = json.loads((dist_dir / "wb_layout.json").read_text())

    # 找到当前层在 weights/wb 中的 offset
    layer_weight_info = weights_layout.get(layer_name, {})
    layer_wb_info = wb_layout.get(layer_name, {})

    if layer_weight_info:
        ibuf_byte_off = int(layer_weight_info["ibuf_byte_off"])
        layer_blob_off = int(layer_weight_info.get("blob_off", 0))
        layer_blob_sz  = int(layer_weight_info["bytes"])
        # 一次性写全部权重到 IBUF（适用于 max-layers 较小的情况）
        runner.x.write(TILE_IBUF_BASE + 0, weights_bin)

    if layer_wb_info:
        wb_byte_off = int(layer_wb_info["wb_byte_off"])
        layer_wb_off = int(layer_wb_info.get("blob_off", 0))
        layer_wb_sz  = int(layer_wb_info["bytes"])
        wb_blob = wb_bin[layer_wb_off: layer_wb_off + layer_wb_sz]
        runner.x.write(WB_BASE + wb_byte_off, wb_blob)

    # 3. 写入输入激活到 VPU_BUF
    H, W, Cin = act_in_fp32.shape
    act_bytes = act_in_fp32.astype(np.float32).tobytes()
    runner.x.write(VPU_BUF_BASE + in_off, act_bytes)

    # 4. 执行并等待完成
    runner.start_and_wait()

    # 5. 读回 FP32 输出激活
    out_nbytes = OH * OW * cout * 4
    raw = runner.x.read(VPU_BUF_BASE + out_off, out_nbytes)
    out_fp32 = np.frombuffer(raw, dtype=np.float32).reshape(OH, OW, cout)
    return out_fp32


# ---------------------------------------------------------------------------
# 主函数
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="YOLOv5n L4 逐层 FPGA 测试")
    ap.add_argument("--max-layers", type=int, default=6,
                    help="编译并测试前 N 层（default: 6）")
    ap.add_argument("--start-layer", type=int, default=2,
                    help="从第几层开始在 FPGA 上跑（0-index，default: 2，跳过 im2col-OH-tiling 未实现的大层）")
    ap.add_argument("--dist", default=None,
                    help="编译器输出目录，默认 tests/chip/dist/yolov5n_{max_layers}layers")
    ap.add_argument("--dry-run", action="store_true",
                    help="只跑 numpy golden，不调用 FPGA（用于验证 golden 本身）")
    args = ap.parse_args()

    dist_dir = Path(args.dist) if args.dist else (
        CHIP / f"dist/yolov5n_{args.max_layers}layers"
    )

    if not dist_dir.exists():
        print(f"[ERROR] dist_dir not found: {dist_dir}")
        print(f"  Run: python tests/chip/compiler/compile.py --network yolov5n "
              f"--out {dist_dir} --max-layers {args.max_layers}")
        sys.exit(1)

    plan = json.loads((dist_dir / "plan.json").read_text())
    mem_layers = {L["name"]: L for L in plan["memory_plan"]["layers"]}

    network = json.loads((REPO / "model/yolov5n/parsed/network.json").read_text())
    layers_by_name = {L["name"]: L for L in network["layers"]}
    weights_dir = REPO / "model/yolov5n/parsed/weights"

    print(f"\n{'='*60}")
    print(f"YOLOv5n L4 逐层测试 — 前 {args.max_layers} 层")
    print(f"dist_dir: {dist_dir}")
    print(f"start_layer (0-index): {args.start_layer}")
    print(f"{'='*60}\n")

    runner = None if args.dry_run else ChipRunnerWin()

    # 用随机输入模拟 320×320×3 RGB 图像（归一化 FP32）
    np.random.seed(42)
    cur_act = (np.random.randint(0, 256, (320, 320, 3), dtype=np.uint8)
               .astype(np.float32) / 255.0)

    compiled_layer_names = [L["name"] for L in plan["memory_plan"]["layers"]]

    for li, lname in enumerate(compiled_layer_names):
        layer = layers_by_name[lname]
        safe  = lname.replace(".", "_")
        wfile = weights_dir / f"{safe}.npz"

        if not wfile.exists():
            print(f"  [{li}] {lname}: SKIP (no weight file)")
            continue

        plan_layer = mem_layers.get(lname)
        if plan_layer is None:
            print(f"  [{li}] {lname}: SKIP (not in memory plan)")
            continue

        # numpy golden
        golden = conv2d_golden(cur_act, layer, wfile)

        if args.dry_run or li < args.start_layer:
            tag = "golden-only" if args.dry_run else f"skip-fpga(< start_layer={args.start_layer})"
            print(f"  [{li}] {lname:40s} ({tag})")
            print(f"       in={cur_act.shape} out={golden.shape} "
                  f"range=[{golden.min():.3f}, {golden.max():.3f}]")
            cur_act = golden
            continue

        # FPGA 执行
        fpga_out = run_layer_on_fpga(runner, lname, cur_act, plan_layer, dist_dir)

        # 对比
        abs_err = np.abs(fpga_out - golden)
        rel_err = abs_err / (np.abs(golden).mean() + 1e-6)
        passed  = int((abs_err < 0.5).sum())
        total   = int(abs_err.size)
        status  = "PASS" if passed == total else f"FAIL {passed}/{total}"

        print(f"  [{li}] {lname:40s}: {status}  "
              f"max_abs={abs_err.max():.4f} mean_rel={rel_err.mean():.4f}")

        cur_act = golden  # 下一层使用 golden 输入（隔离逐层误差）

    print("\nDone.")


if __name__ == "__main__":
    main()
