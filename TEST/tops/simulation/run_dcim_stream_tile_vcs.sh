#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/output/tops/simulation/stream_tile_vcs}"
BUILD_DIR="$RUN_DIR/build"

source "$REPO_ROOT/rtl/tb/lite_bd/sim/vcs_common.sh"
vcs_setup
mkdir -p "$BUILD_DIR"

SOURCES=(
  "$REPO_ROOT/rtl/ref/DCIM/src/inc/para.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/inc/counter.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/inc/dff.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/inc/pipe_stage.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/multiplier.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/multiplier_dsp.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/adderTree.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/maArray.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/calculate_core.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/mergeArray.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/accumulateArray.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/dcim/postProcess.v"
  "$REPO_ROOT/rtl/ref/DCIM/src/model/model_rf_bram.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Activation_Stream.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Weight_Cache.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Partial_Sum_RAM.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Result_Stream.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Tile.sv"
  "$SCRIPT_DIR/tb_dcim_stream_tile.sv"
)

cd "$BUILD_DIR"
rm -rf work simv simv.daidir csrc ucli.key
mkdir work
"$VLOGAN" -full64 -sverilog +v2k +define+SIMULATION \
  ${VCS_FSDB_DEFINE-+define+FSDB_DUMP} ${VCS_TEST_DEFINES:-} \
  "+incdir+$REPO_ROOT/rtl/chip" \
  "+incdir+$REPO_ROOT/rtl/ref/DCIM/src/inc" \
  -work work "${SOURCES[@]}" -l "$RUN_DIR/vlogan.log"
"$VCS" -full64 -j32 ${VCS_ELAB_OPTS:--lca -debug_access+all} -t ps \
  work.tb_dcim_stream_tile -o simv -l "$RUN_DIR/compile.log"
cd "$RUN_DIR"
"$BUILD_DIR/simv" +FSDB ${VCS_SIM_OPTS:-} -no_save 2>&1 | tee sim.log
grep -q "PASS: back-to-back unified INT8/native-INT16 streamed Tile without inter-job reset" sim.log
