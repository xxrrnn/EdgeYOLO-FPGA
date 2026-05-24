#!/usr/bin/env bash
# ===========================================================================
# run_xsim_e2e.sh - 用 Vivado xsim 跑 tb_e2e_inst_driven (3 层 conv 完整 E2E)
#
# 用法：
#   bash rtl/vpu/tb/sim/run_xsim_e2e.sh                  # 默认 run -all
#   E2E_RUN_NS=2000000 bash rtl/vpu/tb/sim/run_xsim_e2e.sh  # 指定运行多少 ns
# 产物：
#   rtl/vpu/tb/sim/build_xsim_e2e/                       # 所有日志和 .wdb 波形
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build_xsim_e2e"
FILELIST="$REPO_ROOT/rtl/vpu/tb/e2e/filelist_e2e.f"
TB_TOP="tb_e2e_inst_driven"
SIM_NAME="sim_e2e_inst"
E2E_DIR="$REPO_ROOT/rtl/vpu/tb/e2e"
GOLDEN_PY="$E2E_DIR/golden_e2e_inst.py"
# tb_e2e_inst_driven.sv currently hard-codes L1=16x16, L2/L3=8x8.
# golden_e2e_inst.py reaches that shape with scale=0.1 (160 * 0.1 = 16).
SCALE="${E2E_SCALE:-0.1}"

echo "=== [0/4] Regenerate E2E golden hex (scale=$SCALE) ==="
python3 "$GOLDEN_PY" --scale "$SCALE" --out-dir "$E2E_DIR"

INCDIR_LIST=(
  "$REPO_ROOT/rtl/chip"
  "$REPO_ROOT/rtl/vpu"
)

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 把 hex 文件软链到 build 目录（testbench 用相对路径 $readmemh）
ln -sfn "$REPO_ROOT/rtl/vpu/tb/e2e"/*.hex . 2>/dev/null || true
# inst hex 在 hex_inst/ 目录里
if [ -d "$REPO_ROOT/rtl/vpu/tb/e2e/hex_inst" ]; then
  ln -sfn "$REPO_ROOT/rtl/vpu/tb/e2e/hex_inst" .
fi
if [ -d "$REPO_ROOT/rtl/vpu/tb/e2e/hex" ]; then
  ln -sfn "$REPO_ROOT/rtl/vpu/tb/e2e/hex" .
fi

INC_ARGS=""
for d in "${INCDIR_LIST[@]}"; do
  INC_ARGS="$INC_ARGS -i $d"
done

echo "=== [1/4] xvlog (analyze) ==="
xvlog --sv $INC_ARGS -f "$FILELIST" 2>&1 | tee xvlog.log
if grep -q '^ERROR' xvlog.log; then
  echo "!!! xvlog ERROR — abort"
  exit 1
fi

echo "=== [2/4] xelab (elaborate) ==="
xelab -debug typical -L floating_point_v7_1_19 -L unisims_ver \
      -s "$SIM_NAME" "$TB_TOP" 2>&1 | tee xelab.log
if grep -q '^ERROR' xelab.log; then
  echo "!!! xelab ERROR — abort"
  exit 1
fi

echo "=== [3/4] xsim (simulate) ==="
RUN_CMD="${E2E_RUN_NS:+run ${E2E_RUN_NS} ns}"
RUN_CMD="${RUN_CMD:-run -all}"
cat > run.tcl <<EOF
$RUN_CMD
quit
EOF
xsim "$SIM_NAME" -t run.tcl 2>&1 | tee xsim.log

echo "=== [4/4] Result summary ==="
grep -E "(L1_|L2_|L3_|GRAND|ALL CHECKPOINTS|SOME CHECKPOINTS|TIMEOUT|FATAL)" xsim.log | tail -40 || true
