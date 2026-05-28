#!/usr/bin/env bash
# Run all primary standalone regressions with VCS (DQA then QA).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/run_vcs_dqa_standalone.sh"
bash "$SCRIPT_DIR/run_vcs_qa_standalone.sh"

echo "All standalone VCS regressions PASS"
