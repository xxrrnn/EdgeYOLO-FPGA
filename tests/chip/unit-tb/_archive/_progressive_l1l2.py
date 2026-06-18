"""
Run L1 + L2 of progressive_test.ipynb as a script (no Jupyter needed).
Executes all cases and prints the summary table.
"""
import sys, struct, time
from pathlib import Path
from collections import defaultdict

UNIT_TB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(UNIT_TB_DIR))
REPO_ROOT = UNIT_TB_DIR.parent.parent.parent

from xdma_win import XDMAWin, ChipRunnerWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

TEST_RESULTS = []

def record(level, name, staging, pw, tw, note=""):
    status = "PASS" if pw == tw else "FAIL"
    TEST_RESULTS.append((level, name, staging, status, pw, tw, note))
    icon = "+" if status == "PASS" else "X"
    print(f"  [{icon}] [{level}] {name} [{staging}]  {status}  ({pw}/{tw}){' -- '+note if note else ''}")
    return status == "PASS"

# ── L1 ────────────────────────────────────────────────────────────
L1 = [
    ("dcim_matmul", "dcim_tiny_1x1",      "int8",  60, "min DCIM"),
    ("dcim_matmul", "conv6_s2_c3_to16",   "int8",  90, "1-tile model.0"),
    ("dcim_matmul", "conv3_s2_c32_to64",  "int8",  90, "4-tile model.3"),
    ("qa",          "qa_c16_signed",       "int8",  60, "QA c=16"),
    ("dqa",         "dqa_c16_small",       "int8",  60, "DQA c=16"),
    ("im2col",      "im2col_6x6_s2_c3",   "int8", 180, "im2col 6x6 s2"),
]

print("="*65); print("L1: 单算子最小规模"); print("="*65)
for mod, var, q, tmo, note in L1:
    rd = generate_case(mod, var, quant=q)
    for r in runner.run_case(rd, staging="hbm", timeout_s=tmo):
        record("L1", f"{mod}/{var}", "hbm", r["passed"], r["total_words"], note)
        if not r["pass"] and r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"    word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")

# ── L2-A ──────────────────────────────────────────────────────────
L2A = [
    ("dcim_matmul", "conv1_c64_to32",              "int8",  90, "N=32 1x1"),
    ("dcim_matmul", "conv3_c128_to128",             "int8",  90, "N=128 8-tile"),
    ("dcim_matmul", "extreme_int8_1x1_c512_to512",  "int8", 120, "N=512 tilepass"),
    ("dcim_matmul", "extreme_int8_3x3_c128_to512",  "int8", 120, "K=1152 N=512"),
    ("dcim_matmul", "extreme_int8_6x6_c3_to64",     "int8", 120, "M=36 N=64"),
    ("dcim_matmul", "dcim_model_0_conv",             "int8", 180, "model.0 M=25600"),
    ("dcim_matmul", "dcim_model_3_conv",             "int8", 180, "model.3 acc=5"),
    ("dcim_matmul", "dcim_model_7_conv",             "int8", 180, "model.7 acc=18"),
]

print("\n"+"="*65); print("L2-A: DCIM extreme & 网络层"); print("="*65)
for mod, var, q, tmo, note in L2A:
    rd = generate_case(mod, var, quant=q)
    for r in runner.run_case(rd, staging="hbm", timeout_s=tmo):
        record("L2-A", f"{mod}/{var}", "hbm", r["passed"], r["total_words"], note)
        if not r["pass"] and r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"    word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")

# ── L2-B im2col ───────────────────────────────────────────────────
L2B = [
    ("im2col", "im2col_3x3_s2_c32",  "int8", 180, "3x3 s2 c32"),
    ("im2col", "im2col_3x3_s1_c128", "int8", 180, "3x3 s1 c128"),
    ("im2col", "im2col_1x1_c512",    "int8", 120, "1x1 c512"),
]

print("\n"+"="*65); print("L2-B: im2col 大尺寸"); print("="*65)
for mod, var, q, tmo, note in L2B:
    rd = generate_case(mod, var, quant=q)
    for r in runner.run_case(rd, staging="hbm", timeout_s=tmo):
        record("L2-B", f"{mod}/{var}", "hbm", r["passed"], r["total_words"], note)
        if not r["pass"] and r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"    word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")

# ── L2-C QA/DQA ───────────────────────────────────────────────────
L2C = [
    ("dqa", "dqa_c32_mid",    "int8", 60, "DQA c=32"),
    ("dqa", "dqa_c64_mid",    "int8", 60, "DQA c=64"),
    ("dqa", "dqa_c128_sppf",  "int8", 60, "DQA c=128"),
    ("qa",  "qa_c64_clip",    "int8", 60, "QA c=64"),
    ("qa",  "qa_c128_dense",  "int8", 60, "QA c=128"),
]

print("\n"+"="*65); print("L2-C: QA/DQA 大通道"); print("="*65)
for mod, var, q, tmo, note in L2C:
    rd = generate_case(mod, var, quant=q)
    for r in runner.run_case(rd, staging="hbm", timeout_s=tmo):
        record("L2-C", f"{mod}/{var}", "hbm", r["passed"], r["total_words"], note)
        if not r["pass"] and r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"    word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")

# ── 汇总 ──────────────────────────────────────────────────────────
level_stats = defaultdict(lambda: {"pass": 0, "fail": 0})
failures = []
for level, name, staging, status, pw, tw, note in TEST_RESULTS:
    key = "pass" if status == "PASS" else "fail"
    level_stats[level][key] += 1
    if status != "PASS":
        failures.append((level, name, staging, pw, tw, note))

WIDTH = 65
print("\n" + "="*WIDTH)
print(f"{'SUMMARY':^{WIDTH}}")
print("="*WIDTH)
print(f"  {'Level':<8} {'Pass':>5} {'Fail':>5} {'Rate':>8}")
print("-"*WIDTH)
for lv in ["L1", "L2-A", "L2-B", "L2-C"]:
    s = level_stats.get(lv)
    if not s:
        print(f"  {lv:<8} {'--':>5} {'--':>5} {'--':>8}")
        continue
    tot = s["pass"] + s["fail"]
    icon = "+" if s["fail"] == 0 else "X"
    print(f"  {lv:<8} {s['pass']:>5} {s['fail']:>5} {s['pass']/tot*100:>7.1f}%  [{icon}]")
tp = sum(s["pass"] for s in level_stats.values())
tf = sum(s["fail"] for s in level_stats.values())
print("-"*WIDTH)
print(f"  {'TOTAL':<8} {tp:>5} {tf:>5} {tp/(tp+tf)*100 if tp+tf else 0:>7.1f}%  "
      f"[{'ALL PASS' if not tf else 'SOME FAILED'}]")
print("="*WIDTH)
if failures:
    print("\nFailed cases:")
    for lv, nm, st, pw, tw, note in failures:
        print(f"  [{lv}] {nm}  {pw}/{tw}  {note}")
sys.exit(0 if not failures else 1)
