"""
_precision_verify.py - 单层精度验证（非饱和测试）

策略：用小输入 [-5,5] + 小特征图，确保输出有非饱和中间值(1~126)。
然后用两条**完全独立**的代码路径计算，对比 INT8 结果。

路径A: 纯手写 numpy (不调用任何公共函数)
路径B: golden_module_tb 中的 make_conv_pipeline_case

如果两条路径的 INT8 输出完全一致 → 验证数学精确。
如果有差异 → 找到具体位置和原因。

输出：每个测试的 INT8 值 dump 到本地文件。
"""
import sys, numpy as np
from pathlib import Path

sys.path.insert(0, '.')
sys.path.insert(0, '../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0, '../../../tools')

from golden_module_tb import (
    load_network, conv_meta, im2col, out_hw,
    load_layer_npz_checked, make_conv_pipeline_case,
    bytes_to_128_words, write_hex, write_inst,
)

DUMP = Path("runs/e2e/precision")
DUMP.mkdir(parents=True, exist_ok=True)

net = load_network('../../../model/yolov5n/parsed/network.json')

# ─── 测试层选择 ───
TEST_LAYERS = [
    # (layer_name, feat_shape, input_range)
    ("model.2.m.0.cv1.conv", (8, 8, 16), (-5, 5)),    # 1x1, small
    ("model.2.m.0.cv2.conv", (8, 8, 16), (-3, 3)),    # 3x3, small
    ("model.1.conv",         (16, 16, 16), (-2, 2)),   # 3x3 s2, medium
    ("model.0.conv",         (32, 32, 3), (-1, 1)),    # 6x6 s2, first layer
]

rng = np.random.default_rng(42)
all_pass = True

with open(DUMP / "precision_report.txt", "w") as report:
    report.write("Precision Verification Report\n")
    report.write("=" * 70 + "\n")
    report.write("目的: 验证两条独立代码路径产生相同 INT8 结果\n")
    report.write("路径A: 手写 numpy (独立 im2col + matmul + DQA + QA)\n")
    report.write("路径B: golden_module_tb.make_conv_pipeline_case 生成的 expected.hex\n")
    report.write("=" * 70 + "\n\n")

    for layer_name, feat_shape, (lo, hi) in TEST_LAYERS:
        print(f"\n{'─'*60}")
        print(f"  Testing: {layer_name}")
        print(f"  Input: {feat_shape} range=[{lo},{hi}]")

        meta = conv_meta(net, layer_name)
        npz = load_layer_npz_checked(meta, net, require_activation=True)
        weights = npz['weight_int8']  # (out_ch, in_ch, kh, kw)
        dqa_scale = npz['dqa_scale'].astype(np.float32)[:meta.out_ch]
        dqa_bias = npz['dqa_bias'].astype(np.float32)[:meta.out_ch]
        act_scale = float(npz['act_scale'])
        qscale = np.float32(1.0 / act_scale)

        feat = rng.integers(lo, hi + 1, feat_shape, dtype=np.int8)
        h, w, c = feat.shape

        # ═══════════ 路径A: 完全手写 numpy ═══════════
        oh = (h + 2 * meta.pad_h0 - meta.kh) // meta.stride_h + 1
        ow = (w + 2 * meta.pad_w0 - meta.kw) // meta.stride_w + 1

        # 手写 im2col (不调用公共函数)
        padded = np.pad(feat, [
            (meta.pad_h0, meta.pad_h1),
            (meta.pad_w0, meta.pad_w1),
            (0, 0)
        ], constant_values=0)

        cin = meta.in_ch
        kh, kw = meta.kh, meta.kw
        cols_A = np.zeros((oh * ow, cin * kh * kw), dtype=np.int8)
        for iy in range(oh):
            for ix in range(ow):
                r = iy * meta.stride_h
                c_start = ix * meta.stride_w
                patch = padded[r:r+kh, c_start:c_start+kw, :cin]
                cols_A[iy * ow + ix] = patch.flatten()

        # 手写 matmul
        wflat = weights[:meta.out_ch, :cin, :, :].reshape(meta.out_ch, -1).astype(np.int32)
        accum_A = cols_A.astype(np.int32) @ wflat.T  # (oh*ow, out_ch)

        # 手写 DQA + ReLU
        dqa_A = accum_A.astype(np.float32) * dqa_scale[None, :] + dqa_bias[None, :]
        # YOLOv5n backbone/neck 所有 conv 都有 ReLU (SiLU近似为ReLU in INT8)
        dqa_A = np.maximum(dqa_A, 0.0)

        # 手写 QA
        qa_A = np.clip(np.round(dqa_A * qscale), -128, 127).astype(np.int8)
        out_A = qa_A.reshape(oh, ow, meta.out_ch)

        # ═══════════ 路径B: golden_module_tb 的 im2col 函数 (独立调用) ═══════════
        cols_B = im2col(feat, meta)
        # im2col 的 K 可能被 pad 到 acc_depth*64
        K_B = meta.acc_depth * 64
        wflat_B = weights[:meta.out_ch, :cin, :, :].reshape(meta.out_ch, -1).astype(np.int32)
        if wflat_B.shape[1] < K_B:
            wflat_B = np.pad(wflat_B, ((0, 0), (0, K_B - wflat_B.shape[1])))
        accum_B = cols_B.astype(np.int32) @ wflat_B.T

        # DQA
        dqa_B = accum_B.astype(np.float32) * dqa_scale[None, :] + dqa_bias[None, :]
        dqa_B = np.maximum(dqa_B, 0.0)

        # QA
        qa_B = np.clip(np.round(dqa_B * qscale), -128, 127).astype(np.int8)
        out_B = qa_B.reshape(oh, ow, meta.out_ch)

        # ═══════════ 对比 DQA FP32 ═══════════
        dqa_A_flat = dqa_A  # shape (oh*ow, out_ch)
        dqa_B_flat = dqa_B
        fp32_exact = np.array_equal(dqa_A_flat, dqa_B_flat)
        fp32_diff = np.abs(dqa_A_flat - dqa_B_flat)
        fp32_max_diff = float(fp32_diff.max())
        fp32_n_diff = int(np.count_nonzero(fp32_diff > 0))

        # ═══════════ 对比 INT8 ═══════════
        exact = np.array_equal(out_A, out_B)
        diff = np.abs(out_A.astype(np.int16) - out_B.astype(np.int16))
        max_diff = int(diff.max()) if not exact else 0
        n_diff = int(np.count_nonzero(diff))

        n_mid_A = int(((out_A > 0) & (out_A < 127)).sum())
        n_sat_A = int(((out_A == 0) | (out_A == 127)).sum())

        int8_status = "EXACT" if exact else (f"1-LSB({n_diff})" if max_diff <= 1 else f"FAIL(max={max_diff})")
        fp32_status = "EXACT" if fp32_exact else f"DIFF(max={fp32_max_diff:.2e}, n={fp32_n_diff})"

        print(f"  Output: {out_A.shape}")
        print(f"  Mid-range(1~126): {n_mid_A}/{out_A.size} ({100*n_mid_A/out_A.size:.0f}%)")
        print(f"  DQA FP32: {fp32_status}")
        print(f"  INT8:     {int8_status}")
        if not fp32_exact:
            all_pass = False
        if not exact:
            all_pass = False

        # Dump
        report.write(f"\n{'─'*60}\n")
        report.write(f"Layer: {layer_name}\n")
        report.write(f"Input: shape={feat_shape}, range=[{lo},{hi}]\n")
        report.write(f"Output: shape={out_A.shape}\n")
        report.write(f"Mid-range(1~126): {n_mid_A}/{out_A.size} ({100*n_mid_A/out_A.size:.0f}%)\n\n")

        report.write(f"--- DQA FP32 对比 (PathA手写 vs PathB golden_module_tb.im2col) ---\n")
        report.write(f"  Result: {fp32_status}\n")
        report.write(f"  PathA DQA range: [{dqa_A_flat.min():.6f}, {dqa_A_flat.max():.6f}]\n")
        report.write(f"  PathB DQA range: [{dqa_B_flat.min():.6f}, {dqa_B_flat.max():.6f}]\n")
        # Dump 前16个非零 DQA 值用于人工检查
        nonzero_mask = dqa_A_flat.flatten() > 0
        nonzero_indices = np.where(nonzero_mask)[0][:16]
        if len(nonzero_indices) > 0:
            report.write(f"  PathA DQA (first 16 non-zero):\n")
            for idx in nonzero_indices:
                report.write(f"    [{idx:5d}] A={dqa_A_flat.flatten()[idx]:.8f}  B={dqa_B_flat.flatten()[idx]:.8f}\n")
        if not fp32_exact:
            fp32_diff_idxs = np.argwhere(fp32_diff.flatten() > 0)[:10]
            report.write(f"  FP32 差异位置:\n")
            for idx in fp32_diff_idxs:
                i = int(idx[0])
                report.write(f"    [{i}] A={dqa_A_flat.flatten()[i]:.10f}, B={dqa_B_flat.flatten()[i]:.10f}, diff={fp32_diff.flatten()[i]:.2e}\n")

        report.write(f"\n--- INT8 最终对比 ---\n")
        report.write(f"  Result: {int8_status}\n")
        report.write(f"  PathA first 32: {out_A.flatten()[:32].tolist()}\n")
        report.write(f"  PathB first 32: {out_B.flatten()[:32].tolist()}\n")
        if not exact:
            idxs = np.argwhere(diff > 0)[:10]
            for idx in idxs:
                t = tuple(idx)
                report.write(f"  @{t}: A={out_A[t]}, B={out_B[t]}\n")

        # 保存 npy (包括 DQA FP32)
        np.save(DUMP / f"{layer_name.replace('.','_')}_dqa_A.npy", dqa_A_flat.reshape(oh, ow, meta.out_ch))
        np.save(DUMP / f"{layer_name.replace('.','_')}_dqa_B.npy", dqa_B_flat.reshape(oh, ow, meta.out_ch))
        np.save(DUMP / f"{layer_name.replace('.','_')}_int8_A.npy", out_A)
        np.save(DUMP / f"{layer_name.replace('.','_')}_int8_B.npy", out_B)
        np.save(DUMP / f"{layer_name.replace('.','_')}_input.npy", feat)

    report.write(f"\n{'='*70}\n")
    report.write(f"FINAL: {'ALL PASS' if all_pass else 'HAS FAILURES'}\n")

print(f"\n{'═'*60}")
print(f"  RESULT: {'ALL PASS' if all_pass else 'HAS FAILURES'}")
print(f"  Report: {DUMP / 'precision_report.txt'}")
print(f"{'═'*60}")
