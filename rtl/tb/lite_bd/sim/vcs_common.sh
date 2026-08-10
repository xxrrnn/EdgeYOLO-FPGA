#!/usr/bin/env bash
# Shared environment checks for the maintained lite-BD VCS runners.
set -euo pipefail

vcs_setup() {
  VIVADO_HOME="${VIVADO_HOME:-/home/EDAtools/Xilinx/Vivado/2024.2}"
  VCS="${VCS:-vcs}"
  VLOGAN="${VLOGAN:-vlogan}"

  if ! command -v "$VCS" >/dev/null 2>&1; then
    echo "ERROR: VCS not found (VCS=$VCS)" >&2
    exit 1
  fi
  if ! command -v "$VLOGAN" >/dev/null 2>&1; then
    echo "ERROR: vlogan not found (VLOGAN=$VLOGAN)" >&2
    exit 1
  fi

  XILINX_VCS_LIB="${XILINX_VCS_LIB:-/data/home/rn_xu29/Tools/vcs_lib}"
  if [[ ! -f "$XILINX_VCS_LIB/synopsys_sim.setup" ]]; then
    echo "ERROR: missing $XILINX_VCS_LIB/synopsys_sim.setup" >&2
    echo "  Set XILINX_VCS_LIB to a Vivado compile_simlib output." >&2
    exit 1
  fi
}
