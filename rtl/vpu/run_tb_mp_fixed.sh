#!/bin/bash
# ==============================================================================
# run_tb_mp_fixed.sh - 运行 mp_unit_fixed testbench (xsim)
# ==============================================================================
# 用法: bash run_tb_mp_fixed.sh
# 需要: Vivado (xvlog, xelab, xsim) 在 PATH 中
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RTL_DIR="$SCRIPT_DIR"
TB_DIR="$RTL_DIR/tb"
SIM_DIR="$RTL_DIR/sim/mp_fixed"

mkdir -p "$SIM_DIR"
cd "$SIM_DIR"

echo "============================================"
echo " mp_unit_fixed Simulation (xsim)"
echo "============================================"
echo ""

# 编译
echo "[1/3] Compiling..."
xvlog -sv \
    "$RTL_DIR/mp_unit_fixed.sv" \
    "$TB_DIR/tb_mp_unit_fixed.sv" \
    2>&1 | tee compile.log

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

# Elaborate
echo ""
echo "[2/3] Elaborating..."
xelab -debug typical tb_mp_unit_fixed -s sim_snapshot \
    2>&1 | tee elaborate.log

if [ $? -ne 0 ]; then
    echo "ERROR: Elaboration failed!"
    exit 1
fi

# 仿真
echo ""
echo "[3/3] Running simulation..."
xsim sim_snapshot --runall \
    2>&1 | tee sim.log

echo ""
echo "Done. Logs in: $SIM_DIR/"
echo "  compile.log, elaborate.log, sim.log"

# 检查结果
if grep -q "PASS" sim.log; then
    echo ""
    echo ">>> SIMULATION PASSED <<<"
    exit 0
elif grep -q "FAIL" sim.log; then
    echo ""
    echo ">>> SIMULATION FAILED <<<"
    exit 1
else
    echo ""
    echo ">>> RESULT UNKNOWN (check sim.log) <<<"
    exit 2
fi
