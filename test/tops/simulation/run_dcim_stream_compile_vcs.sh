#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/test/tops/output/simulation/stream_compile_vcs}"
BUILD_DIR="$RUN_DIR/build"

source "$REPO_ROOT/project/rtl/tb/lite_bd/sim/vcs_common.sh"
vcs_setup
mkdir -p "$BUILD_DIR/work"

SOURCES=(
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/para.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/counter.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/dff.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/pipe_stage.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/multiplier.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/multiplier_dsp.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/adderTree.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/maArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/calculate_core.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/mergeArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/accumulateArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/postProcess.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/model/model_rf_bram.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Activation_Stream.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Weight_Cache.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Partial_Sum_RAM.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Result_Stream.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Tile.sv"
  "$REPO_ROOT/project/rtl/common/uram_tdp_bytewrite.v"
  "$REPO_ROOT/project/rtl/chip/tile_ibuf.v"
  "$REPO_ROOT/project/rtl/chip/tile_obuf.v"
  "$REPO_ROOT/project/rtl/chip/DCIM_Array.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Array_bd.v"
  "$REPO_ROOT/project/rtl/vpu/INST_Decoder.sv"
)

cd "$BUILD_DIR"
rm -rf work
mkdir work
"$VLOGAN" -full64 -sverilog +v2k +define+SIMULATION \
  "+incdir+$REPO_ROOT/project/rtl/chip" \
  "+incdir+$REPO_ROOT/project/rtl/ref/DCIM/src/inc" \
  -work work "${SOURCES[@]}" -l "$RUN_DIR/vlogan.log"

echo "PASS: streamed Tile RTL analyzed by VCS"
