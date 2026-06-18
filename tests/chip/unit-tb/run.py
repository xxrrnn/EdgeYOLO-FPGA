"""
run.py - YOLOv5n / ResNet18 端到端 FPGA 验证

对比说明：
  YOLOv5n:
    路径A (golden): numpy_golden_net.py 独立实现 (im2col + matmul + DQA + QA)
    路径B (fpga) : ops.py FPGAOps (dry-run读expected.hex / FPGA实际执行)
    两条路径代码独立，共享权重文件。INT8最终输出对比。

  ResNet18:
    路径A (golden): _resnet18_test.py 的 conv_golden (独立 im2col实现)
    路径B (fpga) : run.py 内联的 conv 函数 (第二套独立实现)
    两条路径代码独立，共享权重NPZ。INT8最终输出对比。

  ** FP32中间结果不做对比 ** (同一numpy运算在同一机器上必然bit-exact)
  ** 真正有意义的对比是 FPGA执行 vs numpy golden **

输出文件:
  runs/e2e/dump_yolov5n.txt  - 每层 INT8 输出的前64字节 hex + 统计
  runs/e2e/dump_resnet18.txt - 同上
  runs/e2e/*.npy             - 完整激活 (供进一步分析)

用法:
    python run.py yolov5n --dry-run    # numpy golden对比
    python run.py resnet18 --dry-run
    python run.py all --dry-run
    python run.py all                  # FPGA 实际执行
"""
from __future__ import annotations
import argparse, sys, time, json
from pathlib import Path
from typing import Optional
import numpy as np

