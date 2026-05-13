#!/usr/bin/env python3
"""
VPU（PE/DCIM）+ XDMA + CDMA：global BRAM → CDMA → PE ibuf → 运算 → obuf → CDMA → global BRAM。

仓库里尚无单独名为「VPU」的 RTL，计算阵列即 rtl/xdma_dcim_bram 中的 PE_bd。
本脚本硬件路径对齐 tests/xdma_dcim_bram/rw_test.ipynb（GPIO + CDMA 地址映射）。
比特流亦可使用 scripts/vpu/run.tcl 生成的 build/vpu（与 xdma_dcim_bram 同一 RTL）。

硬件限制（当前 DCIM tile）：权重形状固定为 int8 (16, 8)，激活块为 (N, 16)。
因此完整 3×3 im2col（K_dim=144）无法单次 GEMM，这里用 1×1 卷积验证「Host im2col 抽行 + VPU GEMM」
（此时每个输出位置的 im2col 行长度正好为 C_in=16）。

使用:
  python im2col.py                    # Mock：仅用 NumPy golden
  python im2col.py --device /dev/xdma0   # 板卡（需已烧录 VPU/xdma_dcim_bram 等价比特流）
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# xdma_vpu 位于 tests/module（与 Vivado 地址映射一致）
_TESTS_MODULE_DIR = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", "module"))
for _p in (_TESTS_MODULE_DIR, _SCRIPT_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from xdma_vpu import (
    VpuBramSession,
    decode_result_rows,
    golden_int8_matmul,
    pack_activation_rows,
    pack_expected_rows,
    pack_weight_tile,
)

# ============================================================================
# Host 端 im2col（通用）
# ============================================================================


def host_im2col(
    activation: np.ndarray,
    kernel_h: int,
    kernel_w: int,
    padding: int,
    stride: int,
) -> np.ndarray:
    """activation: [C_in, H, W] → im2col 矩阵 [P, K_h*K_w*C_in]，INT8。"""
    C_in, H, W = activation.shape
    output_h = (H + 2 * padding - kernel_h) // stride + 1
    output_w = (W + 2 * padding - kernel_w) // stride + 1
    rows = []
    for r_i in range(output_h):
        for c_i in range(output_w):
            row_parts = []
            for kr_i in range(kernel_h):
                for kc_i in range(kernel_w):
                    ri = r_i * stride + kr_i - padding
                    ci = c_i * stride + kc_i - padding
                    if 0 <= ri < H and 0 <= ci < W:
                        row_parts.append(activation[:, ri, ci])
                    else:
                        row_parts.append(np.zeros(C_in, dtype=np.int8))
            rows.append(np.concatenate(row_parts))
    return np.array(rows, dtype=np.int8)


def conv_weight_to_gemm_tile(weight: np.ndarray) -> np.ndarray:
    """
    weight: [C_out, C_in, 1, 1] int8 → GEMM 右矩阵 [C_in, C_out]（此处 C_out=8）。
    """
    assert weight.ndim == 4 and weight.shape[2:] == (1, 1)
    # W_mat[c_in, c_out] = weight[c_out, c_in, 0, 0]
    return np.transpose(weight[:, :, 0, 0], (1, 0)).astype(np.int8)


def golden_conv1x1_int32(
    weight: np.ndarray,
    activation: np.ndarray,
) -> np.ndarray:
    """1×1：与硬件相同的 int32 矩阵乘 Golden。"""
    W_mat = conv_weight_to_gemm_tile(weight)
    assert W_mat.shape == (16, 8)
    oh, ow = activation.shape[1], activation.shape[2]
    out = np.zeros((oh, ow, 8), dtype=np.int32)
    for r in range(oh):
        for c in range(ow):
            row = activation[:, r, c].astype(np.int8).reshape(1, 16)
            out[r, c] = golden_int8_matmul(row, W_mat, acc=0)[0]
    return out


def run_conv1x1_vpu_mock(weight: np.ndarray, activation: np.ndarray) -> np.ndarray:
    return golden_conv1x1_int32(weight, activation)


def run_conv1x1_vpu_hw(sess: VpuBramSession, weight: np.ndarray, activation: np.ndarray) -> np.ndarray:
    W_mat = conv_weight_to_gemm_tile(weight)
    wbytes = pack_weight_tile(W_mat)
    oh, ow = activation.shape[1], activation.shape[2]
    out = np.zeros((oh, ow, 8), dtype=np.int32)

    for r in range(oh):
        for c in range(ow):
            row = activation[:, r, c].astype(np.int8).reshape(1, 16)
            act_bytes = pack_activation_rows(row)
            exp = golden_int8_matmul(row, W_mat, acc=0)
            exp_bytes = pack_expected_rows(exp)
            rb = sess.run_case_from_payloads(
                wbytes,
                act_bytes,
                len(exp_bytes),
                raw_rows=1,
                acc=0,
            )
            out[r, c] = decode_result_rows(rb)[0]
    return out


# ============================================================================
# 测试入口
# ============================================================================


def test_vpu_im2col_colocated(device: str) -> None:
    np.random.seed(42)
    C_in, C_out = 16, 8
    H, W = 4, 4
    weight = np.random.randint(-8, 8, size=(C_out, C_in, 1, 1), dtype=np.int8)
    activation = np.random.randint(-64, 64, size=(C_in, H, W), dtype=np.int8)

    print("=" * 70)
    print("VPU（PE）+ CDMA + global BRAM：1×1 卷积 / im2col 验证")
    print("=" * 70)
    print(f"  weight : {weight.shape}, activation: {activation.shape}")

    im2c = host_im2col(activation, 1, 1, 0, 1)
    assert im2c.shape == (H * W, C_in)

    gold = golden_conv1x1_int32(weight, activation)

    if not device:
        print("\n[Mock] 无 --device，跳过 DMA/CDMA，仅 NumPy golden")
        hw = run_conv1x1_vpu_mock(weight, activation)
    else:
        print(f"\n[硬件] XDMA={device}，流程：global BRAM → CDMA → ibuf → VPU → obuf → …")
        with VpuBramSession(device) as sess:
            hw = run_conv1x1_vpu_hw(sess, weight, activation)

    diff = np.abs(hw.astype(np.int64) - gold.astype(np.int64))
    max_abs = int(diff.max())
    print(f"\n[结果] max |hw - golden| = {max_abs}")
    if max_abs != 0:
        print("❌ 数值不一致")
        idx = np.unravel_index(int(np.argmax(diff)), diff.shape)
        print(f"   最大误差位置 {idx}: hw={hw[idx]}, gold={gold[idx]}")
        sys.exit(1)
    print("✅ 通过：硬件输出与 Golden int32 一致")


def main() -> None:
    ap = argparse.ArgumentParser(description="VPU + CDMA + im2col（1×1 tile 约束）")
    ap.add_argument(
        "--device",
        default="",
        help="例如 /dev/xdma0；留空则仅 Mock",
    )
    args = ap.parse_args()
    try:
        test_vpu_im2col_colocated(args.device)
    except Exception as e:
        print(f"\n❌ 失败: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
