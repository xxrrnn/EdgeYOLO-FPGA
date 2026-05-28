#!/usr/bin/env bash
# ===========================================================================
# run_xsim_qa_standalone.sh - 用 Vivado xsim 跑 tb_qa_standalone
#
# 用法：
#   bash rtl/vpu/tb/sim/run_xsim_qa_standalone.sh
# 产物：
#   rtl/vpu/tb/sim/build_xsim_qa/  里所有日志和 .wdb 波形
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build_xsim_qa"
FILELIST="$SCRIPT_DIR/filelist_qa_standalone.f"
TB_TOP="tb_qa_standalone"
SIM_NAME="sim_qa_standalone"
GOLDEN_PY="$REPO_ROOT/tools/golden_qa_standalone.py"
GEN_DIR="$REPO_ROOT/rtl/vpu/tb/standalone/generated"
STANDALONE_SCALE="${STANDALONE_SCALE:-1.0}"

echo "=== [0/4] Generate QA golden (network scale=$STANDALONE_SCALE) ==="
python3 "$GOLDEN_PY" --scale "$STANDALONE_SCALE" --out-dir "$GEN_DIR"

INCDIR_LIST=(
  "$REPO_ROOT/rtl/chip"
  "$REPO_ROOT/rtl/vpu"
  "$REPO_ROOT/rtl/vpu/tb/standalone/generated"
)

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 把 hex 文件软链到当前目录（testbench 用相对路径 $readmemh）
ln -sfn "$GEN_DIR/hex" "$BUILD_DIR/hex"

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
# -L floating_point_v7_1_19 让 IP wrapper 找得到 FP 库
xelab -debug typical -L floating_point_v7_1_19 -L unisims_ver \
      -s "$SIM_NAME" "$TB_TOP" 2>&1 | tee xelab.log
if grep -q '^ERROR' xelab.log; then
  echo "!!! xelab ERROR — abort"
  exit 1
fi

echo "=== [3/4] xsim (simulate) ==="
# tcl 脚本：run -all; quit
cat > run.tcl <<'EOF'
run -all
quit
EOF
xsim "$SIM_NAME" -t run.tcl 2>&1 | tee xsim.log

echo "=== [4/4] Result summary ==="
grep -E "(PASS|FAIL|TIMEOUT|Summary|FATAL)" xsim.log || true