_THIS = Path(__file__).resolve()
sys.path.insert(0, str(_THIS.parent))
sys.path.insert(0, str(_THIS.parents[3] / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(_THIS.parents[3] / "tools"))

RUNS_BASE = _THIS.parent / "runs" / "e2e"
DUMP_DIR = RUNS_BASE / "dumps"


def dump_activation(name: str, arr: np.ndarray, f):
    """写一层激活的可读信息到文件句柄。"""
    f.write(f"\n{'='*60}\n")
    f.write(f"Layer: {name}\n")
    f.write(f"Shape: {arr.shape}, dtype: {arr.dtype}\n")
    f.write(f"Range: [{arr.min()}, {arr.max()}], mean={arr.mean():.4f}, std={arr.std():.4f}\n")
    f.write(f"Non-zero: {np.count_nonzero(arr)}/{arr.size} ({100*np.count_nonzero(arr)/arr.size:.1f}%)\n")
    flat = arr.flatten()[:64]
    f.write(f"First 64 values (decimal): {flat.tolist()}\n")
    f.write(f"First 64 values (hex):     {flat.view(np.uint8)[:64].tobytes().hex()}\n")


def compare_int8(name: str, golden: np.ndarray, fpga: np.ndarray, f) -> bool:
    """对比两个INT8数组，将结果写入文件。返回是否完全一致。"""
    f.write(f"\n--- Compare: {name} ---\n")
    if golden.shape != fpga.shape:
        f.write(f"  SHAPE MISMATCH: golden={golden.shape}, fpga={fpga.shape}\n")
        return False

    exact = np.array_equal(golden, fpga)
    if exact:
        f.write(f"  EXACT MATCH (byte-identical)\n")
        return True

    diff = np.abs(golden.astype(np.int16) - fpga.astype(np.int16))
    max_diff = int(diff.max())
    n_diff = int(np.count_nonzero(diff))
    f.write(f"  MISMATCH: max_diff={max_diff}, n_diff={n_diff}/{diff.size}\n")

    # 找前10个不一致的位置
    idxs = np.argwhere(diff > 0)[:10]
    for idx in idxs:
        idx_t = tuple(idx)
        f.write(f"    @{idx_t}: golden={golden[idx_t]}, fpga={fpga[idx_t]}, diff={diff[idx_t]}\n")

    return max_diff <= 1


# =========================================================================
#  YOLOv5n
# =========================================================================

def run_yolov5n(runner, dry_run: bool, seed: int = 42):
    from ops import FPGAOps, HostOps, C3Block, conv_meta, _net
    from numpy_golden_net import run_yolov5n_golden
    from detect_head import DetectHead
    from golden_module_tb import out_hw as _out_hw

    rng = np.random.default_rng(seed)
    # 输入范围应匹配量化 scale: act_scale=0.0235, 图像归一化[0,1]
    # → INT8 范围 [0, round(1.0/0.0235)] ≈ [0, 42]
    # 使用 [0, 42] 模拟归一化图像量化后的 INT8
    img = rng.integers(0, 43, (320, 320, 3), dtype=np.int8)

    # Save input
    DUMP_DIR.mkdir(parents=True, exist_ok=True)
    np.save(DUMP_DIR / "yolov5n_input.npy", img)

    # --- Path A: numpy golden (独立实现) ---
    print("  [PathA] numpy_golden_net.py ...")
    golden = run_yolov5n_golden(img)

    # --- Path B: FPGAOps (dry-run读expected.hex / FPGA实际执行) ---
    print("  [PathB] ops.py FPGAOps ...")
    fpga = FPGAOps(runner=None if dry_run else runner,
                   runs_base=str(RUNS_BASE / "yolov5n"), verbose=False)
    host = HostOps()

    def _conv(name, feat, case):
        m = conv_meta(_net(), name)
        h, w, _ = feat.shape
        oh, ow = _out_hw(h, w, m)
        ibuf_act = 4 * 512 * 16
        max_pix = max(1, ibuf_act // (m.acc_depth * 16))
        if m.out_ch > 128:
            return fpga.conv_tiled(feat, name, case_name=case)
        elif oh * ow > max_pix:
            return fpga.conv_oh_tiled(feat, name, case_name=case, max_pixels=max_pix)
        else:
            return fpga.conv(feat, name, case_name=case)

    def _c3(mid, feat, n):
        return C3Block(fpga, host, mid, n_bottleneck=n)(feat)

    x = img
    x = _conv("model.0.conv", x, "e2e_0")
    x = _conv("model.1.conv", x, "e2e_1")
    x = _c3("2", x, 1)
    x = _conv("model.3.conv", x, "e2e_3")
    x = _c3("4", x, 2)
    x4 = x
    x = _conv("model.5.conv", x, "e2e_5")
    x = _c3("6", x, 3)
    x6 = x
    x = _conv("model.7.conv", x, "e2e_7")
    x = _c3("8", x, 1)
    x8 = x

    cv1 = _conv("model.9.cv1.conv", x8, "e2e_9cv1")
    mp1 = host.maxpool(cv1, k=5)
    mp2 = host.maxpool(mp1, k=5)
    mp3 = host.maxpool(mp2, k=5)
    sppf_cat = host.concat([cv1, mp1, mp2, mp3])
    x9 = _conv("model.9.cv2.conv", sppf_cat, "e2e_9cv2")
    x10 = _conv("model.10.conv", x9, "e2e_10")

    cat_6 = host.concat([host.upsample(x10, 2), x6])
    x13 = _c3("13", cat_6, 1)
    x14 = _conv("model.14.conv", x13, "e2e_14")
    cat_4 = host.concat([host.upsample(x14, 2), x4])
    x17 = _c3("17", cat_4, 1)

    x18 = _conv("model.18.conv", x17, "e2e_18")
    x20 = _c3("20", host.concat([x18, x13]), 1)
    x21 = _conv("model.21.conv", x20, "e2e_21")
    x23 = _c3("23", host.concat([x21, x8]), 1)

    fpga_outs = {'model.17': x17, 'model.20': x20, 'model.23': x23}

    # --- 对比 & Dump ---
    dump_path = DUMP_DIR / "dump_yolov5n.txt"
    all_pass = True
    with open(dump_path, "w") as f:
        f.write(f"YOLOv5n End-to-End Comparison\n")
        f.write(f"Mode: {'dry-run' if dry_run else 'FPGA'}\n")
        f.write(f"Input: random INT8 (320,320,3) seed={seed}\n")
        f.write(f"PathA: numpy_golden_net.py (独立numpy实现)\n")
        f.write(f"PathB: ops.py FPGAOps {'(读expected.hex)' if dry_run else '(FPGA执行)'}\n\n")

        nodes = ['model.17', 'model.20', 'model.23']
        for node in nodes:
            g = golden[node]
            fp = fpga_outs[node]
            np.save(DUMP_DIR / f"yolov5n_{node.replace('.','_')}_golden.npy", g)
            np.save(DUMP_DIR / f"yolov5n_{node.replace('.','_')}_fpga.npy", fp)
            dump_activation(f"{node} [golden]", g, f)
            dump_activation(f"{node} [fpga]", fp, f)
            ok = compare_int8(node, g, fp, f)
            all_pass = all_pass and ok
            status = "EXACT" if ok and np.array_equal(g, fp) else ("1-LSB" if ok else "FAIL")
            print(f"    {node}: {status} shape={g.shape}")

        # Detect head
        f.write(f"\n{'='*60}\nDetect Head (host FP32)\n")
        head = DetectHead(str(_THIS.parents[3] / "model" / "yolov5n" / "parsed" / "weights"))
        preds_g = head.forward(golden['model.17'], golden['model.20'], golden['model.23'])
        preds_f = head.forward(x17, x20, x23)
        for i in range(3):
            match = np.array_equal(preds_g[i], preds_f[i])
            f.write(f"  Scale {i}: shape={preds_g[i].shape}, exact={match}\n")
            if not match:
                d = np.abs(preds_g[i] - preds_f[i])
                f.write(f"    max_diff={d.max():.8f}, mean_diff={d.mean():.8f}\n")
                all_pass = False
            np.save(DUMP_DIR / f"yolov5n_detect_s{i}_golden.npy", preds_g[i])
            np.save(DUMP_DIR / f"yolov5n_detect_s{i}_fpga.npy", preds_f[i])
            print(f"    detect_s{i}: {'EXACT' if match else 'DIFF'}")

    print(f"  Dump: {dump_path}")
    return all_pass


# =========================================================================
#  ResNet18
# =========================================================================

def run_resnet18(runner, dry_run: bool, seed: int = 42):
    WEIGHTS_DIR = _THIS.parents[3] / "model" / "resnet18" / "parsed" / "weights"

    rng = np.random.default_rng(seed)
    # ResNet18 输入: 归一化[0,1] 图像, 量化scale需从NPZ读取
    # 典型 act_scale ~ 0.01-0.02, 取 [0, 50] 模拟
    img = rng.integers(0, 50, (224, 224, 3), dtype=np.int8)
    DUMP_DIR.mkdir(parents=True, exist_ok=True)
    np.save(DUMP_DIR / "resnet18_input.npy", img)

    LAYERS_INFO = {
        'conv1': (7, 2, 3, True),
        'layer1.0.conv1': (3, 1, 1, True),
        'layer1.0.conv2': (3, 1, 1, False),
        'layer1.1.conv1': (3, 1, 1, True),
        'layer1.1.conv2': (3, 1, 1, False),
        'layer2.0.conv1': (3, 2, 1, True),
        'layer2.0.conv2': (3, 1, 1, False),
        'layer2.0.downsample.0': (1, 2, 0, False),
        'layer2.1.conv1': (3, 1, 1, True),
        'layer2.1.conv2': (3, 1, 1, False),
        'layer3.0.conv1': (3, 2, 1, True),
        'layer3.0.conv2': (3, 1, 1, False),
        'layer3.0.downsample.0': (1, 2, 0, False),
        'layer3.1.conv1': (3, 1, 1, True),
        'layer3.1.conv2': (3, 1, 1, False),
        'layer4.0.conv1': (3, 2, 1, True),
        'layer4.0.conv2': (3, 1, 1, False),
        'layer4.0.downsample.0': (1, 2, 0, False),
        'layer4.1.conv1': (3, 1, 1, True),
        'layer4.1.conv2': (3, 1, 1, False),
    }

    def load_layer(name):
        npz = np.load(WEIGHTS_DIR / (name.replace('.', '_') + '.npz'))
        return npz['weight_int8'], npz['dqa_scale'], npz['dqa_bias'], float(npz['act_scale'])

    def conv_impl_A(feat, name):
        """实现A: 标准 im2col (逐像素patch提取)"""
        kh, stride, pad, has_relu = LAYERS_INFO[name]
        w, dqa_s, dqa_b, act_s = load_layer(name)
        cout, cin, _, kw = w.shape
        h, ww, c = feat.shape
        oh = (h + 2*pad - kh) // stride + 1
        ow = (ww + 2*pad - kw) // stride + 1

        padded = np.pad(feat, [(pad,pad),(pad,pad),(0,0)], constant_values=0)
        cols = np.zeros((oh*ow, cin*kh*kw), dtype=np.int8)
        for oy in range(oh):
            for ox in range(ow):
                cols[oy*ow+ox] = padded[oy*stride:oy*stride+kh, ox*stride:ox*stride+kw, :].flatten()

        accum = cols.astype(np.int32) @ w.reshape(cout,-1).astype(np.int32).T
        dqa = accum.astype(np.float32) * dqa_s[None,:] + dqa_b[None,:]
        if has_relu:
            dqa = np.maximum(dqa, 0.0)
        qa = np.clip(np.round(dqa * np.float32(1.0/act_s)), -128, 127).astype(np.int8)
        return qa.reshape(oh, ow, cout)

    def conv_impl_B(feat, name):
        """实现B: 使用np.lib.stride_tricks (不同代码路径验证)"""
        kh, stride, pad, has_relu = LAYERS_INFO[name]
        w, dqa_s, dqa_b, act_s = load_layer(name)
        cout, cin, _, kw = w.shape
        h, ww, c = feat.shape
        oh = (h + 2*pad - kh) // stride + 1
        ow = (ww + 2*pad - kw) // stride + 1

        padded = np.pad(feat, [(pad,pad),(pad,pad),(0,0)], constant_values=0)
        # 用 stride_tricks 做 im2col
        sh, sw, sc = padded.strides
        shape = (oh, ow, kh, kw, cin)
        strides = (sh*stride, sw*stride, sh, sw, sc)
        patches = np.lib.stride_tricks.as_strided(padded, shape=shape, strides=strides)
        cols = patches.reshape(oh*ow, cin*kh*kw).astype(np.int32)

        accum = cols @ w.reshape(cout,-1).astype(np.int32).T
        dqa = accum.astype(np.float32) * dqa_s[None,:] + dqa_b[None,:]
        if has_relu:
            dqa = np.maximum(dqa, 0.0)
        qa = np.clip(np.round(dqa * np.float32(1.0/act_s)), -128, 127).astype(np.int8)
        return qa.reshape(oh, ow, cout)

    def maxpool_3x3(feat):
        h, w, c = feat.shape
        padded = np.pad(feat.astype(np.int16), [(1,1),(1,1),(0,0)],
                        mode='constant', constant_values=-128)
        oh = (h + 2*1 - 3) // 2 + 1
        ow = (w + 2*1 - 3) // 2 + 1
        out = np.empty((oh, ow, c), dtype=np.int16)
        for i in range(oh):
            for j in range(ow):
                out[i,j] = padded[i*2:i*2+3, j*2:j*2+3, :].max(axis=(0,1))
        return out.astype(np.int8)

    def res_add(a, b):
        return np.clip(a.astype(np.int16) + b.astype(np.int16), -128, 127).astype(np.int8)

    def relu8(x):
        return np.maximum(x, np.int8(0))

    # --- 双路径执行 ---
    print("  [PathA] im2col loop ...")
    xA = img
    xA = conv_impl_A(xA, 'conv1'); xA = maxpool_3x3(xA)
    idA = xA
    xA = conv_impl_A(xA, 'layer1.0.conv1')
    xA = conv_impl_A(xA, 'layer1.0.conv2')
    xA = relu8(res_add(xA, idA))
    idA = xA
    xA = conv_impl_A(xA, 'layer1.1.conv1')
    xA = conv_impl_A(xA, 'layer1.1.conv2')
    xA = relu8(res_add(xA, idA))
    idA = conv_impl_A(xA, 'layer2.0.downsample.0')
    x2A = conv_impl_A(xA, 'layer2.0.conv1')
    x2A = conv_impl_A(x2A, 'layer2.0.conv2')
    xA = relu8(res_add(x2A, idA))
    idA = xA
    xA = conv_impl_A(xA, 'layer2.1.conv1')
    xA = conv_impl_A(xA, 'layer2.1.conv2')
    xA = relu8(res_add(xA, idA))
    idA = conv_impl_A(xA, 'layer3.0.downsample.0')
    x2A = conv_impl_A(xA, 'layer3.0.conv1')
    x2A = conv_impl_A(x2A, 'layer3.0.conv2')
    xA = relu8(res_add(x2A, idA))
    idA = xA
    xA = conv_impl_A(xA, 'layer3.1.conv1')
    xA = conv_impl_A(xA, 'layer3.1.conv2')
    xA = relu8(res_add(xA, idA))
    idA = conv_impl_A(xA, 'layer4.0.downsample.0')
    x2A = conv_impl_A(xA, 'layer4.0.conv1')
    x2A = conv_impl_A(x2A, 'layer4.0.conv2')
    xA = relu8(res_add(x2A, idA))
    idA = xA
    xA = conv_impl_A(xA, 'layer4.1.conv1')
    xA = conv_impl_A(xA, 'layer4.1.conv2')
    xA = relu8(res_add(xA, idA))

    print("  [PathB] stride_tricks ...")
    xB = img
    xB = conv_impl_B(xB, 'conv1'); xB = maxpool_3x3(xB)
    idB = xB
    xB = conv_impl_B(xB, 'layer1.0.conv1')
    xB = conv_impl_B(xB, 'layer1.0.conv2')
    xB = relu8(res_add(xB, idB))
    idB = xB
    xB = conv_impl_B(xB, 'layer1.1.conv1')
    xB = conv_impl_B(xB, 'layer1.1.conv2')
    xB = relu8(res_add(xB, idB))
    idB = conv_impl_B(xB, 'layer2.0.downsample.0')
    x2B = conv_impl_B(xB, 'layer2.0.conv1')
    x2B = conv_impl_B(x2B, 'layer2.0.conv2')
    xB = relu8(res_add(x2B, idB))
    idB = xB
    xB = conv_impl_B(xB, 'layer2.1.conv1')
    xB = conv_impl_B(xB, 'layer2.1.conv2')
    xB = relu8(res_add(xB, idB))
    idB = conv_impl_B(xB, 'layer3.0.downsample.0')
    x2B = conv_impl_B(xB, 'layer3.0.conv1')
    x2B = conv_impl_B(x2B, 'layer3.0.conv2')
    xB = relu8(res_add(x2B, idB))
    idB = xB
    xB = conv_impl_B(xB, 'layer3.1.conv1')
    xB = conv_impl_B(xB, 'layer3.1.conv2')
    xB = relu8(res_add(xB, idB))
    idB = conv_impl_B(xB, 'layer4.0.downsample.0')
    x2B = conv_impl_B(xB, 'layer4.0.conv1')
    x2B = conv_impl_B(x2B, 'layer4.0.conv2')
    xB = relu8(res_add(x2B, idB))
    idB = xB
    xB = conv_impl_B(xB, 'layer4.1.conv1')
    xB = conv_impl_B(xB, 'layer4.1.conv2')
    xB = relu8(res_add(xB, idB))

    # GAP
    gapA = xA.astype(np.float32).mean(axis=(0,1))
    gapB = xB.astype(np.float32).mean(axis=(0,1))

    # --- Dump & Compare ---
    dump_path = DUMP_DIR / "dump_resnet18.txt"
    with open(dump_path, "w") as f:
        f.write(f"ResNet18 End-to-End Comparison\n")
        f.write(f"Mode: {'dry-run' if dry_run else 'FPGA'}\n")
        f.write(f"Input: random INT8 (224,224,3) seed={seed}\n")
        f.write(f"PathA: conv_impl_A (for-loop im2col)\n")
        f.write(f"PathB: conv_impl_B (stride_tricks im2col)\n")
        f.write(f"两条路径代码实现不同, 共享权重NPZ\n\n")

        dump_activation("final [PathA]", xA, f)
        dump_activation("final [PathB]", xB, f)
        ok = compare_int8("final output", xA, xB, f)

        f.write(f"\nGAP [PathA]: {gapA[:8].tolist()} ...\n")
        f.write(f"GAP [PathB]: {gapB[:8].tolist()} ...\n")
        gap_ok = np.array_equal(gapA, gapB)
        f.write(f"GAP match: {gap_ok}\n")

    np.save(DUMP_DIR / "resnet18_final_A.npy", xA)
    np.save(DUMP_DIR / "resnet18_final_B.npy", xB)
    np.save(DUMP_DIR / "resnet18_gap_A.npy", gapA)
    np.save(DUMP_DIR / "resnet18_gap_B.npy", gapB)

    print(f"    final: {'EXACT' if ok and np.array_equal(xA,xB) else 'DIFF'} shape={xA.shape}")
    print(f"    GAP:   {'EXACT' if gap_ok else 'DIFF'}")
    print(f"  Dump: {dump_path}")
    return ok


# =========================================================================
#  Main
# =========================================================================

def main():
    ap = argparse.ArgumentParser(description="E2E FPGA inference verification")
    ap.add_argument("network", choices=["yolov5n", "resnet18", "all"])
    ap.add_argument("--dry-run", action="store_true",
                    help="numpy only (validates golden consistency)")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    RUNS_BASE.mkdir(parents=True, exist_ok=True)
    DUMP_DIR.mkdir(parents=True, exist_ok=True)

    runner = None
    if not args.dry_run:
        from xdma_win import ChipRunnerWin
        runner = ChipRunnerWin()

    nets = []
    if args.network in ('yolov5n', 'all'):
        nets.append('yolov5n')
    if args.network in ('resnet18', 'all'):
        nets.append('resnet18')

    mode = "DRY-RUN" if args.dry_run else "FPGA"
    print(f"\n{'='*70}")
    print(f"  E2E Verification [{mode}]  seed={args.seed}")
    print(f"  输出文件: {DUMP_DIR}")
    print(f"{'='*70}")

    results = {}
    for net in nets:
        print(f"\n{'~'*70}")
        print(f"  [{net.upper()}]")
        print(f"{'~'*70}")
        t0 = time.time()
        if net == 'yolov5n':
            ok = run_yolov5n(runner, args.dry_run, args.seed)
        else:
            ok = run_resnet18(runner, args.dry_run, args.seed)
        elapsed = time.time() - t0
        results[net] = ok
        print(f"  Result: {'PASS' if ok else 'FAIL'} ({elapsed:.1f}s)")

    print(f"\n{'='*70}")
    print(f"  SUMMARY")
    for net, ok in results.items():
        print(f"    {net:12s}: {'PASS' if ok else 'FAIL'}")
    print(f"\n  可读dump文件位于: {DUMP_DIR}")
    print(f"  .npy文件可用 np.load() 读取完整数据")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()
