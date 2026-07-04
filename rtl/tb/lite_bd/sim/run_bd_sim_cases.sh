#!/usr/bin/env bash
# Run all lite BD conv-chain cases; print a per-case PASS/FAIL summary at the end.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build_bd_sim"
CASES=(default bottleneck3x3 downsample c3_deep)
BD_VERIFY_WORDS="${BD_VERIFY_WORDS:-${E2E_VERIFY_WORDS:-0}}"
BD_SCALE="${BD_SCALE:-${E2E_SCALE:-0.1}}"
BD_MODE="${BD_MODE:-fast}"
FAIL=0
declare -a CASE_STATUS=()

for c in "${CASES[@]}"; do
  echo ""
  echo "################################################################"
  echo "# BD sim case: $c  (mode=$BD_MODE scale=$BD_SCALE verify_words=$BD_VERIFY_WORDS)"
  echo "################################################################"
  if BD_CASE="$c" BD_SCALE="$BD_SCALE" BD_VERIFY_WORDS="$BD_VERIFY_WORDS" BD_MODE="$BD_MODE" \
     bash "$SCRIPT_DIR/run_bd_sim.sh"; then
    CASE_STATUS+=("$c:PASS")
    echo ">>> CASE $c: PASS"
  else
    FAIL=1
    CASE_STATUS+=("$c:FAIL")
    echo ">>> CASE $c: FAIL (see $BUILD_DIR/sim.log)"
  fi
  if [[ -f "$BUILD_DIR/sim.log" ]]; then
    cp -f "$BUILD_DIR/sim.log" "$BUILD_DIR/sim_${c}.log"
    echo "--- $c checkpoint summary (from sim.log) ---"
    grep -E '^(--- compare |--- L[0-9]|  GRAND|  ALL CHECKPOINTS|  SOME CHECKPOINTS|FATAL)' \
      "$BUILD_DIR/sim_${c}.log" | tail -20 || true
  fi
done

echo ""
echo "==================== BD cases summary ===================="
for s in "${CASE_STATUS[@]}"; do printf '  %s\n' "$s"; done
if [[ "$FAIL" -eq 0 ]]; then
  echo "OVERALL: ALL CASES PASSED"
else
  echo "OVERALL: SOME CASES FAILED"
fi
echo "Per-case logs: $BUILD_DIR/sim_<case>.log"
exit $FAIL
