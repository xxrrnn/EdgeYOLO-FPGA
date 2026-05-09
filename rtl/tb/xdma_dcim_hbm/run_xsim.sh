#!/bin/bash
# Run INT8, INT16, or PCIe testbench with Vivado xsim
# Usage: ./run_xsim.sh [int8|int16|pcie]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

XDMA_DIR="$REPO_ROOT/rtl/xdma_dcim_bram"
DCIM_DIR="$REPO_ROOT/rtl/DCIM/src/dcim"
DCIM_INC_DIR="$REPO_ROOT/rtl/DCIM/src/inc"

MODE="${1:-int8}"

if [ "$MODE" = "int16" ]; then
    TB_FILE="$SCRIPT_DIR/tb_pe_large_gemm_int16.sv"
    TOP_MODULE="tb_pe_large_gemm_int16"
    SIM_NAME="tb_int16_sim"
elif [ "$MODE" = "pcie" ]; then
    TB_FILE="$SCRIPT_DIR/tb_pcie_large_gemm.sv"
    TOP_MODULE="tb_pcie_large_gemm"
    SIM_NAME="tb_pcie_sim"
else
    TB_FILE="$SCRIPT_DIR/tb_pe_large_gemm.sv"
    TOP_MODULE="tb_pe_large_gemm"
    SIM_NAME="tb_int8_sim"
fi

cd "$SCRIPT_DIR"

# Clean previous simulation
rm -rf xsim.dir *.log *.jou *.pb *.wdb

echo "=== Compiling $MODE testbench with xvlog ==="

xvlog -sv -i "$XDMA_DIR" -i "$DCIM_INC_DIR" \
    "$XDMA_DIR/dcim_defs.vh" \
    "$XDMA_DIR/xdma_dcim_preprocess.v" \
    "$XDMA_DIR/DCIM_Macro.sv" \
    "$XDMA_DIR/PE.sv" \
    "$DCIM_INC_DIR/dff.v" \
    "$DCIM_INC_DIR/pipe_stage.v" \
    "$DCIM_INC_DIR/counter.v" \
    "$DCIM_DIR/multiplier.v" \
    "$DCIM_DIR/adderTree.v" \
    "$DCIM_DIR/maArray.v" \
    "$DCIM_DIR/calculate_core.v" \
    "$DCIM_DIR/sramWrap.v" \
    "$DCIM_DIR/memory.v" \
    "$DCIM_DIR/mergeArray.v" \
    "$DCIM_DIR/ppCache.v" \
    "$DCIM_DIR/accumulateArray.v" \
    "$DCIM_DIR/postProcess.v" \
    "$TB_FILE"

echo "=== Elaborating design ==="
xelab "$TOP_MODULE" -debug typical -s "$SIM_NAME"

echo "=== Running simulation ==="
xsim "$SIM_NAME" -runall

echo "=== Done ==="
