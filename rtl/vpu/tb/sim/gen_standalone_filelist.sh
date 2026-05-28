#!/usr/bin/env bash
# Generate simulator-neutral filelist for QA/DQA standalone (VCS / xsim).
# Usage: gen_standalone_filelist.sh {qa|dqa} [output.f]
set -euo pipefail

TARGET="${1:-}"
OUT="${2:-}"
if [[ -z "$TARGET" ]]; then
  echo "usage: gen_standalone_filelist.sh qa|dqa [output.f]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
VIVADO_HOME="${VIVADO_HOME:-/home/EDAtools/Xilinx/Vivado/2024.2}"
LITE_GEN="${LITE_GEN:-$REPO_ROOT/build/lite/lite.gen/sources_1/ip}"

OBUF="$REPO_ROOT/rtl/DCIM_Macro/obuf.v"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$VIVADO_HOME" ]] || die "missing VIVADO_HOME: $VIVADO_HOME"
[[ -d "$LITE_GEN" ]] || die "missing LITE_GEN: $LITE_GEN (build lite project first)"

emit() {
  if [[ -n "$OUT" ]]; then
    cat >"$OUT"
    echo "Wrote filelist -> $OUT"
  else
    cat
  fi
}

case "$TARGET" in
  qa)
    [[ -f "$LITE_GEN/fp32_mac/sim/fp32_mac.v" ]] || die "missing fp32_mac sim model"
    [[ -f "$LITE_GEN/fp32_to_int8/sim/fp32_to_int8.v" ]] || die "missing fp32_to_int8 sim model"
    emit <<EOF
# Auto-generated QA standalone filelist (do not edit; use gen_standalone_filelist.sh)
# FP IP: link floating_point_v7_1_19 via XILINX_VCS_LIB (not rfs.v)

$LITE_GEN/fp32_mac/sim/fp32_mac.v
$LITE_GEN/fp32_to_int8/sim/fp32_to_int8.v
$REPO_ROOT/rtl/vpu/fp_array/fp_mac_array.v
$REPO_ROOT/rtl/vpu/fp_array/fp32_2_int8_array.sv
$REPO_ROOT/rtl/vpu/qa_unit.sv
$OBUF
$REPO_ROOT/rtl/vpu/tb/standalone/tb_qa_standalone.sv
EOF
    ;;
  dqa)
    [[ -f "$LITE_GEN/fp32_mac/sim/fp32_mac.v" ]] || die "missing fp32_mac sim model"
    [[ -f "$LITE_GEN/int32_2_fp32/sim/int32_2_fp32.v" ]] || die "missing int32_2_fp32 sim model"
    emit <<EOF
# Auto-generated DQA standalone filelist (do not edit; use gen_standalone_filelist.sh)
# FP IP: link floating_point_v7_1_19 via XILINX_VCS_LIB (not rfs.v)

$LITE_GEN/fp32_mac/sim/fp32_mac.v
$LITE_GEN/int32_2_fp32/sim/int32_2_fp32.v
$REPO_ROOT/rtl/vpu/fp_array/fp_mac_array.v
$REPO_ROOT/rtl/vpu/fp_array/int32_2_fp32_array.sv
$OBUF
$REPO_ROOT/rtl/vpu/dqa_relu_unit.sv
$REPO_ROOT/rtl/vpu/tb/standalone/tb_dqa_standalone.sv
EOF
    ;;
  *)
    die "unknown target '$TARGET' (expected qa or dqa)"
    ;;
esac
