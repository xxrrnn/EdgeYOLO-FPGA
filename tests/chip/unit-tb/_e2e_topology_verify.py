"""
端到端拓扑验证：numpy golden vs FPGA 链式执行

用相同随机输入跑两遍网络：
1. numpy golden（numpy_golden_net.py）→ 纯 numpy 计算每层输出
2. FPGA 链式执行（_l4_full_network_test.py 的 dry-run）→ 算子级别验证

比较两者在关键节点的激活值（含 add/concat 拓扑连接），
确保 FPGA 执行流程的层间数据传递与参考网络一致。

注意：dry-run 模式下从 expected.hex 读回的数据包含 DCIM padding 通道（16对齐），
需裁剪到 meta.out_ch 后再比较。
"""
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0, '../../../tools')

import numpy as np
from numpy_golden_net import run_yolov5n_golden
from ops import FPGAOps, HostOps, C3Block
from golden_module_tb import load_network, conv_meta, out_hw

# 使用较小输入图加速测试（320×320 → 缩放到网络实际需要）
H, W = 320, 320
IN_CH = 3
rng = np.random.default_rng(123)
input_img = rng.integers(-128, 128, (H, W, IN_CH), dtype=np.int16).astype(np.int8)

print(f"输入: {input_img.shape} INT8")
print()

# ── 1. numpy golden ──────────────────────────────────────────────────────────
print("=" * 60)
print("Phase 1: 运行 numpy golden 网络...")
print("=" * 60)
golden = run_yolov5n_golden(input_img, verbose=True)
print(f"\n完成，共 {len(golden)} 个关键激活节点")
print()

# ── 2. FPGA dry-run（不上板，读 expected.hex 作为 conv 输出）────────────────
print("=" * 60)
print("Phase 2: 运行 FPGA dry-run 链式执行...")
print("=" * 60)

fpga = FPGAOps(runner=None, runs_base='./runs/e2e_verify', verbose=True)
host = HostOps()
net = load_network('../../../model/yolov5n/parsed/network.json')


def _conv(name, feat, case):
    m = conv_meta(net, name)
    h, w, _ = feat.shape
    oh, ow = out_hw(h, w, m)
    ibuf_act = 4 * 512 * 16
    max_pix = max(1, ibuf_act // (m.acc_depth * 16))
    if m.out_ch > 128:
        return fpga.conv_tiled(feat, name, case_name=case)
    elif oh * ow > max_pix:
        return fpga.conv_oh_tiled(feat, name, case_name=case, max_pixels=max_pix)
    else:
        return fpga.conv(feat, name, case_name=case)


def _c3(mid, feat, n):
    block = C3Block(fpga, host, mid, n_bottleneck=n)
    return block(feat)


# 逐层执行
fpga_acts = {}

x = input_img
x = _conv("model.0.conv", x, "e2e_m0")
fpga_acts["model.0.conv"] = x

x = _conv("model.1.conv", x, "e2e_m1")
fpga_acts["model.1.conv"] = x

x = _c3("2", x, n=1)
fpga_acts["model.2"] = x

x = _conv("model.3.conv", x, "e2e_m3")
fpga_acts["model.3.conv"] = x

x = _c3("4", x, n=2)
fpga_acts["model.4"] = x

x = _conv("model.5.conv", x, "e2e_m5")
fpga_acts["model.5.conv"] = x

x = _c3("6", x, n=3)
fpga_acts["model.6"] = x

x = _conv("model.7.conv", x, "e2e_m7")
fpga_acts["model.7.conv"] = x

x8 = _c3("8", x, n=1)
fpga_acts["model.8"] = x8

# SPPF
cv1 = _conv("model.9.cv1.conv", x8, "e2e_sppf_cv1")
fpga_acts["model.9.cv1.conv"] = cv1
mp1 = host.maxpool(cv1, k=5)
mp2 = host.maxpool(mp1, k=5)
mp3 = host.maxpool(mp2, k=5)
sppf_cat = host.concat([cv1, mp1, mp2, mp3])
cv2 = _conv("model.9.cv2.conv", sppf_cat, "e2e_sppf_cv2")
fpga_acts["model.9.cv2.conv"] = cv2

x10 = _conv("model.10.conv", cv2, "e2e_m10")
fpga_acts["model.10.conv"] = x10

# Neck FPN
x_up1 = host.upsample(x10, scale=2)
cat_6 = host.concat([x_up1, fpga_acts["model.6"]])
x13 = _c3("13", cat_6, n=1)
fpga_acts["model.13"] = x13

x14 = _conv("model.14.conv", x13, "e2e_m14")
fpga_acts["model.14.conv"] = x14

x_up2 = host.upsample(x14, scale=2)
cat_4 = host.concat([x_up2, fpga_acts["model.4"]])
x17 = _c3("17", cat_4, n=1)
fpga_acts["model.17"] = x17

# Neck PAN
x18 = _conv("model.18.conv", x17, "e2e_m18")
fpga_acts["model.18.conv"] = x18
cat_13 = host.concat([x18, x13])
x20 = _c3("20", cat_13, n=1)
fpga_acts["model.20"] = x20

x21 = _conv("model.21.conv", x20, "e2e_m21")
fpga_acts["model.21.conv"] = x21
cat_8 = host.concat([x21, x8])
x23 = _c3("23", cat_8, n=1)
fpga_acts["model.23"] = x23

print(f"\nFPGA dry-run 完成，共 {len(fpga_acts)} 个关键激活节点")
print()

# ── 3. 逐层比较 ───────────────────────────────────────────────────────────────
print("=" * 60)
print("Phase 3: 端到端逐层比较（numpy golden vs FPGA dry-run）")
print("=" * 60)

compare_keys = [
    "model.0.conv", "model.1.conv", "model.2",
    "model.3.conv", "model.4", "model.5.conv",
    "model.6", "model.7.conv", "model.8",
    "model.9.cv1.conv", "model.9.cv2.conv", "model.10.conv",
    "model.13", "model.14.conv", "model.17",
    "model.18.conv", "model.20", "model.21.conv", "model.23",
]

all_pass = True
for key in compare_keys:
    g = golden.get(key)
    f = fpga_acts.get(key)
    if g is None:
        print(f"  [SKIP] {key}: golden 无此键")
        continue
    if f is None:
        print(f"  [SKIP] {key}: fpga 无此键")
        continue

    # FPGA 输出可能有 16-ch padding，裁剪到 golden 的 channel 数
    gc = g.shape[-1]
    f_trim = f[:, :, :gc] if f.shape[-1] > gc else f

    if g.shape != f_trim.shape:
        print(f"  [FAIL] {key}: shape 不匹配 golden={g.shape} fpga={f_trim.shape}")
        all_pass = False
        continue

    match = np.array_equal(g, f_trim)
    if match:
        print(f"  [PASS] {key}: {g.shape} 数值完全一致")
    else:
        diff = np.abs(g.astype(np.int16) - f_trim.astype(np.int16))
        n_diff = np.count_nonzero(diff)
        print(f"  [FAIL] {key}: {g.shape} 有 {n_diff}/{g.size} 元素不同, max_diff={diff.max()}")
        all_pass = False

print()
if all_pass:
    print("✓ 所有层数值完全一致！拓扑验证 PASS")
else:
    print("✗ 存在不一致层，需检查拓扑连接")
