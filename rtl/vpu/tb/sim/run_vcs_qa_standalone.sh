#!/usr/bin/env bash
# run_vcs_qa_standalone.sh - VCS regression for tb_qa_standalone
#
# Usage:
#   bash rtl/vpu/tb/sim/run_vcs_qa_standalone.sh
#   STANDALONE_SCALE=1.0 bash rtl/vpu/tb/sim/run_vcs_qa_standalone.sh
#   ONLY_CASE=2 STANDALONE_SCALE=0.1 bash rtl/vpu/tb/sim/run_vcs_qa_standalone.sh  # fast smoke
#
# Env:
#   STANDALONE_SCALE  default 1.0 (network original spatial params)
#   ONLY_CASE         optional 0|1|2 to run a single layer case
#   VIVADO_HOME       Vivado install (FP IP rfs.v)
#   LITE_GEN          path to lite.gen/.../ip (default build/lite/...)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vcs_common.sh
source "$SCRIPT_DIR/vcs_common.sh"

vcs_setup
BUILD_DIR="$SCRIPT_DIR/build_vcs_qa"

vcs_gen_golden qa
vcs_prepare_build qa "$BUILD_DIR"
vcs_compile tb_qa_standalone "$BUILD_DIR"
vcs_run "$BUILD_DIR"

echo "QA standalone VCS PASS"
