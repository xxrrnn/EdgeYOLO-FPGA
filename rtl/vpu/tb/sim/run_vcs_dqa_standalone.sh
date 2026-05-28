#!/usr/bin/env bash
# run_vcs_dqa_standalone.sh - VCS regression for tb_dqa_standalone
#
# Usage:
#   bash rtl/vpu/tb/sim/run_vcs_dqa_standalone.sh
#   ONLY_CASE=2 STANDALONE_SCALE=0.1 bash rtl/vpu/tb/sim/run_vcs_dqa_standalone.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vcs_common.sh
source "$SCRIPT_DIR/vcs_common.sh"

vcs_setup
BUILD_DIR="$SCRIPT_DIR/build_vcs_dqa"

vcs_gen_golden dqa
vcs_prepare_build dqa "$BUILD_DIR"
vcs_compile tb_dqa_standalone "$BUILD_DIR"
vcs_run "$BUILD_DIR"

echo "DQA standalone VCS PASS"
