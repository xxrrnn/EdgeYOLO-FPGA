#!/usr/bin/env bash
# Filelist for lite BD VCS sim. Prefers Vivado export; falls back to bd/lite/sim + ip netlists.
set -euo pipefail
OUT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BD_DIR="$REPO_ROOT/bd/lite"
EXPORT_DIR="$REPO_ROOT/sim/lite_bd_export/vcs"
LITE_GEN="${LITE_GEN:-$REPO_ROOT/build/lite/lite.gen/sources_1/ip}"
VIVADO_HOME="${VIVADO_HOME:-/home/EDAtools/Xilinx/Vivado/2024.2}"

die() { echo "ERROR: $*" >&2; exit 1; }
emit() { if [[ -n "$OUT" ]]; then cat >"$OUT"; else cat; fi; }

{
  # Vivado export (after scripts/chip-lite/3_export_sim.tcl)
  if [[ -f "$EXPORT_DIR/filelist.f" ]]; then
    echo "# Vivado export_simulation filelist"
    sed 's/^\s*\+incdir/+incdir+/g' "$EXPORT_DIR/filelist.f" | grep -v '^$' || true
    if [[ -f "$EXPORT_DIR/glbl.v" ]]; then
      echo "$EXPORT_DIR/glbl.v"
    elif [[ -f "$VIVADO_HOME/data/verilog/src/glbl.v" ]]; then
      echo "$VIVADO_HOME/data/verilog/src/glbl.v"
    fi
  else
    echo "# Fallback: bd/lite sim netlists (no export dir at $EXPORT_DIR)"
    echo "$BD_DIR/hdl/lite_wrapper.v"
    echo "$BD_DIR/sim/lite.v"
    for f in "$BD_DIR"/ip/*/*_sim_netlist.v; do
      [[ -f "$f" ]] && echo "$f"
    done
    if [[ -f "$VIVADO_HOME/data/verilog/src/glbl.v" ]]; then
      echo "$VIVADO_HOME/data/verilog/src/glbl.v"
    fi
  fi

  [[ -d "$LITE_GEN" ]] || die "missing LITE_GEN: $LITE_GEN"
  for ip in fp32_mac fp32_add fp32_compare_leq fp32_to_int8 fp32_to_fixed8 int32_2_fp32 \
              fp32_mult_lane fp32_add_lane fixed32_to_fp32 fp16_mac fp16_add fp16_2_int8 fp32_2_fp16; do
    echo "$LITE_GEN/$ip/sim/$ip.v"
  done

  cat <<EOF
$REPO_ROOT/rtl/tb/lite_bd/lite_xdma_constant_stub.v
$REPO_ROOT/rtl/tb/lite_bd/host_axi_master_bfm.sv
$REPO_ROOT/rtl/tb/lite_bd/tb_lite_bd_e2e.sv
EOF
} | emit

[[ -n "$OUT" ]] && echo "Wrote BD sim filelist -> $OUT"
