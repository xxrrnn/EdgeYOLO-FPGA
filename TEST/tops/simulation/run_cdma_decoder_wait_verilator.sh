#!/usr/bin/env bash
# A/B runner: point DECODER_SV at either the pre-fix or current decoder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
DECODER_SV="${DECODER_SV:-$REPO_ROOT/rtl/vpu/INST_Decoder.sv}"
CASE_DIR="${CASE_DIR:-$REPO_ROOT/output/tops/simulation/yolo_two_job}"
RUN_DIR="${RUN_DIR:-/tmp/cdma_decoder_wait_verilator}"
SR_BUSY_DELAY_CYCLES="${SR_BUSY_DELAY_CYCLES:-0}"
TOP=tb_cdma_decoder_wait_verilator

command -v verilator >/dev/null || { echo "ERROR: verilator not found" >&2; exit 2; }
[[ -f "$CASE_DIR/act0.hex" ]] || {
  python3 "$SCRIPT_DIR/gen_yolo_two_job_vectors.py"
}

mkdir -p "$RUN_DIR"
verilator --cc --exe --top-module "$TOP" \
  -DSIMULATION \
  -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
  -I"$REPO_ROOT/rtl/chip" -I"$REPO_ROOT/rtl/vpu" \
  -Mdir "$RUN_DIR/obj_dir" \
  "$DECODER_SV" \
  "$REPO_ROOT/rtl/vpu/CDMA_Controller.sv" \
  "$SCRIPT_DIR/tb_cdma_decoder_wait_verilator.sv" \
  --exe "$SCRIPT_DIR/tb_cdma_decoder_wait_verilator.cpp"

make -C "$RUN_DIR/obj_dir" -f "V${TOP}.mk" -j"$(nproc 2>/dev/null || echo 4)"

"$RUN_DIR/obj_dir/V$TOP" \
  "+ACT_HEX=$CASE_DIR/act0.hex" \
  "+SR_BUSY_DELAY_CYCLES=$SR_BUSY_DELAY_CYCLES" 2>&1 | tee "$RUN_DIR/sim.log"
grep -q "CDMA_WAIT_PASS" "$RUN_DIR/sim.log"
