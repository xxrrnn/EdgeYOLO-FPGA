#!/usr/bin/env bash
# Same two-job test on VCS (eda02).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PIXELS="${TWO_JOB_PIXELS:-4000}"
ACC="${TWO_JOB_ACC:-2}"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/test/tops/output/simulation/two_job_vcs}"
BUILD_DIR="$RUN_DIR/build"
source "$REPO_ROOT/project/rtl/tb/lite_bd/sim/vcs_common.sh"
vcs_setup
mkdir -p "$BUILD_DIR"
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
  "$SCRIPT_DIR/tb_dcim_two_job.sv"
)
cd "$BUILD_DIR"
rm -rf work simv simv.daidir csrc ucli.key
mkdir work
"$VLOGAN" -full64 -sverilog +v2k +define+SIMULATION \
  "+define+TWO_JOB_PIXELS=$PIXELS" "+define+TWO_JOB_ACC=$ACC" \
  "+incdir+$REPO_ROOT/project/rtl/chip" \
  "+incdir+$REPO_ROOT/project/rtl/ref/DCIM/src/inc" \
  -work work "${SOURCES[@]}" -l "$RUN_DIR/vlogan.log"
"$VCS" -full64 -j32 -t ps work.tb_dcim_two_job \
  -o simv -l "$RUN_DIR/compile.log"
cd "$RUN_DIR"
"$BUILD_DIR/simv" -no_save 2>&1 | tee sim.log
grep -q "TWO_JOB_PASS" sim.log
