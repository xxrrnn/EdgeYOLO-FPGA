#!/usr/bin/env bash
# Two sequential DCIM_Tile jobs on Verilator 4.x (--cc --exe, no --binary).
#   bash TEST/tops/simulation/run_dcim_two_job_verilator.sh
#   TWO_JOB_PIXELS=4000 TWO_JOB_ACC=2 bash TEST/tops/simulation/run_dcim_two_job_verilator.sh
set -euo pipefail
# Allow WSL to copy this script to /tmp (CRLF strip) while keeping repo paths.
if [[ -z "${REPO_ROOT:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
else
  SCRIPT_DIR="$REPO_ROOT/TEST/tops/simulation"
fi
PIXELS="${TWO_JOB_PIXELS:-256}"
ACC="${TWO_JOB_ACC:-2}"
# Prefer a Linux-native RUN_DIR; /mnt/e obj_dir is slow and chmod-unfriendly.
RUN_DIR="${RUN_DIR:-/tmp/two_job_verilator}"
OBJ_DIR="$RUN_DIR/obj_dir_p${PIXELS}_a${ACC}"
TOP=tb_dcim_two_job_verilator_top

command -v verilator >/dev/null || {
  echo "ERROR: verilator not found" >&2
  exit 2
}

mkdir -p "$RUN_DIR" "$OBJ_DIR"
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
  "$REPO_ROOT/rtl/chip/DCIM_Result_Stream.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Partial_Sum_RAM.sv"
  "$REPO_ROOT/rtl/chip/DCIM_Tile.sv"
  "$SCRIPT_DIR/tb_dcim_two_job_verilator_top.sv"
)

verilator --cc --exe --top-module "$TOP" \
  -CFLAGS "-DTWO_JOB_PIXELS=$PIXELS -DTWO_JOB_ACC=$ACC" \
  -DTWO_JOB_PIXELS="$PIXELS" -DTWO_JOB_ACC="$ACC" \
  -DSIMULATION \
  -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
  -I"$REPO_ROOT/rtl/chip" -I"$REPO_ROOT/rtl/ref/DCIM/src/inc" \
  --output-split 20000 --output-split-cfuncs 100 \
  -Mdir "$OBJ_DIR" \
  "${SOURCES[@]}" \
  --exe "$SCRIPT_DIR/tb_dcim_two_job_verilator.cpp"

make -C "$OBJ_DIR" -f "V${TOP}.mk" -j"$(nproc 2>/dev/null || echo 4)"
LOG="$RUN_DIR/sim_p${PIXELS}_a${ACC}.log"
if [[ -n "${CASE_DIR:-}" ]]; then
  echo "CASE_DIR=$CASE_DIR"
  "$OBJ_DIR/V${TOP}" "$CASE_DIR" 2>&1 | tee "$LOG"
else
  "$OBJ_DIR/V${TOP}" 2>&1 | tee "$LOG"
  grep -q "TWO_JOB_PASS" "$LOG"
fi
