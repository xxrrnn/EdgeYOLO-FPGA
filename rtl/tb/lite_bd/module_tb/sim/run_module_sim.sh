#!/usr/bin/env bash
# Module-level BD simulation with compile-once/run-many flow.
set -euo pipefail

MODULE_SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_TB_DIR="$(cd "$MODULE_SIM_DIR/.." && pwd)"
LITE_BD_DIR="$(cd "$MODULE_TB_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LITE_BD_DIR/../../.." && pwd)"
source "$REPO_ROOT/rtl/vpu/tb/sim/vcs_common.sh"

vcs_setup

EXPORT_VCS_DIR="$REPO_ROOT/sim/lite_bd_export/vcs/lite/vcs"
BD_SIM_DIR="$LITE_BD_DIR/sim"

# ── 解析 BUILD_TAG → LITE_BUILD_DIR ──────────────────────────────────────────
# 优先用环境变量 BUILD_TAG；否则取 build/lite/ 下最新含 lite.xpr 的子目录。
# LITE_BUILD_DIR: build/lite/<tag>   （不含末尾 /）
# LITE_GEN      : .../lite.gen/sources_1/ip  传给 gen_bd_rtl_extra.sh
if [[ -z "${BUILD_TAG:-}" ]]; then
  _latest=$(ls -dt "$REPO_ROOT/build/lite"/*/lite.xpr 2>/dev/null | head -1)
  if [[ -n "$_latest" ]]; then
    BUILD_TAG="$(basename "$(dirname "$_latest")")"
  fi
fi
if [[ -z "${BUILD_TAG:-}" ]]; then
  echo "ERROR: no build found under $REPO_ROOT/build/lite/ — run vivado -source scripts/chip-lite/run.tcl first" >&2
  exit 1
fi
LITE_BUILD_DIR="$REPO_ROOT/build/lite/$BUILD_TAG"
export LITE_GEN="$LITE_BUILD_DIR/lite.gen/sources_1/ip"
echo "INFO: using BUILD_TAG=$BUILD_TAG  LITE_BUILD_DIR=$LITE_BUILD_DIR"

MODULE_CASE="${MODULE_CASE:-dcim_matmul}"
MODULE_VARIANT="${MODULE_VARIANT:-default}"
MODULE_VARIANTS="${MODULE_VARIANTS:-}"
MODULE_VERIFY_WORDS="${MODULE_VERIFY_WORDS:-0}"
MODULE_QUANT="${MODULE_QUANT:-int8}"
MODULE_DIM="${MODULE_DIM:-}"
FSDB="${FSDB:-0}"
RUN_EXPORT="${RUN_EXPORT:-0}"
FAST="${FAST:-1}"
VCS_JOBS="${VCS_JOBS:-64}"
SIMV_JOBS="${SIMV_JOBS:-32}"
ACTION="${ACTION:-sim}"
PRELOAD_MODE="${PRELOAD_MODE:-backdoor}"
case "$PRELOAD_MODE" in
  backdoor|axi) ;;
  *)
    echo "ERROR: unknown PRELOAD_MODE=$PRELOAD_MODE (use backdoor or axi)" >&2
    exit 1
    ;;
esac
SKIP_LITE_COMPILE="${SKIP_LITE_COMPILE:-1}"
TB_TOP="tb_lite_bd_module"

case_mode_slug() {
  local module="$1"
  local variant="$2"
  local quant="$3"
  if [[ "$module" == "dcim_matmul" ]]; then
    if [[ "$variant" == *int16* ]]; then
      printf 'dcim_int16'
    else
      printf 'dcim_int8'
    fi
  else
    printf 'q%s' "$quant"
  fi
}

_VARIANT_MODE_SLUG="$(case_mode_slug "$MODULE_CASE" "$MODULE_VARIANT" "$MODULE_QUANT")"
_VARIANT_SLUG="${MODULE_CASE}_${MODULE_VARIANT}_${_VARIANT_MODE_SLUG}"
RUN_DIR="${RUN_DIR:-$MODULE_SIM_DIR/run_${_VARIANT_SLUG}}"
SUITE_DIR="${SUITE_DIR:-$MODULE_SIM_DIR/suite_${MODULE_CASE}}"
COMPILE_DIR="${COMPILE_DIR:-$MODULE_SIM_DIR/build_shared}"
SIMV="$COMPILE_DIR/simv"
GOLDEN_PY="$MODULE_TB_DIR/golden_module_tb.py"

if [[ "$RUN_EXPORT" == "1" ]]; then
  echo "=== Vivado export_simulation (lite BD) ==="
  vivado -mode batch -source "$REPO_ROOT/scripts/chip-lite/4_export_sim.tcl" \
    2>&1 | tee "$REPO_ROOT/sim/lite_bd_export/export.log"
fi

[[ -f "$EXPORT_VCS_DIR/lite.sh" ]] || {
  echo "ERROR: missing export scripts at $EXPORT_VCS_DIR — run RUN_EXPORT=1 first" >&2
  exit 1
}

compile_simv() {
  mkdir -p "$COMPILE_DIR"
  echo "=== BD IP compile (shared with parent) ==="
  unset SYNOPSYS_SIM_SETUP
  if [[ "$SKIP_LITE_COMPILE" == "1" && -d "$EXPORT_VCS_DIR/vcs_lib/xil_defaultlib" ]]; then
    if ls "$EXPORT_VCS_DIR/vcs_lib/xil_defaultlib"/lite.* >/dev/null 2>&1; then
      echo "INFO: SKIP_LITE_COMPILE=1, reuse existing compile"
      _missing_sim=0
      for _lib in axi_datamover_v5_1_36 axi_sg_v4_1_20 axi_cdma_v4_1_34; do
        if ! ls "$EXPORT_VCS_DIR/vcs_lib/$_lib/64/"*.sim >/dev/null 2>&1; then
          _missing_sim=1; break
        fi
      done
      if [[ "$_missing_sim" == "1" ]]; then
        echo "INFO: VHDL .sim files missing, running lite.sh -step elaborate to restore..."
        (cd "$EXPORT_VCS_DIR"; ./lite.sh -lib_map_path "$XILINX_VCS_LIB" -step elaborate \
          2>&1 | tail -5 | tee -a "$COMPILE_DIR/export_compile.log")
      fi
    else
      echo "INFO: lite module missing, recompiling..."
      (cd "$EXPORT_VCS_DIR"; ./lite.sh -lib_map_path "$XILINX_VCS_LIB" -step compile \
        2>&1 | tee "$COMPILE_DIR/export_compile.log")
      # rm -rf "$EXPORT_VCS_DIR/vcs_lib/hbm_v1_0_16"  # 保留库，只替换顶层
    fi
  else
    (cd "$EXPORT_VCS_DIR"; ./lite.sh -lib_map_path "$XILINX_VCS_LIB" -step compile \
      2>&1 | tee "$COMPILE_DIR/export_compile.log")
  fi

  # HBM 行为仿真模型包含 PHY calibration 序列，会导致仿真极慢（数小时）。
  # module_tb 数据路径完全走片上 URAM（OBUF/IBUF），不经过 HBM。
  # 保留 hbm_v1_0_16 库（内部子模块），仅用 lite_hbm_stub.sv 替换 lite_hbm_0_0 顶层
  # （apb_complete_0=1，AXI 输出置零，无 PHY calibration 行为）。
  # echo "=== Removing HBM PHY sim model from vcs_lib (replaced by fast stub) ==="
  # rm -rf "$EXPORT_VCS_DIR/vcs_lib/hbm_v1_0_16"

  rm -f "$SIMV" "$COMPILE_DIR/vlogan_rtl_extra.log" "$COMPILE_DIR/vlogan_tb.log" \
    "$COMPILE_DIR/compile.log" "$COMPILE_DIR/rtl_extra.f"
  rm -rf "$COMPILE_DIR/simv.daidir"

  export SYNOPSYS_SIM_SETUP="$EXPORT_VCS_DIR/synopsys_sim.setup"

  VERDI_PLI_DIR="/home/EDAtools/synopsys/verdi/V-2023.12-SP1/share/PLI/VCS/LINUX64"
  vcs_parallel_opts=()
  if [[ "$VCS_JOBS" =~ ^[0-9]+$ && "$VCS_JOBS" -gt 1 ]]; then
    vcs_parallel_opts=(-j"$VCS_JOBS")
  fi
  vcs_elab_opts=(-full64 -ignore initializer_driver_checks +notimingcheck +nospecify -t ps
                 -P "$VERDI_PLI_DIR/novas.tab" "$VERDI_PLI_DIR/pli.a")
  if [[ "$FAST" == "0" || "$FSDB" == "1" ]]; then
    vcs_elab_opts+=(-debug_access+all)
  fi
  if [[ "$FSDB" == "1" ]]; then
    vcs_elab_opts+=(-kdb -lca -debug_region+cell+encrypt +vcs+fsdbon)
  fi

  inc=(
    "+incdir+$REPO_ROOT/rtl/chip"
    "+incdir+$REPO_ROOT/rtl/vpu"
    "+incdir+$REPO_ROOT/rtl/common"
    "+incdir+$LITE_BD_DIR"
    "+incdir+$MODULE_TB_DIR"
    "+incdir+$LITE_BUILD_DIR/lite.ip_user_files/bd/lite/ip/lite_xdma_0_0/ip_0/source"
    "+incdir+$REPO_ROOT/bd/lite/ipshared/eebc/hdl/verilog"
    "+incdir+$LITE_BUILD_DIR/lite.ip_user_files/bd/lite/ip/lite_hbm_0_0/hdl/rtl"
    "+incdir+$REPO_ROOT/bd/lite/ipshared/7b8c/verif/model"
    "+define+SIMULATION"
  )
  if [[ "${FP32_2_INT16_BEHAVIORAL:-1}" == "1" ]]; then
    inc+=("+define+FP32_2_INT16_BEHAVIORAL")
  fi

  echo "=== Vlogan user RTL into xil_defaultlib ==="
  EXTRA_FL="$COMPILE_DIR/rtl_extra.f"
  bash "$BD_SIM_DIR/gen_bd_rtl_extra.sh" "$EXTRA_FL"
  (cd "$EXPORT_VCS_DIR"
    "$VLOGAN" "${vcs_parallel_opts[@]}" -full64 -sverilog +v2k "${inc[@]}" -work xil_defaultlib \
      -f "$EXTRA_FL" -l "$COMPILE_DIR/vlogan_rtl_extra.log")

  echo "=== Vlogan HBM fast stub (replaces PHY calibration model) ==="
  (cd "$EXPORT_VCS_DIR"
    "$VLOGAN" "${vcs_parallel_opts[@]}" -full64 -sverilog +v2k "${inc[@]}" -work xil_defaultlib \
      "$LITE_BD_DIR/lite_hbm_stub.sv" \
      -l "$COMPILE_DIR/vlogan_hbm_stub.log")

  echo "=== Vlogan module TB (work) ==="
  (cd "$EXPORT_VCS_DIR"
    mkdir -p vcs_lib/work
    "$VLOGAN" "${vcs_parallel_opts[@]}" -full64 -sverilog +v2k "${inc[@]}" -work work \
      "$LITE_BD_DIR/lite_xdma_constant_stub.v" \
      "$LITE_BD_DIR/host_axi_master_bfm.sv" \
      "$MODULE_TB_DIR/tb_lite_bd_module.sv" \
      -l "$COMPILE_DIR/vlogan_tb.log")

  echo "=== VCS elaborate module TB + lite ==="
  (cd "$EXPORT_VCS_DIR"
    "$VCS" "${vcs_parallel_opts[@]}" "${vcs_elab_opts[@]}" \
      work."$TB_TOP" xil_defaultlib.lite xil_defaultlib.glbl \
      -o "$SIMV" -l "$COMPILE_DIR/compile.log")
}

generate_run_dir() {
  mkdir -p "$RUN_DIR"
  mode_slug="$(case_mode_slug "$MODULE_CASE" "$MODULE_VARIANT" "$MODULE_QUANT")"
  echo "=== Generate module golden module=$MODULE_CASE case=$MODULE_VARIANT mode=$mode_slug ==="
  extra_args=()
  if [[ "$MODULE_CASE" == "dcim_matmul" ]]; then
    if [[ "$MODULE_VARIANT" == *int16* ]]; then
      extra_args+=(--quant int16)
    else
      extra_args+=(--quant int8)
    fi
  elif [[ -n "$MODULE_QUANT" ]]; then
    extra_args+=(--quant "$MODULE_QUANT")
  fi
  [[ -n "$MODULE_DIM"   ]] && extra_args+=(--dim "$MODULE_DIM")
  python3 "$GOLDEN_PY" --module "$MODULE_CASE" --case "$MODULE_VARIANT" \
    --verify-words "$MODULE_VERIFY_WORDS" --out-dir "$RUN_DIR" ${extra_args[@]+"${extra_args[@]}"}
  if [[ -f "$RUN_DIR/skipped.txt" ]]; then
    cat "$RUN_DIR/skipped.txt"
    echo "SKIP: quant/case mismatch (not a simulation failure)"
    exit 0
  fi
}

ensure_simv() {
  if [[ ! -x "$SIMV" ]]; then
    compile_simv
  else
    echo "=== Reuse shared simv: $SIMV ==="
  fi
}

summarize_log() {
  [[ $# -ge 1 ]] || return 0
  grep -E "(MODULE_TB|MODULE RESULTS|MODULE CHECK|FATAL|MISMATCH|Decoder done)" "$1" | tail -120 || true
}

check_log_pass() {
  local log_file="${1:-}"
  local label="${2:-unknown}"
  [[ -n "$log_file" ]] || {
    echo "ERROR: check_log_pass missing log file" >&2
    exit 1
  }
  if grep -q 'MODULE CHECK FAILED\|FATAL' "$log_file"; then
    echo "ERROR: module BD simulation FAILED ($label, see $log_file)" >&2
    exit 1
  fi
  if grep -q 'MODULE CHECK PASSED' "$log_file"; then
    echo "MODULE BD VCS PASS ($label)"
  else
    echo "ERROR: module BD sim did not report MODULE CHECK PASSED ($label)" >&2
    exit 1
  fi
}

run_simv() {
  [[ -x "$SIMV" ]] || {
    echo "ERROR: missing shared simv: $SIMV" >&2
    echo "  → run ACTION=compile bash $0 or make compile" >&2
    exit 1
  }
  [[ -f "$RUN_DIR/inst.hex" ]] || {
    echo "ERROR: missing run data: $RUN_DIR/inst.hex" >&2
    echo "  → run ACTION=gen bash $0 or make data" >&2
    exit 1
  }
  sim_opts=(+notimingcheck +nospecify "+RUN_DIR=$RUN_DIR" "+PRELOAD_MODE=$PRELOAD_MODE" -no_save)
  if [[ "$SIMV_JOBS" =~ ^[0-9]+$ && "$SIMV_JOBS" -gt 1 ]]; then
    sim_opts=(-j"$SIMV_JOBS" "${sim_opts[@]}")
  fi
  if [[ "$FSDB" == "1" ]]; then
    sim_opts+=(+FSDB)
  fi
  echo "=== VCS simulate module BD test (reuse simv, PRELOAD_MODE=$PRELOAD_MODE) ==="
  (cd "$RUN_DIR"
    "$SIMV" "${sim_opts[@]}" 2>&1 | grep -v '^IEEE1500' | tee sim.log)
  echo "=== sim.log written: $RUN_DIR/sim.log ==="

  summarize_log "$RUN_DIR/sim.log"
  check_log_pass "$RUN_DIR/sim.log" "module=$MODULE_CASE case=$MODULE_VARIANT mode=$(case_mode_slug "$MODULE_CASE" "$MODULE_VARIANT" "$MODULE_QUANT")"
}

generate_suite_dir() {
  [[ -n "$MODULE_VARIANTS" ]] || {
    echo "ERROR: MODULE_VARIANTS is empty for suite generation" >&2
    exit 1
  }
  rm -rf "$SUITE_DIR"
  mkdir -p "$SUITE_DIR"
  : > "$SUITE_DIR/suite.txt"
  echo "=== Generate suite module=$MODULE_CASE variants=$MODULE_VARIANTS quant=$MODULE_QUANT ==="
  if [[ "$MODULE_CASE" == "dcim_matmul" ]]; then
    for v in $MODULE_VARIANTS; do
      mode_slug="$(case_mode_slug "$MODULE_CASE" "$v" "$MODULE_QUANT")"
      case_name="run_${MODULE_CASE}_${v}_${mode_slug}"
      case_dir="$SUITE_DIR/$case_name"
      extra_args=()
      [[ -n "$MODULE_DIM" ]] && extra_args+=(--dim "$MODULE_DIM")
      python3 "$GOLDEN_PY" --module "$MODULE_CASE" --case "$v" \
        --verify-words "$MODULE_VERIFY_WORDS" --out-dir "$case_dir" ${extra_args[@]+"${extra_args[@]}"}
      printf '%s\n' "$case_name" >> "$SUITE_DIR/suite.txt"
    done
  else
    quant_list="$MODULE_QUANT"
    [[ "$quant_list" == "all" ]] && quant_list="int8 int16"
    for q in $quant_list; do
      for v in $MODULE_VARIANTS; do
        mode_slug="$(case_mode_slug "$MODULE_CASE" "$v" "$q")"
        case_name="run_${MODULE_CASE}_${v}_${mode_slug}"
        case_dir="$SUITE_DIR/$case_name"
        extra_args=()
        [[ -n "$q" ]] && extra_args+=(--quant "$q")
        [[ -n "$MODULE_DIM" ]] && extra_args+=(--dim "$MODULE_DIM")
        python3 "$GOLDEN_PY" --module "$MODULE_CASE" --case "$v" \
          --verify-words "$MODULE_VERIFY_WORDS" --out-dir "$case_dir" ${extra_args[@]+"${extra_args[@]}"}
        printf '%s\n' "$case_name" >> "$SUITE_DIR/suite.txt"
      done
    done
  fi
  echo "Generated suite dir: $SUITE_DIR"
}

run_suite_simv() {
  [[ -x "$SIMV" ]] || {
    echo "ERROR: missing shared simv: $SIMV" >&2
    echo "  → run ACTION=compile bash $0 or make compile" >&2
    exit 1
  }
  [[ -f "$SUITE_DIR/suite.txt" ]] || {
    echo "ERROR: missing suite file: $SUITE_DIR/suite.txt" >&2
    echo "  → run ACTION=gen-suite bash $0 or make data-suite" >&2
    exit 1
  }
  sim_opts=(+notimingcheck +nospecify "+RUN_DIR=$SUITE_DIR" "+SUITE_FILE=$SUITE_DIR/suite.txt" "+PRELOAD_MODE=$PRELOAD_MODE" -no_save)
  if [[ "$SIMV_JOBS" =~ ^[0-9]+$ && "$SIMV_JOBS" -gt 1 ]]; then
    sim_opts=(-j"$SIMV_JOBS" "${sim_opts[@]}")
  fi
  if [[ "$FSDB" == "1" ]]; then
    sim_opts+=(+FSDB)
  fi
  echo "=== VCS simulate module BD suite (reuse simv, PRELOAD_MODE=$PRELOAD_MODE) ==="
  (cd "$SUITE_DIR"
    "$SIMV" "${sim_opts[@]}" 2>&1 | grep -v '^IEEE1500' | tee sim.log)
  echo "=== suite sim.log written: $SUITE_DIR/sim.log ==="

  summarize_log "$SUITE_DIR/sim.log"
  check_log_pass "$SUITE_DIR/sim.log" "suite=$SUITE_DIR"
}

case "$ACTION" in
  compile)
    compile_simv
    ;;
  gen)
    generate_run_dir
    ;;
  run)
    run_simv
    ;;
  sim)
    generate_run_dir
    ensure_simv
    run_simv
    ;;
  rebuild-sim)
    generate_run_dir
    compile_simv
    run_simv
    ;;
  gen-suite)
    generate_suite_dir
    ;;
  run-suite)
    run_suite_simv
    ;;
  sim-suite)
    generate_suite_dir
    ensure_simv
    run_suite_simv
    ;;
  rebuild-suite)
    generate_suite_dir
    compile_simv
    run_suite_simv
    ;;
  *)
    echo "ERROR: unknown ACTION=$ACTION (compile|gen|run|sim|rebuild-sim|gen-suite|run-suite|sim-suite|rebuild-suite)" >&2
    exit 1
    ;;
esac
