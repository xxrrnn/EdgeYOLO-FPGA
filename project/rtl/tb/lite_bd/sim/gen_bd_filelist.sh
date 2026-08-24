#!/usr/bin/env bash
# Filelist for lite BD VCS sim. Prefers Vivado export; falls back to bd/lite/sim + ip netlists.
set -euo pipefail
OUT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
BD_DIR="$REPO_ROOT/bd/lite"
EXPORT_DIR="$REPO_ROOT/sim/lite_bd_export/vcs"

# LITE_GEN：FP IP 仿真模型所在目录，位于 build/lite/<tag>/lite.gen/sources_1/ip
# 解析优先级：
#   1. 环境变量 LITE_GEN（显式覆盖）
#   2. 环境变量 BUILD_TAG 指定的 tag（与 run.tcl / export_sim.tcl 保持一致）
#   3. build/lite/<latest_tag>/lite.gen/...（自动取最新含 lite.xpr 的子目录）
#   4. 旧路径 build/lite/lite.gen/...（向后兼容）
if [[ -z "${LITE_GEN:-}" ]]; then
  BUILD_TAG="${BUILD_TAG:-}"
  if [[ -n "$BUILD_TAG" ]] && [[ -d "$REPO_ROOT/build/lite/$BUILD_TAG/lite.gen/sources_1/ip" ]]; then
    LITE_GEN="$REPO_ROOT/build/lite/$BUILD_TAG/lite.gen/sources_1/ip"
  else
    # 自动找最新含 lite.xpr 的 build/<tag>
    _latest=$(ls -dt "$REPO_ROOT"/build/lite/*/lite.xpr 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
    if [[ -n "$_latest" ]] && [[ -d "$_latest/lite.gen/sources_1/ip" ]]; then
      LITE_GEN="$_latest/lite.gen/sources_1/ip"
    else
      # 向后兼容：旧路径 build/lite/lite.gen/...
      LITE_GEN="$REPO_ROOT/build/lite/lite.gen/sources_1/ip"
    fi
  fi
fi
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
$REPO_ROOT/project/rtl/tb/lite_bd/lite_xdma_constant_stub.v
$REPO_ROOT/project/rtl/tb/lite_bd/host_axi_master_bfm.sv
$REPO_ROOT/project/rtl/tb/lite_bd/tb_lite_bd_e2e.sv
EOF
} | emit

[[ -n "$OUT" ]] && echo "Wrote BD sim filelist -> $OUT"
