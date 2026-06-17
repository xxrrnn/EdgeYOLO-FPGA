"""
_cout_tiling_test.py  ——  cout-tiling 单算子验证（数值级别）

验证 model.7.conv (128→256, k=3, s=2) 的 2-pass cout-tiling：
  tile0: weights[0:128]   → output ch[0:128]
  tile1: weights[128:256] → output ch[128:255]

比较机制说明
-----------
比对在 FPGA 内 run_case 中进行（逐 16-byte word 精确比对）：
  - expected.hex 中每个 128-bit word 以 FPGA 写入顺序（big-endian 128 位）存储
  - run_case 从 VPU_BUF 读 FPGA 原始字节后做相同的 word-level 比对
  - PASS N/N 意味着 N 个 128-bit word 与 numpy golden 完全一致（字节级精确）

用法:
    python _cout_tiling_test.py           # dry-run（仅生成 golden，不上 FPGA）
    python _cout_tiling_test.py --fpga    # FPGA 执行 + word-level 精确比对
"""
import sys, argparse, numpy as np
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ops import FPGAOps, _net
from golden_module_tb import conv_meta, make_conv_pipeline_case, write_inst
from golden_module_tb import bytes_to_128_words, write_hex as _write_hex

ap = argparse.ArgumentParser()
ap.add_argument("--fpga", action="store_true", help="在 FPGA 上执行（需已连接设备）")
args = ap.parse_args()

runner = None
if args.fpga:
    from xdma_win import ChipRunnerWin
    runner = ChipRunnerWin(verbose=True)

RUNS_BASE = Path("./runs/cout_tiling")
RUNS_BASE.mkdir(parents=True, exist_ok=True)
mode = "FPGA" if args.fpga else "dry-run"

print(f"\n=== cout-tiling 验证 [{mode}]: model.7.conv (128→256) ===\n")

# ── 固定同一输入激活，两个 pass 使用相同数据 ──────────────────────────
H, W = 4, 4
feat_in = np.random.default_rng(7).integers(-128, 128, (H, W, 128),
                                             dtype=np.int16).astype(np.int8)
meta = conv_meta(_net(), "model.7.conv")
oh = (H + 2*meta.pad_h0 - meta.kh) // meta.stride_h + 1
ow = (W + 2*meta.pad_w0 - meta.kw) // meta.stride_w + 1

all_pass = True
tile_outs = []

for tile_idx, offset in enumerate([0, 128]):
    print(f"--- tile{tile_idx}  ch[{offset}:{offset+128}] ---")
    case_name = f"model7_tile{tile_idx}"
    run_dir = RUNS_BASE / case_name
    run_dir.mkdir(parents=True, exist_ok=True)

    spec = {
        "name": case_name, "layer": "model.7.conv", "in_hw": (H, W),
        "out_ch_limit": 128, "out_ch_offset": offset,
    }
    md = make_conv_pipeline_case(str(run_dir), _net(), spec,
                                 np.random.default_rng(7), feat=feat_in)
    write_inst(str(run_dir / "inst.hex"), md["fast_inst"])
    (run_dir / "checks.txt").write_text(
        f"{case_name} expected.hex {md['dst']:06x} {md['words']} 0\n"
    )
    wb = md.get("wb", b"")
    if wb:
        _write_hex(str(run_dir / "wb_init.hex"), bytes_to_128_words(wb))
        pf = run_dir / "preload.txt"
        txt = pf.read_text() if pf.exists() else ""
        if "wb_init.hex" not in txt:
            with open(pf, "a") as f:
                f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

    if runner is not None:
        # FPGA 执行：run_case 内部做 word-level 精确比对（expected.hex vs VPU_BUF）
        results = runner.run_case(run_dir, staging="hbm")
        r = results[0]
        passed = r.get("passed", 0)
        total  = r.get("total_words", 0)
        ok     = r.get("pass", False)
        print(f"  {'PASS ✓' if ok else 'FAIL ✗'}  {passed}/{total} words（字节级精确）")
        if r.get("first_mismatch"):
            print(f"  首个不匹配: {r['first_mismatch']}")
        if not ok:
            all_pass = False

        # 读 VPU_BUF 得到 INT8 原始输出（供下游拼接使用）
        from xdma_win import VPU_BUF_BASE
        raw = runner.x.read(VPU_BUF_BASE + md["dst"], md["words"] * 16)
        tile_out = np.frombuffer(raw, dtype=np.int8).reshape(oh, ow, 128)
        tile_outs.append(tile_out)
    else:
        print(f"  [dry-run] golden 已生成: {run_dir/'expected.hex'}")
        # 读 expected.hex：注意其中每 16B word 是 bytes_to_128_words 存储格式
        # 为还原 HWC 顺序，需要逐 word 反转
        exp_raw = b"".join(bytes.fromhex(l.strip())
                           for l in open(run_dir / "expected.hex"))
        n = oh * ow * 128
        blob = bytearray(n)
        for w in range(md["words"]):
            word_bytes = exp_raw[w*16:(w+1)*16]
            blob[w*16:(w+1)*16] = bytes(reversed(word_bytes))
        tile_out = np.frombuffer(bytes(blob), dtype=np.int8).reshape(oh, ow, 128)
        tile_outs.append(tile_out)

# ── 合并 tile0 + tile1 → 完整 256ch ─────────────────────────────────
print(f"\n--- 合并验证: model.7.conv 完整 256ch ---")
if len(tile_outs) == 2:
    combined = np.concatenate([tile_outs[0][:,:,:128], tile_outs[1][:,:,:128]], axis=-1)
    print(f"  合并后 shape: {combined.shape}  (期望 ({oh},{ow},256))")
    assert combined.shape == (oh, ow, 256), f"shape 错误: {combined.shape}"
    print(f"  {'PASS ✓' if all_pass else 'FAIL ✗'}  256ch 合并成功")
    if runner is not None:
        print(f"  tile0[0,0,:4]: {tile_outs[0][0,0,:4].tolist()}")
        print(f"  tile1[0,0,:4]: {tile_outs[1][0,0,:4].tolist()}")

print(f"\n=== 汇总 [{mode}] ===")
if runner is None:
    print(f"  dry-run: 所有 tile golden 已生成")
else:
    print(f"  cout-tiling: {'ALL PASS ✓' if all_pass else 'FAIL ✗'}")
    print()
    print("比较说明：PASS N/N words = N 个 128-bit word 与 numpy golden 字节级精确匹配")
    print("（VPU_BUF 原始字节 vs int8_hwc_words 写入的 expected.hex，均为 FPGA 写入格式）")
