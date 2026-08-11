#!/usr/bin/env bash
# Open the peak FSDB in nWave/Verdi and save a focused screenshot.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 RUN_DIR [OUTPUT_PNG]" >&2
  exit 2
fi

RUN_DIR="$(cd "$1" && pwd)"
FSDB="$RUN_DIR/tb_lite_bd_module.fsdb"
OUTPUT_PNG="${2:-$RUN_DIR/peak_verdi.png}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDI_TCL="$SCRIPT_DIR/verdi_peak.tcl"
VERDI_BIN="${VERDI_BIN:-/home/EDAtools/synopsys/verdi/V-2023.12-SP1/bin}"

[[ -f "$FSDB" ]] || { echo "ERROR: missing FSDB: $FSDB" >&2; exit 1; }
[[ -f "$VERDI_TCL" ]] || { echo "ERROR: missing Tcl: $VERDI_TCL" >&2; exit 1; }

export PATH="$VERDI_BIN:$PATH"
LOG="$RUN_DIR/verdi_peak.log"
XVFB_PID=""
WM_PID=""
NWAVE_PID=""

cleanup() {
  [[ -z "$NWAVE_PID" ]] || kill "$NWAVE_PID" 2>/dev/null || true
  [[ -z "$WM_PID" ]] || kill "$WM_PID" 2>/dev/null || true
  [[ -z "$XVFB_PID" ]] || kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

# nWave rejects xvfb-run's temporary Xauthority cookie on eda02. When no real
# display is present, start a private Xvfb with access control disabled instead.
if [[ -z "${DISPLAY:-}" ]]; then
  for DISPLAY_NUM in $(seq 109 129); do
    [[ -e "/tmp/.X11-unix/X${DISPLAY_NUM}" ]] && continue
    /usr/bin/Xvfb ":${DISPLAY_NUM}" -screen 0 1920x1080x24 -ac \
      >"$RUN_DIR/xvfb_peak.log" 2>&1 &
    XVFB_PID=$!
    export DISPLAY=":${DISPLAY_NUM}"
    for _ in $(seq 1 20); do
      /usr/bin/xdpyinfo >/dev/null 2>&1 && break
      kill -0 "$XVFB_PID" 2>/dev/null || break
      sleep 0.25
    done
    if /usr/bin/xdpyinfo >/dev/null 2>&1; then
      break
    fi
    kill "$XVFB_PID" 2>/dev/null || true
    XVFB_PID=""
    unset DISPLAY
  done
  [[ -n "${DISPLAY:-}" ]] || {
    echo "ERROR: could not start a private Xvfb display" >&2
    exit 1
  }

  if [[ -x /usr/bin/metacity ]]; then
    /usr/bin/metacity --sm-disable >"$RUN_DIR/metacity_peak.log" 2>&1 &
    WM_PID=$!
    sleep 1
  fi
fi

nWave -ssf "$FSDB" -play "$VERDI_TCL" >"$LOG" 2>&1 &
NWAVE_PID=$!

for _ in $(seq 1 30); do
  grep -q 'PEAK_VERDI_VIEW_READY' "$LOG" 2>/dev/null && break
  kill -0 "$NWAVE_PID" 2>/dev/null || {
    echo "ERROR: nWave exited before loading the view; see $LOG" >&2
    exit 1
  }
  sleep 1
done
grep -q 'PEAK_VERDI_VIEW_READY' "$LOG" || {
  echo "ERROR: timed out waiting for nWave; see $LOG" >&2
  exit 1
}

WMCTRL="${WMCTRL:-/home/EDAtools/synopsys/laker2023.06/bin/wmctrl}"
if [[ -x "$WMCTRL" ]]; then
  "$WMCTRL" -r nWave -b add,maximized_vert,maximized_horz 2>/dev/null || true
fi
sleep 2
/usr/bin/gnome-screenshot -f "$OUTPUT_PNG"
echo "VERDI_SCREENSHOT=$OUTPUT_PNG"
