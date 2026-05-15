#!/bin/bash
################################################################################
# 使用 Vivado 进行完整系统仿真
# 测试 INST_Decoder + CDMA_Controller + Xilinx CDMA IP + BRAM
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJ_ROOT/build/vpu"
SIM_DIR="$SCRIPT_DIR"

echo "========================================"
echo "完整系统仿真"
echo "========================================"
echo "项目路径: $PROJ_ROOT"
echo "构建目录: $BUILD_DIR"
echo "仿真目录: $SIM_DIR"
echo ""

# 检查 Vivado 项目
if [ ! -f "$BUILD_DIR/vpu.xpr" ]; then
    echo "ERROR: Vivado 项目不存在: $BUILD_DIR/vpu.xpr"
    echo "请先运行 Vivado 项目构建"
    exit 1
fi

# 运行 Vivado 仿真
cd "$BUILD_DIR"
vivado -mode batch -source "$SIM_DIR/run_sim.tcl" -notrace

echo ""
echo "========================================"
echo "仿真完成"
echo "========================================"
