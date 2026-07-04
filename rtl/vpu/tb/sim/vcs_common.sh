#!/usr/bin/env bash
# Shared VCS helpers for VPU standalone regressions.
set -euo pipefail

vcs_setup() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  VIVADO_HOME="${VIVADO_HOME:-/home/EDAtools/Xilinx/Vivado/2024.2}"
  LITE_GEN="${LITE_GEN:-$REPO_ROOT/build/lite/lite.gen/sources_1/ip}"
  VCS="${VCS:-vcs}"
  VLOGAN="${VLOGAN:-vlogan}"
  GEN_DIR="$REPO_ROOT/rtl/vpu/tb/standalone/generated"
  STANDALONE_SCALE="${STANDALONE_SCALE:-1.0}"
  ONLY_CASE="${ONLY_CASE:-}"

  if ! command -v "$VCS" >/dev/null 2>&1; then
    echo "ERROR: VCS not found (VCS=$VCS)" >&2
    exit 1
  fi
  if ! command -v "$VLOGAN" >/dev/null 2>&1; then
    echo "ERROR: vlogan not found (VLOGAN=$VLOGAN)" >&2
    exit 1
  fi
  XILINX_VCS_LIB="${XILINX_VCS_LIB:-/data/home/rn_xu29/Tools/vcs_lib}"
}

vcs_gen_golden() {
  local target="$1"
  local py=""
  case "$target" in
    qa)  py="$REPO_ROOT/tools/golden_qa_standalone.py" ;;
    dqa) py="$REPO_ROOT/tools/golden_dqa_standalone.py" ;;
    *) echo "ERROR: unknown golden target '$target'" >&2; return 1 ;;
  esac
  echo "=== Generate ${target^^} golden (scale=$STANDALONE_SCALE) ==="
  python3 "$py" --scale "$STANDALONE_SCALE" --out-dir "$GEN_DIR"
}

vcs_prepare_build() {
  local target="$1"
  local build_dir="$2"
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  bash "$SCRIPT_DIR/gen_standalone_filelist.sh" "$target" "$build_dir/filelist.f"
  ln -sfn "$GEN_DIR/hex" "$build_dir/hex"
}

vcs_write_synopsys_setup() {
  local build_dir="$1"
  local setup="$build_dir/synopsys_sim.setup"
  [[ -d "$XILINX_VCS_LIB" ]] || {
    echo "ERROR: XILINX_VCS_LIB not found: $XILINX_VCS_LIB" >&2
    echo "  Run Vivado compile_simlib -simulator vcs first, or set XILINX_VCS_LIB." >&2
    exit 1
  }
  [[ -f "$XILINX_VCS_LIB/synopsys_sim.setup" ]] || {
    echo "ERROR: missing $XILINX_VCS_LIB/synopsys_sim.setup" >&2
    exit 1
  }
  cat >"$setup" <<EOF
WORK > DEFAULT
DEFAULT : ./vcs_lib/work
LIBRARY_SCAN=TRUE
work : ./vcs_lib/work
OTHERS : $XILINX_VCS_LIB/synopsys_sim.setup
EOF
}

vcs_compile() {
  local tb_top="$1"
  local build_dir="$2"
  local simv="$build_dir/simv"

  local inc=(
    "+incdir+$REPO_ROOT/rtl/chip"
    "+incdir+$REPO_ROOT/rtl/vpu"
    "+incdir+$GEN_DIR"
  )

  vcs_write_synopsys_setup "$build_dir"

  echo "=== VCS compile: top=$tb_top (XILINX_VCS_LIB=$XILINX_VCS_LIB) ==="
  (
    cd "$build_dir"
    export SYNOPSYS_SIM_SETUP="$build_dir/synopsys_sim.setup"
    mkdir -p vcs_lib/work

    # Two-step flow (matches Vivado export_simulation for encrypted FP IP)
    "$VLOGAN" -full64 -sverilog +v2k "${inc[@]}" \
      -work work \
      -f filelist.f \
      -l vlogan.log

    "$VCS" -full64 -debug_access+all \
      -ignore initializer_driver_checks \
      work."$tb_top" \
      -o simv \
      -l compile.log
  )
  [[ -x "$simv" ]] || { echo "ERROR: simv missing after compile (see $build_dir/vlogan.log compile.log)" >&2; exit 1; }
}

vcs_run() {
  local build_dir="$1"
  shift
  local plusargs=()
  if [[ -n "${ONLY_CASE:-}" ]]; then
    plusargs+=("+ONLY_CASE=$ONLY_CASE")
  fi

  echo "=== VCS simulate ==="
  (
    cd "$build_dir"
    if ((${#plusargs[@]})); then
      ./simv "${plusargs[@]}" "$@" 2>&1 | tee sim.log
    else
      ./simv "$@" 2>&1 | tee sim.log
    fi
  )

  echo "=== Result summary ==="
  grep -E "(PASS|FAIL|TIMEOUT|Summary|FATAL)" "$build_dir/sim.log" || true

  if grep -qE 'FATAL| regression FAILED|TIMEOUT case' "$build_dir/sim.log"; then
    echo "ERROR: simulation reported failure (see $build_dir/sim.log)" >&2
    exit 1
  fi
  if grep -q 'FAIL \[' "$build_dir/sim.log"; then
    echo "ERROR: one or more cases FAILED (see $build_dir/sim.log)" >&2
    exit 1
  fi
}
