"""
ops.py  ——  YOLOv5n FPGA 算子库（可拼接）

所有算子均已通过片上硬件验证（见 tests/chip/README.md）：
  - conv    : DCIM + im2col_unit + DQA + QA 全链路（L3~L4 PASS）
  - add     : VPU element-wise add INT8（L1 PASS）
  - concat  : channel-wise concat（host numpy，L1 PASS）
  - mp      : MaxPool INT8（L1 PASS，host numpy 模拟）
  - us      : Upsample nearest neighbor（L1 PASS，host numpy 模拟）
  - qa      : FP32 → INT8 量化（host numpy）
  - dqa     : INT32 → FP32 反量化（host numpy，FPGA DQA 单元集成在 conv 内）

使用方法
--------
    from ops import FPGAOps, HostOps

    ops = FPGAOps(runner)           # runner = ChipRunnerWin()
    host = HostOps()                # CPU 算子（add / concat / mp / us）

    # 单层 conv（自动 cout-tiling）
    out = ops.conv(feat, "model.0.conv", case_name="m0")

    # 链式执行
    x = ops.conv(img, "model.0.conv", case_name="net_0")
    x = ops.conv(x,   "model.1.conv", case_name="net_1")
    skip = x
    cv1 = ops.conv(x, "model.2.cv1.conv", case_name="net_2_cv1")
    cv2 = ops.conv(x, "model.2.cv2.conv", case_name="net_2_cv2")
    m0  = ops.conv(cv1, "model.2.m.0.cv1.conv", case_name="net_2_m0cv1")
    m0  = ops.conv(m0,  "model.2.m.0.cv2.conv", case_name="net_2_m0cv2")
    m0  = host.add(cv1, m0)       # shortcut
    cat = host.concat([m0, cv2])
    x   = ops.conv(cat, "model.2.cv3.conv", case_name="net_2_cv3")

数据约定
--------
- 所有激活（包括 FPGA 输出）：INT8 numpy array，shape (H, W, C)
- 所有输出 channel 已截断到真实值（DCIM 16ch 填充部分已去除）
- cout-tiling 在 FPGAOps.conv 内部自动处理（out_ch > 128 自动分 pass）
"""
from __future__ import annotations

import sys
import os
import numpy as np
from pathlib import Path
from typing import Optional

