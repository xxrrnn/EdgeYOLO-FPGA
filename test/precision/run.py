"""INT8 / INT16 计算精度上板：随机矩阵乘 + 主机回读 + 当前 top.ltx 波形对照。

当前 bitstream 的 ILA（peak_tops_ila，见 top.ltx）已经接到存内计算阵列：
  probe0 计算掩码，probe1 输入低 32bit，probe2 job 号，
  probe3 相位（INT8 为 0..1，INT16 为 0..3），probe4/5 结果有效与低 32bit。
不必重综合也能用这份 LTX 证明片上走的是 INT8×INT8 还是 INT16×INT16。

在仓库根目录执行::

    python test/precision/run.py --prepare-only
    python test/precision/run.py --mode int8 --seed 20260822
    python test/precision/run.py --mode int16 --seed 20260822

先在 Vivado Lab 打开 top.ltx、Arm ILA，再跑上板命令。产物在
``test/precision/output/``。
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parents[2]
GENERATOR = REPO_ROOT / "project" / "rtl" / "tb" / "lite_bd" / "module_tb" / "golden_module_tb.py"
OUT_ROOT = REPO_ROOT / "test" / "precision" / "output"

CASES = {
    "int8": {
        "name": "precision_int8_random",
        "phases_per_job": 2,
        "mode_code": 6,
        "mode_name": "MODE_INT8",
        "ops": "INT8 × INT8，累加 INT32",
    },
    "int16": {
        "name": "precision_int16_random",
        "phases_per_job": 4,
        "mode_code": 7,
        "mode_name": "MODE_INT16",
        "ops": "INT16 × INT16，累加 INT64",
    },
}


def parse_manifest(run_dir: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in (run_dir / "manifest.txt").read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep:
            out[key.strip()] = value.strip()
    return out


def first_result_low32(run_dir: Path) -> str:
    line = (run_dir / "expected.hex").read_text(encoding="utf-8").splitlines()[0].strip()
    # hex 行是 128bit 大端显示，内存小端，低 32bit 在行尾 8 个十六进制字符
    return "0x" + line[-8:]


def expected_ila(run_dir: Path, mode: str) -> dict:
    info = CASES[mode]
    man = parse_manifest(run_dir)
    jobs = int(man.get("matmul_m", "0"))
    phases = int(info["phases_per_job"])
    return {
        "mode": mode,
        "case": info["name"],
        "ops": info["ops"],
        "dcim_mode_code": info["mode_code"],
        "dcim_mode_name": info["mode_name"],
        "jobs": jobs,
        "phases_per_job": phases,
        "expected_phase_sequence": list(range(phases)) * max(jobs, 1),
        "ila_trigger": "peak_compute_mask == 8'hFF（8 个 tile 全开，与峰值测试同一触发）",
        "waveform_must_show": (
            f"每个 job 的 peak_phase 必须连续走过 0..{phases - 1}，"
            f"然后 job 加 1。这就是片上 {info['ops']} 的相位证据。"
        ),
        "probe5_first_result_low32": first_result_low32(run_dir),
        "shape": man.get("shape"),
        "seed_note": "随机数由 --seed 决定，同一 seed 可复现向量与期望波形。",
    }


def prepare(mode: str, seed: int, out_root: Path) -> Path:
    info = CASES[mode]
    run_dir = out_root / f"{info['name']}_seed{seed}"
    run_dir.mkdir(parents=True, exist_ok=True)
    stale_got = run_dir / "fpga_got.bin"
    if stale_got.exists():
        stale_got.unlink()
    cmd = [
        sys.executable,
        str(GENERATOR),
        "--module", "dcim_matmul",
        "--case", info["name"],
        "--seed", str(seed),
        "--quant", mode,
        "--verify-words", "0",
        "--out-dir", str(run_dir),
    ]
    print("[prepare] " + " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=str(REPO_ROOT), check=True)
    if not (run_dir / "expected.hex").is_file():
        raise FileNotFoundError(f"case was skipped or incomplete: {run_dir}")
    ila = expected_ila(run_dir, mode)
    (run_dir / "expected_ila.json").write_text(
        json.dumps(ila, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"[prepare] {mode}: {ila['shape']}")
    print(f"[prepare] ILA: 每 job {ila['phases_per_job']} 拍，"
          f"probe5 首结果低32bit={ila['probe5_first_result_low32']}")
    return run_dir


def _fmt_hex(value: int, bits: int) -> str:
    mask = (1 << bits) - 1
    width = bits // 4
    return f"0x{(int(value) & mask):0{width}x}"


def unpack_obuf(raw: bytes, m: int, n: int, int16: bool) -> np.ndarray:
    runtime = REPO_ROOT / "project" / "runtime"
    if str(runtime) not in sys.path:
        sys.path.insert(0, str(runtime))
    from chip_config import (  # pylint: disable=import-outside-toplevel
        DCIM_INT16_OUT_CH_PER_TILE,
        DCIM_INT16_OUT_WORDS_PER_TILE,
        DCIM_INT8_OUT_CH_PER_TILE,
        DCIM_INT8_OUT_WORDS_PER_TILE,
        DCIM_NUM_TILES,
    )
    if int16:
        ch_per_tile = DCIM_INT16_OUT_CH_PER_TILE
        wpt = DCIM_INT16_OUT_WORDS_PER_TILE
        per = 2
        fmt = "<q"
        dtype = np.int64
        elem = 8
    else:
        ch_per_tile = DCIM_INT8_OUT_CH_PER_TILE
        wpt = DCIM_INT8_OUT_WORDS_PER_TILE
        per = 4
        fmt = "<i"
        dtype = np.int32
        elem = 4
    out = np.zeros((m, n), dtype=dtype)
    off = 0
    for px in range(m):
        for tile in range(DCIM_NUM_TILES):
            for word_idx in range(wpt):
                for c in range(per):
                    oc = tile * ch_per_tile + word_idx * per + c
                    value = struct.unpack_from(fmt, raw, off)[0]
                    off += elem
                    if oc < n:
                        out[px, oc] = value
    return out


def _probe1_from_act(act_row, phase: int, int16: bool) -> tuple[int, list[int]]:
    """Tile0 ILA probe1 = phase_data[31:0] = first 8 channels' 4-bit nibble.

    INT8:  phase0 = bits[7:4], phase1 = bits[3:0]  (see DCIM_Activation_Stream).
    INT16: phase0..3 = bits[15:12] .. [3:0].
    """
    nibbles: list[int] = []
    for ch in range(8):
        value = int(act_row[ch])
        if int16:
            nibble = (value >> ((3 - phase) * 4)) & 0xF
        else:
            nibble = ((value >> 4) & 0xF) if phase == 0 else (value & 0xF)
        nibbles.append(nibble)
    word = 0
    for i, nibble in enumerate(nibbles):
        word |= nibble << (4 * i)
    return word & 0xFFFFFFFF, nibbles


def _fmt_row(values, bits: int, kind: str, per_line: int = 8) -> list[str]:
    vals = [int(v) for v in values]
    if kind == "dec":
        cells = [f"{v:6d}" for v in vals]
    else:
        cells = [_fmt_hex(v, bits) for v in vals]
    lines = []
    for i in range(0, len(cells), per_line):
        lines.append("    " + ", ".join(cells[i:i + per_line]))
    return lines


def _write_matrix(lines: list[str], title: str, mat: np.ndarray, bits: int,
                  row_prefix: str) -> None:
    lines.append(title)
    for i, row in enumerate(mat):
        lines.append(f"  {row_prefix}{i} 十进制:")
        lines.extend(_fmt_row(row, bits, "dec"))
        lines.append(f"  {row_prefix}{i} 十六进制:")
        lines.extend(_fmt_row(row, bits, "hex"))
    lines.append("")


def dump_host_ila(run_dir: Path, mode: str) -> dict:
    """Write complete host/ILA dump (hex+dec) and print the ILA table."""
    npz_path = run_dir / "operands.npz"
    if not npz_path.is_file():
        print(f"[dump] 缺少 {npz_path.name}，请先重新 prepare")
        return {}
    data = np.load(npz_path)
    act = data["act"]
    weight = data["weight"]
    golden = data["golden"]
    m, k_hw = int(act.shape[0]), int(act.shape[1])
    n = int(weight.shape[0])
    man = parse_manifest(run_dir)
    logical_k = min(int(man.get("matmul_k", k_hw)), k_hw)
    int16 = mode == "int16"
    in_bits = 16 if int16 else 8
    out_bits = 64 if int16 else 32
    phases = int(CASES[mode]["phases_per_job"])
    act_show = act[:, :logical_k]
    weight_show = weight[:, :logical_k]

    fpga = None
    got_path = run_dir / "fpga_got.bin"
    if got_path.is_file() and got_path.stat().st_size > 0:
        fpga = unpack_obuf(got_path.read_bytes(), m, n, int16)

    ila_cycles = []
    for job in range(m):
        for phase in range(phases):
            probe1, nibbles = _probe1_from_act(act[job], phase, int16)
            ila_cycles.append({
                "probe0_compute_mask": "0xff",
                "probe2_job": job,
                "probe3_phase": phase,
                "probe1_peak_dcim_input": _fmt_hex(probe1, 32),
                "probe1_nibbles_ch0_7": nibbles,
                "act_ch0_7_dec": [int(v) for v in act_show[job, :8]],
                "act_ch0_7_hex": [_fmt_hex(v, in_bits) for v in act_show[job, :8]],
            })

    ila_results = []
    for job in range(m):
        y = int(golden[job, 0])
        y_low32 = y & 0xFFFFFFFF
        item = {
            "probe2_job": job,
            "probe4_result_valid": 1,
            "probe5_peak_result_data": _fmt_hex(y_low32, 32),
            "y_oc0_dec": y,
            "y_oc0_hex": _fmt_hex(y, out_bits),
        }
        if fpga is not None:
            y_fpga = int(fpga[job, 0])
            item["y_oc0_fpga_dec"] = y_fpga
            item["y_oc0_fpga_hex"] = _fmt_hex(y_fpga, out_bits)
            item["match"] = y_fpga == y
        ila_results.append(item)

    lines: list[str] = []
    lines.append("Host / ILA 对照（完整输入输出，十进制 + 十六进制）")
    lines.append(f"case={CASES[mode]['name']}  {CASES[mode]['ops']}")
    lines.append(f"shape: M={m} 有效K={logical_k} 硬件K={k_hw} N={n}  in_hw={man.get('in_hw')}")
    lines.append("")
    lines.append("ILA 对照说明（Vivado Lab 打开 top.ltx，核 peak_tops_ila）：")
    lines.append("  probe0 peak_compute_mask[7:0]  计算时应为 0xff")
    lines.append("  probe1 peak_dcim_input[31:0]   Tile0 该拍输入低 32bit = 通道 0..7 的 4bit nibble")
    lines.append("                                 INT8: phase0=高半字节[7:4]，phase1=低半字节[3:0]")
    lines.append("                                 INT16: phase0..3 = [15:12]..[3:0]")
    lines.append("  probe2 peak_job[5:0]           像素/job 号 0..7")
    lines.append("  probe3 peak_phase[1:0]         INT8 走 0,1；INT16 走 0,1,2,3")
    lines.append("  probe4 peak_result_valid       该拍写出结果")
    lines.append("  probe5 peak_result_data[31:0]  Tile0 输出通道 0 的低 32bit，等于下面 y[job, oc=0]")
    lines.append("  触发：peak_compute_mask == 8'hFF")
    lines.append("")

    _write_matrix(lines, "======== 输入激活 act[job, k] ========", act_show, in_bits, "job")
    _write_matrix(lines, "======== 权重 weight[oc, k]（与对应 job 做点积） ========",
                  weight_show, in_bits, "oc")
    _write_matrix(lines, "======== 主机 golden 输出 y[job, oc] ========",
                  golden, out_bits, "job")
    if fpga is not None:
        _write_matrix(lines, "======== FPGA 回读 y[job, oc] ========", fpga, out_bits, "job")
        n_match = int(np.sum(fpga == golden))
        lines.append(f"FPGA vs golden: {n_match}/{fpga.size} 元素一致"
                     + ("  MATCH" if n_match == fpga.size else "  MISMATCH"))
        lines.append("")

    lines.append("======== ILA 期望：计算拍（对照 probe0/1/2/3） ========")
    lines.append("beat  job  phase  probe1(hex)          nibbles ch0..7     act[job,0..7] 十进制")
    for beat, row in enumerate(ila_cycles):
        nib = " ".join(f"{v:x}" for v in row["probe1_nibbles_ch0_7"])
        act_d = " ".join(f"{v:6d}" for v in row["act_ch0_7_dec"])
        lines.append(
            f"{beat:4d}  {row['probe2_job']:3d}  {row['probe3_phase']:5d}  "
            f"{row['probe1_peak_dcim_input']:12s}  [{nib:<15s}]  {act_d}"
        )
    lines.append("")
    lines.append("======== ILA 期望：结果拍（对照 probe4/5，Tile0 oc=0） ========")
    lines.append("job  probe5 低32bit     y[job,0] 十进制              y[job,0] 十六进制"
                 + ("          FPGA 十进制" if fpga is not None else ""))
    for row in ila_results:
        extra = ""
        if fpga is not None:
            tag = "MATCH" if row.get("match") else "MISMATCH"
            extra = f"    {row['y_oc0_fpga_dec']:d}  {tag}"
        lines.append(
            f"{row['probe2_job']:3d}  {row['probe5_peak_result_data']:12s}  "
            f"{row['y_oc0_dec']:22d}  {row['y_oc0_hex']}"
            + extra
        )
    lines.append("")

    dump_path = run_dir / "host_ila_dump.txt"
    dump_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    ila_path = run_dir / "expected_ila.json"
    ila = json.loads(ila_path.read_text(encoding="utf-8")) if ila_path.is_file() else {}
    ila["probe5_all_jobs_low32"] = [row["probe5_peak_result_data"] for row in ila_results]
    ila["ila_cycles"] = ila_cycles
    ila["ila_results"] = ila_results
    ila["dump_file"] = str(dump_path)
    ila_path.write_text(json.dumps(ila, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("=" * 72)
    print(f"[dump] 完整输入/输出/ILA 对照已写到 {dump_path}")
    print(f"[dump] {CASES[mode]['ops']}  M={m} K={logical_k} N={n}")
    print("-" * 72)
    print("输入激活 act[job, k]  十进制 / 十六进制：")
    for job in range(m):
        print(f"  job{job} 十进制: " + ", ".join(f"{int(v):6d}" for v in act_show[job]))
        print(f"  job{job} 十六进制: " + ", ".join(_fmt_hex(v, in_bits) for v in act_show[job]))
    print("-" * 72)
    print("ILA 计算拍（波形里 job/phase/probe1 应对上）：")
    print("  beat  job  phase  probe1              act[job,0..7]")
    for beat, row in enumerate(ila_cycles):
        print(
            f"  {beat:4d}  {row['probe2_job']:3d}  {row['probe3_phase']:5d}  "
            f"{row['probe1_peak_dcim_input']:12s}  "
            + ", ".join(f"{v:4d}" for v in row["act_ch0_7_dec"])
        )
    print("-" * 72)
    print("ILA 结果拍 probe5 = y[job, oc=0] 低 32bit（主机 golden"
          + (" / FPGA" if fpga is not None else "") + "）：")
    for row in ila_results:
        fpga_s = ""
        if fpga is not None:
            fpga_s = f"  FPGA={row['y_oc0_fpga_dec']}({row['y_oc0_fpga_hex']})  " + (
                "MATCH" if row.get("match") else "MISMATCH"
            )
        print(
            f"  job{row['probe2_job']}  probe5={row['probe5_peak_result_data']}  "
            f"dec={row['y_oc0_dec']}  hex={row['y_oc0_hex']}"
            + fpga_s
        )
    if fpga is not None:
        n_match = int(np.sum(fpga == golden))
        print(f"[dump] 全部输出 FPGA vs golden: {n_match}/{fpga.size} MATCH")
    print(f"[dump] 完整权重 {n}×{logical_k} 与全部输出 {m}×{n} 见上述 txt")
    print("=" * 72)
    return {
        "dump_file": str(dump_path),
        "fpga_compared": fpga is not None,
    }


def run_fpga(run_dir: Path, timeout_s: float, quiet: bool) -> list[dict]:
    if os.name != "nt":
        raise SystemExit("上板需要 Windows 与 XDMA 驱动")
    runtime = REPO_ROOT / "project" / "runtime"
    host = REPO_ROOT / "test" / "network" / "host"
    for extra in (runtime, host):
        if str(extra) not in sys.path:
            sys.path.insert(0, str(extra))
    from xdma_win import ChipRunnerWin  # pylint: disable=import-outside-toplevel

    print("[fpga] 请先在 Vivado Lab 用 top.ltx Arm ILA"
          "（触发：peak_compute_mask == 8'hFF）", flush=True)
    return ChipRunnerWin(verbose=not quiet).run_case(
        run_dir, timeout_s=timeout_s, staging="hbm", verify=True
    )


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mode", choices=["int8", "int16", "both"], default="both")
    ap.add_argument("--seed", type=int, default=20260822)
    ap.add_argument("--out-dir", type=Path, default=OUT_ROOT)
    ap.add_argument("--prepare-only", action="store_true", help="只生成随机向量和 expected_ila.json")
    ap.add_argument("--timeout-s", type=float, default=60.0)
    ap.add_argument("--quiet-xdma", action="store_true")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
    modes = ["int8", "int16"] if args.mode == "both" else [args.mode]
    reports = []
    for mode in modes:
        run_dir = prepare(mode, args.seed, Path(args.out_dir))
        record = {
            "mode": mode,
            "run_dir": str(run_dir),
        }
        if args.prepare_only:
            record["status"] = "PREPARED"
            record["dump"] = dump_host_ila(run_dir, mode)
        else:
            results = run_fpga(run_dir, args.timeout_s, args.quiet_xdma)
            host_pass = all(bool(item.get("pass") or item.get("passed")) for item in results)
            record["host_results"] = results
            record["status"] = "PASS_HOST_PENDING_ILA" if host_pass else "FAIL_HOST"
            record["dump"] = dump_host_ila(run_dir, mode)
            print(f"[fpga] {mode} host={'PASS' if host_pass else 'FAIL'}  "
                  f"请把 ILA 波形对照 {run_dir / 'host_ila_dump.txt'}")
        reports.append(record)

    summary = Path(args.out_dir) / "precision_report.json"
    summary.parent.mkdir(parents=True, exist_ok=True)
    payload = {"seed": args.seed, "cases": reports}
    summary.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"[report] {summary}")
    if any(c.get("status") == "FAIL_HOST" for c in reports):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
