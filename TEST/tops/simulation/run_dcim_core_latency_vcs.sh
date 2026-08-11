#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/output/tops/simulation/core_latency_vcs}"
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
  "$SCRIPT_DIR/tb_dcim_core_latency.sv"
)

cd "$BUILD_DIR"
rm -rf work simv simv.daidir csrc ucli.key
mkdir -p work
"$VLOGAN" -full64 -sverilog +v2k +define+SIMULATION \
  "+incdir+$REPO_ROOT/rtl/chip" \
  "+incdir+$REPO_ROOT/rtl/ref/DCIM/src/inc" \
  -work work "${SOURCES[@]}" -l "$RUN_DIR/vlogan.log"
"$VCS" -full64 -j32 -lca -t ps work.tb_dcim_core_latency \
  -o simv -l "$RUN_DIR/compile.log"
cd "$RUN_DIR"
"$BUILD_DIR/simv" -no_save 2>&1 | tee sim.log