_THIS = Path(__file__).resolve()
_REPO = _THIS.parents[3]
sys.path.insert(0, str(_THIS.parent))
sys.path.insert(0, str(_REPO / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(_REPO / "tools"))

from golden_module_tb import (
    make_conv_pipeline_case, load_network, conv_meta,
    write_inst, bytes_to_128_words, write_hex as _write_hex,
)

# ─── 常量 ──────────────────────────────────────────────────────────────────
_NETWORK_JSON = str(_REPO / "model" / "yolov5n" / "parsed" / "network.json")
_TILE_SIZE    = 128   # 硬件单 pass 最大输出通道数（8 tiles × 16 ch）

_net_cache: Optional[dict] = None

# DCIM hardware bug: when n_tiles * acc_depth >= 2 * DCIM_SRAM_DP (= 256),
# some output tiles produce wrong accumulation results.
# This constrains the maximum safe tile_size (output channels per ctile pass).
#   safe_tile_size = floor(255 / acc_depth) * 16  (rounded down to 16-ch boundary)
# For acc_depth=36: floor(255/36)*16 = 7*16 = 112
# For acc_depth=72: floor(255/72)*16 = 3*16 = 48
# For acc_depth=18: floor(255/18)*16 = 14*16 = 224 → hardware max 128 (8 tiles)
_DCIM_SRAM_DP = 128  # = DCIM_SRAM_DP from chip_config


def _safe_int8_tile_size(acc_depth: int) -> int:
    """Return the largest safe output-channel block size (multiple of 16) for INT8 mode.

    Hardware constraint: n_tiles * acc_depth must be < 2 * DCIM_SRAM_DP (256).
    """
    max_tiles = max(1, (2 * _DCIM_SRAM_DP - 1) // acc_depth)
    return min(max_tiles, 8) * 16  # 8 tiles * 16 ch = 128 is the hardware maximum


def set_network_json(path: str):
    """Switch to a different network.json (e.g. parsed_int16)."""
    global _NETWORK_JSON, _net_cache
    _NETWORK_JSON = path
    _net_cache = None
    import golden_module_tb
    golden_module_tb.WEIGHT_DIR = str(Path(path).parent / "weights")

def _net():
    global _net_cache
    if _net_cache is None:
        _net_cache = load_network(_NETWORK_JSON)
    return _net_cache


# ─── FPGAOps ───────────────────────────────────────────────────────────────

class FPGAOps:
    """FPGA 硬件算子封装。所有 conv 类操作均在 FPGA 上执行。"""

    def __init__(self, runner, runs_base: str = "./runs/ops", verbose: bool = False,
                 verify: bool = True, weight_hbm_map: "dict | None" = None):
        """
        runner          : ChipRunnerWin 实例（None = dry-run 模式，返回 numpy golden）
        runs_base       : 测试 case 文件存放根目录
        verbose         : 是否打印详细信息
        verify          : 若 False，跳过逐层 expected.hex 对比验证（加速推理）
        weight_hbm_map  : 由 runner.preload_all_weights() 返回的预上传权重地址映射
                          {case_name -> {filename -> hbm_abs_offset}}
                          若提供，每次 run_case 跳过权重 PCIe 上传（权重已在 HBM 池中）
        """
        self.runner   = runner
        self.runs_base = Path(runs_base)
        self.verbose  = verbose
        self.verify   = verify
        self._weight_hbm_map = weight_hbm_map or {}
        # Clear the runner weight cache at the start of each FPGAOps session so that
        # stale cache entries from a previous inference run do not cause HBM mismatches.
        # (All layers share HBM_OFF_WEIGHT, so weights from a prior run are gone.)
        if runner is not None and hasattr(runner, 'clear_weight_cache') and not weight_hbm_map:
            runner.clear_weight_cache()

    def conv(
        self,
        feat_in: np.ndarray,
        layer_name: str,
        case_name: str,
        out_ch_limit: int = 0,
        out_ch_offset: int = 0,
        seed: int = 0,
    ) -> np.ndarray:
        """执行单个 conv_pipeline（im2col + DCIM + DQA + QA）。

        feat_in      : INT8 (H, W, C_in)
        layer_name   : 如 "model.0.conv"
        case_name    : run 目录名（唯一标识，如 "net_0"）
        out_ch_limit : 0=不截断；>0=截断到该通道数（cout-tiling 分 pass 时使用）
        out_ch_offset: 输出通道起始偏移（cout-tiling 分 pass 时使用）
        返回: INT8 (OH, OW, C_out)，已去除 DCIM 填充 pad
        """
        run_dir = self.runs_base / case_name
        run_dir.mkdir(parents=True, exist_ok=True)

        h, w, _ = feat_in.shape
        spec: dict = {"name": case_name, "layer": layer_name, "in_hw": (h, w)}
        spec["relu_en"] = bool(_net()[layer_name].get("has_activation", True))
        if out_ch_limit > 0:
            spec["out_ch_limit"] = out_ch_limit
        if out_ch_offset > 0:
            spec["out_ch_offset"] = out_ch_offset

        rng = np.random.default_rng(seed)
        md  = make_conv_pipeline_case(str(run_dir), _net(), spec, rng, feat=feat_in)

        # 写运行时文件
        write_inst(str(run_dir / "inst.hex"), md["fast_inst"])
        (run_dir / "checks.txt").write_text(
            f"{case_name} expected.hex {md['dst']:06x} {md['words']} 0\n"
        )
        wb_data = md.get("wb", b"")
        if wb_data:
            _write_hex(str(run_dir / "wb_init.hex"), bytes_to_128_words(wb_data))
            pf = run_dir / "preload.txt"
            txt = pf.read_text() if pf.exists() else ""
            if "wb_init.hex" not in txt:
                with open(pf, "a") as f:
                    f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

        # 计算输出 shape
        meta    = conv_meta(_net(), layer_name)
        oh      = (h + 2 * meta.pad_h0 - meta.kh) // meta.stride_h + 1
        ow      = (w + 2 * meta.pad_w0 - meta.kw) // meta.stride_w + 1
        eff_cout = meta.out_ch if out_ch_limit <= 0 else min(meta.out_ch - out_ch_offset, out_ch_limit)
        # 对齐粒度：INT16 对齐到 8，INT8 对齐到 16
        import golden_module_tb as _gmt_ec
        _npz_ec = np.load(os.path.join(_gmt_ec.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz'))
        _align_ec = 8 if _npz_ec['weight_int8'].dtype == np.int16 else 16
        eff_ch   = ((eff_cout + _align_ec - 1) // _align_ec) * _align_ec  # DCIM 通道对齐

        if self.verbose:
            print(f"  [{layer_name}] {md['shape']}")

        if self.runner is None:
            # dry-run：从 expected.hex 读出 golden 数据
            import golden_module_tb
            raw_words = [bytes.fromhex(l.strip()) for l in open(run_dir / "expected.hex")]
            raw_bytes = b"".join(bytes(reversed(w)) for w in raw_words)
            # Detect INT16 from weight dtype in NPZ
            npz_path = os.path.join(golden_module_tb.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz')
            read_dtype = np.int16 if np.load(npz_path)['weight_int8'].dtype == np.int16 else np.int8
            exp_flat = np.frombuffer(raw_bytes, dtype=read_dtype)
            try:
                return exp_flat.reshape(oh, ow, eff_ch)
            except ValueError:
                return exp_flat.reshape(oh, ow, exp_flat.size // (oh * ow))

        # FPGA 执行
        w_map = self._weight_hbm_map.get(case_name) if self._weight_hbm_map else None
        results = self.runner.run_case(run_dir, staging="hbm", verify=self.verify,
                                        weight_hbm_map=w_map)
        ok = all(r.get("pass", False) for r in results)
        passed = sum(r.get("passed", 0) for r in results)
        total  = sum(r.get("total_words", 0) for r in results)
        if self.verify and not ok:
            print(f"  [FAIL] {layer_name} {passed}/{total} words")
        elif self.verbose:
            print(f"  [PASS] {layer_name} {total}/{total} words")

        # 从 VPU_BUF 读原始字节，根据 weight dtype 判断 INT8/INT16
        import golden_module_tb
        npz_path = os.path.join(golden_module_tb.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz')
        read_dtype = np.int16 if np.load(npz_path)['weight_int8'].dtype == np.int16 else np.int8
        from xdma_win import VPU_BUF_BASE
        raw = self.runner.x.read(VPU_BUF_BASE + md["dst"], md["words"] * 16)
        got = np.frombuffer(raw, dtype=read_dtype)
        try:
            return got.reshape(oh, ow, eff_ch)
        except ValueError:
            return got

    def conv_tiled(
        self,
        feat_in: np.ndarray,
        layer_name: str,
        case_name: str,
        tile_size: int = _TILE_SIZE,
    ) -> np.ndarray:
        """自动 cout-tiling：out_ch > tile_size 时分多 pass 执行，结果 concat。

        适用于 model.7/8/9/23 等 256-ch 输出层，以及 INT16 模式 128ch 层。
        每个 cout-tile 内部还会自动检查是否需要 oh-tiling。

        DCIM 硬件限制：n_tiles * acc_depth >= 2*DCIM_SRAM_DP (256) 时会产生错误结果。
        INT8 模式下自动将 tile_size 限制为 _safe_int8_tile_size(acc_depth) 以绕过此 bug。
        """
        meta    = conv_meta(_net(), layer_name)
        total_ch = meta.out_ch
        # Check for DCIM hardware bug workaround (INT8 only)
        import golden_module_tb as _gmt_ct
        import os as _os_ct
        _npz_ct = np.load(_os_ct.path.join(_gmt_ct.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz'))
        _is_int16 = _npz_ct['weight_int8'].dtype == np.int16
        if not _is_int16 and tile_size == _TILE_SIZE:
            safe = _safe_int8_tile_size(meta.acc_depth)
            if safe < tile_size:
                tile_size = safe
                if self.verbose:
                    print(f"  [{layer_name}] DCIM tile WA: tile_size→{tile_size} "
                          f"(acc_depth={meta.acc_depth}, constraint n_tiles*acc<256)")
        n_tiles  = (total_ch + tile_size - 1) // tile_size
        h, w, _ = feat_in.shape
        from golden_module_tb import out_hw as _out_hw_ct
        oh, ow = _out_hw_ct(h, w, meta)
        ibuf_act = 4 * 512 * 16
        max_pix = max(1, ibuf_act // (meta.acc_depth * 16))
        if _is_int16:
            max_pix = max(1, ibuf_act // (meta.acc_depth_int16 * 16))
        need_oh_tile = (oh * ow > max_pix)
        # INT16 eff_ch 对齐到 8，INT8 对齐到 16
        align = 8 if _is_int16 else 16
        outputs  = []
        for i in range(n_tiles):
            offset = i * tile_size
            limit  = min(tile_size, total_ch - offset)
            if self.verbose:
                print(f"  [{layer_name}] cout-tile {i}/{n_tiles} ch[{offset}:{offset+limit}]")
            if need_oh_tile:
                out_i = self.conv_oh_tiled(feat_in, layer_name,
                                           case_name=f"{case_name}_ctile{i}",
                                           max_pixels=max_pix,
                                           out_ch_limit=limit,
                                           out_ch_offset=offset)
            else:
                out_i = self.conv(feat_in, layer_name,
                                  case_name=f"{case_name}_ctile{i}",
                                  out_ch_limit=limit, out_ch_offset=offset)
            valid = ((limit + align - 1) // align) * align
            outputs.append(out_i[:, :, :valid])
        full = np.concatenate(outputs, axis=-1)
        return full[:, :, :total_ch]

    def conv_oh_tiled(
        self,
        feat_in: np.ndarray,
        layer_name: str,
        case_name: str,
        max_pixels: int = 400,
        out_ch_limit: int = 0,
        out_ch_offset: int = 0,
    ) -> np.ndarray:
        """OH-tiling：当 oh*ow > max_pixels 时沿 OH 方向分 tile 执行。

        每个 OH tile 独立送入 FPGA，结果按行拼接后返回完整输出。
        适用于 IBUF 容量不足（max_pixels = IBUF_ACT_BYTES / (acc_depth * 16)）的大 feature map。

        max_pixels : IBUF 最大像素数（默认 400，对应 acc=5, in_ch=32 时的安全上限）
        """
        from golden_module_tb import conv_meta as _conv_meta, out_hw, alloc_flat
        import numpy as _np

        meta     = _conv_meta(_net(), layer_name)
        h, w, _  = feat_in.shape
        oh_full, ow = out_hw(h, w, meta)

        # 若不需要 OH-tiling，直接走普通路径
        if oh_full * ow <= max_pixels:
            return self.conv(feat_in, layer_name, case_name,
                             out_ch_limit=out_ch_limit, out_ch_offset=out_ch_offset)

        # 计算每 tile 的 OH 行数，使 tile_oh * ow ≤ max_pixels
        tile_oh = max(1, max_pixels // ow)
        if self.verbose:
            n_tiles = (oh_full + tile_oh - 1) // tile_oh
            print(f"  [{layer_name}] OH-tiling: oh={oh_full} ow={ow} → {n_tiles} tiles (tile_oh={tile_oh})")

        tiles_out = []
        oh_start = 0
        while oh_start < oh_full:
            oh_end = min(oh_start + tile_oh, oh_full)
            tile_cname = f"{case_name}_ohtile{oh_start}"

            run_dir = self.runs_base / tile_cname
            run_dir.mkdir(parents=True, exist_ok=True)

            spec: dict = {
                "name": tile_cname,
                "layer": layer_name,
                "in_hw": (h, w),
                "oh_tile_start": oh_start,
                "oh_tile_end":   oh_end,
                "relu_en": bool(_net()[layer_name].get("has_activation", True)),
            }
            if out_ch_limit > 0:
                spec["out_ch_limit"] = out_ch_limit
            if out_ch_offset > 0:
                spec["out_ch_offset"] = out_ch_offset

            rng = np.random.default_rng(0)
            md  = make_conv_pipeline_case(str(run_dir), _net(), spec, rng, feat=feat_in)

            write_inst(str(run_dir / "inst.hex"), md["fast_inst"])
            tile_words = md["words"]
            (run_dir / "checks.txt").write_text(
                f"{tile_cname} expected.hex {md['dst']:06x} {tile_words} 0\n"
            )
            wb_data = md.get("wb", b"")
            if wb_data:
                _write_hex(str(run_dir / "wb_init.hex"), bytes_to_128_words(wb_data))
                pf = run_dir / "preload.txt"
                txt = pf.read_text() if pf.exists() else ""
                if "wb_init.hex" not in txt:
                    with open(pf, "a") as f:
                        f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

            tile_oh_actual = oh_end - oh_start
            eff_cout = meta.out_ch if out_ch_limit <= 0 else min(meta.out_ch - out_ch_offset, out_ch_limit)
            # 对齐粒度：INT16 对齐到 8，INT8 对齐到 16
            import golden_module_tb as _gmt_eff
            _npz_eff = np.load(os.path.join(_gmt_eff.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz'))
            _align_eff = 8 if _npz_eff['weight_int8'].dtype == np.int16 else 16
            eff_ch   = ((eff_cout + _align_eff - 1) // _align_eff) * _align_eff

            if self.runner is None:
                # dry-run：反转每 16B word 的字节序
                import golden_module_tb
                raw_words = [bytes.fromhex(l.strip()) for l in open(run_dir / "expected.hex")]
                raw_bytes = b"".join(bytes(reversed(w)) for w in raw_words)
                npz_path = os.path.join(golden_module_tb.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz')
                read_dtype = np.int16 if np.load(npz_path)['weight_int8'].dtype == np.int16 else np.int8
                exp_flat = np.frombuffer(raw_bytes, dtype=read_dtype)
                tile_out = exp_flat.reshape(tile_oh_actual, ow, eff_ch)
            else:
                results = self.runner.run_case(run_dir, staging="hbm", verify=self.verify,
                                               weight_hbm_map=self._weight_hbm_map.get(tile_cname))
                ok = all(r.get("pass", False) for r in results)
                passed = sum(r.get("passed", 0) for r in results)
                total  = sum(r.get("total_words", 0) for r in results)
                if self.verify and not ok:
                    print(f"  [FAIL] {layer_name} oh[{oh_start}:{oh_end}] {passed}/{total} words")
                elif self.verbose:
                    print(f"  [PASS] {layer_name} oh[{oh_start}:{oh_end}] {total}/{total} words")

                import golden_module_tb as _gmt
                _npz_path = os.path.join(_gmt.WEIGHT_DIR, layer_name.replace('.', '_') + '.npz')
                _rdtype = np.int16 if np.load(_npz_path)['weight_int8'].dtype == np.int16 else np.int8
                from xdma_win import VPU_BUF_BASE
                raw = self.runner.x.read(VPU_BUF_BASE + md["dst"], tile_words * 16)
                tile_out = np.frombuffer(raw, dtype=_rdtype).reshape(tile_oh_actual, ow, eff_ch)

            tiles_out.append(tile_out)
            oh_start = oh_end

        full = np.concatenate(tiles_out, axis=0)  # (OH, OW, eff_ch)
        return full



class HostOps:
    """Host CPU 算子（add/concat/mp/us/qa）——在 numpy 上执行。

    这些算子已在 L1 硬件验证，此处用于完整网络中连接 FPGA conv 层的中间处理。
    后续可替换为 on-chip 版本（CDMA concat / VPU add）。
    """

    @staticmethod
    def add(a: np.ndarray, b: np.ndarray) -> np.ndarray:
        """逐元素加（饱和截断），对应 YOLOv5 Bottleneck shortcut。"""
        is_int16 = a.dtype == np.int16
        clip_lo, clip_hi = (-32768, 32767) if is_int16 else (-128, 127)
        out_dtype = np.int16 if is_int16 else np.int8
        return np.clip(
            a.astype(np.int32) + b.astype(np.int32), clip_lo, clip_hi
        ).astype(out_dtype)

    @staticmethod
    def concat(feats: list[np.ndarray], axis: int = -1) -> np.ndarray:
        """沿通道轴拼接，对应 YOLOv5 Concat 算子。"""
        return np.concatenate(feats, axis=axis)

    @staticmethod
    def upsample(feat: np.ndarray, scale: int = 2) -> np.ndarray:
        """最近邻上采样（对应 Upsample）。"""
        return np.repeat(np.repeat(feat, scale, axis=0), scale, axis=1)

    @staticmethod
    def maxpool(feat: np.ndarray, k: int = 5) -> np.ndarray:
        """MaxPool（same padding），对应 SPPF 中的 MaxPool。"""
        pad = k // 2
        h, w, c = feat.shape
        is_int16 = feat.dtype == np.int16
        pad_val = -32768 if is_int16 else -128
        padded = np.pad(feat, [(pad, pad), (pad, pad), (0, 0)],
                        mode="constant", constant_values=pad_val)
        out = np.empty((h, w, c), dtype=feat.dtype)
        for i in range(h):
            for j in range(w):
                out[i, j] = padded[i:i+k, j:j+k, :].max(axis=(0, 1))
        return out

    @staticmethod
    def qa(feat_fp: np.ndarray, act_scale: float, int16: bool = False) -> np.ndarray:
        """FP32 → INT8/INT16 量化（网络输入 QA）。"""
        clip_lo, clip_hi = (-32768, 32767) if int16 else (-128, 127)
        out_dtype = np.int16 if int16 else np.int8
        return np.clip(
            np.round(feat_fp / act_scale), clip_lo, clip_hi
        ).astype(out_dtype)

    @staticmethod
    def hard_quant(feat_int8: np.ndarray, src_scale: float, dst_scale: float) -> np.ndarray:
        """INT8 rescale: dequant with src_scale, div by 2, requant with dst_scale.

        Implements the YOLOv5 QAT 'hard_quant(out/2)' for C3 output layers
        (model.17/20/23) that feed into neck downsamples and detect head.
        """
        rescale = src_scale / 2.0 / dst_scale
        return np.clip(np.round(feat_int8.astype(np.float32) * rescale), -128, 127).astype(np.int8)

    @staticmethod
    def dqa(feat_int32: np.ndarray, scale: np.ndarray,
            bias: np.ndarray, relu: bool = True) -> np.ndarray:
        """INT32 → FP32 反量化（逐通道 scale/bias + ReLU）。"""
        fp = feat_int32.astype(np.float32) * scale + bias
        if relu:
            fp = np.maximum(fp, 0.0)
        return fp


# ─── C3Block ───────────────────────────────────────────────────────────────

class C3Block:
    """YOLOv5 C3 block（含 Bottleneck shortcut）。

    结构: input
      ├─ cv1 ─→ [bottleneck × n] ─→ add(shortcut) ─┐
      └─ cv2 ────────────────────────────────────────┤ concat → cv3 → output

    所有 conv 在 FPGA 上执行；add/concat 在 host 执行。
    """

    def __init__(self, fpga_ops: FPGAOps, host_ops: HostOps,
                 model_id: str, n_bottleneck: int = 1):
        self.ops = fpga_ops
        self.host = host_ops
        self.mid = model_id
        self.n   = n_bottleneck

    def __call__(self, feat_in: np.ndarray) -> np.ndarray:
        p = f"model.{self.mid}"
        o = self.ops

        def _conv(name, feat, **kw):
            cname = f"c3_{self.mid}_{name.replace('.','_')}"
            m  = conv_meta(_net(), f"{p}.{name}")
            h, w, _ = feat.shape
            from golden_module_tb import out_hw as _out_hw
            oh, ow = _out_hw(h, w, m)
            # 计算 IBUF 安全容量（acc_depth 决定每像素占 IBUF 行数）
            ibuf_act = 4 * 512 * 16  # 32KB
            max_pix = max(1, ibuf_act // (m.acc_depth * 16))
            # INT16 每 pass 最多 64 ch（8 tiles × 8 ch）
            import golden_module_tb as _gmt_c3
            import os as _os_c3
            _npz_c3 = np.load(os.path.join(_gmt_c3.WEIGHT_DIR, f"{p}.{name}".replace('.', '_') + '.npz'))
            _tile_sz = 64 if _npz_c3['weight_int8'].dtype == np.int16 else _TILE_SIZE
            if m.out_ch > _tile_sz:
                return o.conv_tiled(feat, f"{p}.{name}", case_name=cname, tile_size=_tile_sz)
            elif oh * ow > max_pix:
                return o.conv_oh_tiled(feat, f"{p}.{name}", case_name=cname, max_pixels=max_pix)
            return o.conv(feat, f"{p}.{name}", case_name=cname, **kw)

        cv1 = _conv("cv1.conv", feat_in)
        cv2 = _conv("cv2.conv", feat_in)
        x   = cv1
        for i in range(self.n):
            x = _conv(f"m.{i}.cv1.conv", x)
            x = _conv(f"m.{i}.cv2.conv", x)
        cat = self.host.concat([x, cv2], axis=-1)
        return _conv("cv3.conv", cat)


# ─── 验证函数 ─────────────────────────────────────────────────────────────

def verify_op(
    fpga_ops: FPGAOps,
    layer_name: str,
    case_name: str,
    in_hw: tuple[int, int],
    out_ch_limit: int = 0,
    out_ch_offset: int = 0,
    seed: int = 42,
    verbose: bool = True,
) -> bool:
    """验证单个 conv 算子：FPGA 输出与 numpy golden 字节级精确比对。

    比对在 run_case 内部进行（逐 128-bit word 精确比对）：
      - expected.hex 按 FPGA 写入格式（bytes_to_128_words 反转）存储
      - run_case 从 VPU_BUF 读原始字节后与 expected.hex 做 word-level 比对
      - PASS N/N 意味着 N 个 128-bit word 与 numpy golden 字节级完全一致

    返回 True=PASS，False=FAIL。
    """
    if fpga_ops.runner is None:
        raise ValueError("verify_op 需要 FPGA runner，dry-run 下无法验证")

    meta  = conv_meta(_net(), layer_name)
    h, w  = in_hw
    in_ch = meta.in_ch
    feat  = np.random.default_rng(seed).integers(
        -128, 128, (h, w, in_ch), dtype=np.int16).astype(np.int8)

    if verbose:
        print(f"验证 {layer_name} [{h}×{w}×{in_ch}] "
              f"out_ch_limit={out_ch_limit} out_ch_offset={out_ch_offset}")

    # 生成 case 文件并执行（run_case 内部做精确 word-level 比对）
    run_dir = Path(fpga_ops.runs_base) / case_name
    run_dir.mkdir(parents=True, exist_ok=True)
    spec: dict = {"name": case_name, "layer": layer_name, "in_hw": (h, w)}
    if out_ch_limit > 0:
        spec["out_ch_limit"] = out_ch_limit
    if out_ch_offset > 0:
        spec["out_ch_offset"] = out_ch_offset

    from golden_module_tb import (make_conv_pipeline_case, write_inst,
                                   bytes_to_128_words, write_hex as _wh)
    rng = np.random.default_rng(seed)
    md  = make_conv_pipeline_case(str(run_dir), _net(), spec, rng, feat=feat)
    write_inst(str(run_dir / "inst.hex"), md["fast_inst"])
    (run_dir / "checks.txt").write_text(
        f"{case_name} expected.hex {md['dst']:06x} {md['words']} 0\n"
    )
    wb_data = md.get("wb", b"")
    if wb_data:
        _wh(str(run_dir / "wb_init.hex"), bytes_to_128_words(wb_data))
        pf = run_dir / "preload.txt"
        txt = pf.read_text() if pf.exists() else ""
        if "wb_init.hex" not in txt:
            with open(pf, "a") as f:
                f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

    results = fpga_ops.runner.run_case(run_dir, staging="hbm")
    ok      = all(r.get("pass", False) for r in results)
    passed  = sum(r.get("passed", 0) for r in results)
    total   = sum(r.get("total_words", 0) for r in results)
    status  = "PASS" if ok else "FAIL"
    if verbose or not ok:
        print(f"  {status}  {passed}/{total} words（字节级精确）")
        for r in results:
            if r.get("first_mismatch"):
                print(f"  首个不匹配: {r['first_mismatch']}")
    return ok
