#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
cd "$repo_root"

vivado_bin="${VIVADO:-vivado}"
tag="${WEIGHT_CACHE_TIMING_TAG:-$(date +%y%m%d_%H%M%S)}"
out_root="$repo_root/test/tops/output/fpga/weight_cache_timing/$tag"
mkdir -p "$out_root/baseline" "$out_root/replicated"

pids=()
for variant in baseline replicated; do
  "$vivado_bin" -mode batch -nolog -nojournal \
    -source "$repo_root/test/tops/fpga/synth/weight_cache_timing/run_variant.tcl" \
    -tclargs "$variant" "$out_root/$variant" \
    >"$out_root/$variant/vivado.log" 2>&1 &
  pids+=("$!")
done

rc=0
for pid in "${pids[@]}"; do
  wait "$pid" || rc=1
done

for variant in baseline replicated; do
  echo "===== $variant ====="
  cat "$out_root/$variant/result.tsv" 2>/dev/null || tail -n 40 "$out_root/$variant/vivado.log"
done

if (( rc != 0 )); then
  echo "ERROR: one or more Vivado variants failed" >&2
  exit 1
fi
echo "WEIGHT_CACHE_TIMING_AB_DONE=$out_root"
