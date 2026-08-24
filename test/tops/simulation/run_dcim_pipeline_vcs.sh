#!/usr/bin/env bash
# Compile and run the focused eight-tile DCIM arithmetic-pipeline test on eda02.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/test/tops/output/simulation/pipeline_vcs}"
BUILD_DIR="$RUN_DIR/build"
DATA_DIR="$RUN_DIR/data"

source "$REPO_ROOT/project/rtl/tb/lite_bd/sim/vcs_common.sh"
vcs_setup

mkdir -p "$BUILD_DIR" "$DATA_DIR"
python3 "$SCRIPT_DIR/gen_pipeline_int8.py" --out-dir "$DATA_DIR" --batch-jobs 32 \
  >"$RUN_DIR/generate.log"

VERDI_PLI_DIR="/home/EDAtools/synopsys/verdi/V-2023.12-SP1/share/PLI/VCS/LINUX64"
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
  "$SCRIPT_DIR/tb_dcim_pipeline_peak.sv"
)

cd "$BUILD_DIR"
rm -rf work simv simv.daidir csrc ucli.key
mkdir -p work
"$VLOGAN" -full64 -sverilog +v2k +define+SIMULATION \
  "+incdir+$REPO_ROOT/project/rtl/ref/DCIM/src/inc" \
  -work work "${SOURCES[@]}" -l "$RUN_DIR/vlogan.log"
"$VCS" -full64 -j32 -debug_access+all -kdb -lca -t ps \
  -P "$VERDI_PLI_DIR/novas.tab" "$VERDI_PLI_DIR/pli.a" \
  work.tb_dcim_pipeline_peak -o simv -l "$RUN_DIR/compile.log"

cd "$RUN_DIR"
"$BUILD_DIR/simv" +FSDB "+DATA_DIR=$DATA_DIR" -no_save 2>&1 | tee sim.log
python3 "$SCRIPT_DIR/report_pipeline_int8.py" --run-dir "$RUN_DIR"

echo "PIPELINE_RUN_DIR=$RUN_DIR"
