#!/usr/bin/env bash
# Save the focused pipeline FSDB view as a PNG, using a private Xvfb if needed.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 RUN_DIR [OUTPUT_PNG]" >&2
  exit 2
fi
RUN_DIR="$(cd "$1" && pwd)"
FSDB="$RUN_DIR/tb_dcim_pipeline_peak.fsdb"
OUTPUT_PNG="${2:-$RUN_DIR/pipeline_verdi.png}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDI_TCL="$SCRIPT_DIR/verdi_pipeline.tcl"
VERDI_BIN="${VERDI_BIN:-/home/EDAtools/synopsys/verdi/V-2023.12-SP1/bin}"
[[ -f "$FSDB" ]] || { echo "ERROR: missing FSDB: $FSDB" >&2; exit 1; }

export PATH="$VERDI_BIN:$PATH"
LOG="$RUN_DIR/verdi_pipeline.log"
XVFB_PID=""
WM_PID=""
NWAVE_PID=""
cleanup() {
  [[ -z "$NWAVE_PID" ]] || kill "$NWAVE_PID" 2>/dev/null || true
  [[ -z "$WM_PID" ]] || kill "$WM_PID" 2>/dev/null || true
  [[ -z "$XVFB_PID" ]] || kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -z "${DISPLAY:-}" ]] || ! /usr/bin/xdpyinfo >/dev/null 2>&1; then
  unset DISPLAY
  for display_num in $(seq 130 150); do
    [[ -e "/tmp/.X11-unix/X${display_num}" ]] && continue
    /usr/bin/Xvfb ":${display_num}" -screen 0 1920x1080x24 -ac \
      >"$RUN_DIR/xvfb_pipeline.log" 2>&1 &
    XVFB_PID=$!
    export DISPLAY=":${display_num}"
    for _ in $(seq 1 20); do
      /usr/bin/xdpyinfo >/dev/null 2>&1 && break
      sleep 0.25
    done
    /usr/bin/xdpyinfo >/dev/null 2>&1 && break
    kill "$XVFB_PID" 2>/dev/null || true
    XVFB_PID=""
    unset DISPLAY
  done
  [[ -n "${DISPLAY:-}" ]] || { echo "ERROR: could not start Xvfb" >&2; exit 1; }
  if [[ -x /usr/bin/metacity ]]; then
    /usr/bin/metacity --sm-disable >"$RUN_DIR/metacity_pipeline.log" 2>&1 &
    WM_PID=$!
    sleep 1
  fi
fi

nWave -ssf "$FSDB" -play "$VERDI_TCL" >"$LOG" 2>&1 &
NWAVE_PID=$!
for _ in $(seq 1 30); do
  grep -q 'PIPELINE_VERDI_VIEW_READY' "$LOG" 2>/dev/null && break
  kill -0 "$NWAVE_PID" 2>/dev/null || {
    echo "ERROR: nWave exited; see $LOG" >&2
    exit 1
  }
  sleep 1
done
grep -q 'PIPELINE_VERDI_VIEW_READY' "$LOG" || {
  echo "ERROR: timed out waiting for nWave; see $LOG" >&2
  exit 1
}
WMCTRL="${WMCTRL:-/home/EDAtools/synopsys/laker2023.06/bin/wmctrl}"
[[ -x "$WMCTRL" ]] && "$WMCTRL" -r nWave -b add,maximized_vert,maximized_horz 2>/dev/null || true
sleep 2
/usr/bin/gnome-screenshot -f "$OUTPUT_PNG"
echo "PIPELINE_VERDI_SCREENSHOT=$OUTPUT_PNG"
