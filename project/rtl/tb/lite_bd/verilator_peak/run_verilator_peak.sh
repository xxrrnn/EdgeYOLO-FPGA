#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
CASE_DIR="${VERILATOR_PEAK_RUN_DIR:-$REPO_ROOT/test/tops/output/verilator_peak_int8}"
BUILD_DIR="${VERILATOR_PEAK_BUILD_DIR:-$REPO_ROOT/test/tops/output/.verilator_peak_build}"
OBJ_DIR="$BUILD_DIR/obj_dir"
TOP=dcim_peak_verilator_top

command -v verilator >/dev/null || { echo "ERROR: verilator is not installed" >&2; exit 2; }
command -v make >/dev/null || { echo "ERROR: make is not installed" >&2; exit 2; }
command -v python3 >/dev/null || { echo "ERROR: python3 is not installed" >&2; exit 2; }

mkdir -p "$CASE_DIR" "$BUILD_DIR"
if python3 -c 'import numpy' >/dev/null 2>&1; then
  python3 "$REPO_ROOT/project/rtl/tb/lite_bd/module_tb/golden_module_tb.py" \
    --module dcim_matmul --case peak_int8_all_tiles --verify-words 0 \
    --out-dir "$CASE_DIR"
elif command -v python.exe >/dev/null 2>&1; then
  # WSL may intentionally be minimal; reuse the Windows project's Python/numpy.
  python.exe "$(wslpath -w "$REPO_ROOT/project/rtl/tb/lite_bd/module_tb/golden_module_tb.py")" \
    --module dcim_matmul --case peak_int8_all_tiles --verify-words 0 \
    --out-dir "$(wslpath -w "$CASE_DIR")"
else
  echo "ERROR: golden generation needs numpy (WSL python3 or Windows python.exe)" >&2
  exit 2
fi

sources=(
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/para.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/counter.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/dff.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/inc/pipe_stage.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/multiplier.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/multiplier_dsp.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/adderTree.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/calculate_core.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/sramWrap.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/memory.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/dcim.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/maArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/mergeArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/accumulateArray.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/ppCache.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/postProcess.v"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/dcim/act_nibble_converter.sv"
  "$REPO_ROOT/project/rtl/ref/DCIM/src/model/model_rf_bram.sv"
  "$REPO_ROOT/project/rtl/common/uram_tdp_bytewrite.v"
  "$REPO_ROOT/project/rtl/chip/tile_ibuf.v"
  "$REPO_ROOT/project/rtl/chip/tile_obuf.v"
  "$REPO_ROOT/project/rtl/chip/DCIM_Tile.sv"
  "$REPO_ROOT/project/rtl/chip/DCIM_Array.sv"
  "$SCRIPT_DIR/dcim_peak_verilator_top.sv"
)

binary="$OBJ_DIR/V$TOP"
needs_build=0
[[ -x "$binary" ]] || needs_build=1
for source in "${sources[@]}" "$SCRIPT_DIR/dcim_peak_verilator.cpp"; do
  [[ ! -e "$binary" || "$source" -nt "$binary" ]] && needs_build=1
done
if [[ "$needs_build" -eq 1 ]]; then
  verilator --cc --trace --trace-depth 1 --top-module "$TOP" --prefix "V$TOP" \
    -DSIM -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
    -I"$REPO_ROOT/project/rtl/chip" -I"$REPO_ROOT/project/rtl/ref/DCIM/src/inc" \
    --output-split 20000 --output-split-cfuncs 100 \
    -Mdir "$OBJ_DIR" "${sources[@]}" \
    --exe "$SCRIPT_DIR/dcim_peak_verilator.cpp"
  make -C "$OBJ_DIR" -f "V$TOP.mk" -j"${VERILATOR_BUILD_JOBS:-4}"
else
  echo "Reusing cached Verilator binary: $binary"
fi
"$OBJ_DIR/V$TOP" "$CASE_DIR" "$CASE_DIR/peak_int8_verilator.vcd" \
  2>&1 | tee "$CASE_DIR/sim.log"

python3 "$REPO_ROOT/project/rtl/tb/lite_bd/module_tb/report_peak_int8.py" \
  --run-dir "$CASE_DIR" --simulator verilator
