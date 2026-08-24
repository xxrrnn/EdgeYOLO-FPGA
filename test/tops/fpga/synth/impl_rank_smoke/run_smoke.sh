#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
cd "$repo_root"

vivado_bin="${VIVADO:-vivado}"
tag="${SMOKE_TAG:-impl_rank_smoke_$(date +%y%m%d_%H%M%S)}"
top_n="${SMOKE_TOP_N:-2}"
route_variants="${SMOKE_ROUTE_VARIANTS:-4}"
impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"

echo "[rank-smoke] tag=$tag top_n=$top_n route_variants=$route_variants"
"$vivado_bin" -mode batch -nolog -nojournal \
  -source "$repo_root/test/tops/fpga/synth/impl_rank_smoke/make_post_opt.tcl" \
  -tclargs "$tag"

BUILD_TAG="$tag" SOURCE_DCP="$impl_dir/post_opt.dcp" \
PLACE_THREADS="${PLACE_THREADS:-4}" ROUTE_THREADS="${ROUTE_THREADS:-4}" \
VIVADO_THREADS="${VIVADO_THREADS:-4}" \
IMPL_PLACE_TOP_N="$top_n" IMPL_ROUTE_VARIANTS="$route_variants" IMPL_ROUTE_TOP_K=0 \
RACE_MIN_WNS_NS="${RACE_MIN_WNS_NS:-0.0}" \
RACE_MIN_WHS_NS="${RACE_MIN_WHS_NS:-0.0}" \
VIVADO="$vivado_bin" bash "$repo_root/scripts/chip-lite/impl_two_stage.sh"

winner_file="$impl_dir/two_stage_winner.txt"
[[ -f "$winner_file" ]] || { echo "ERROR: missing $winner_file" >&2; exit 10; }
race_root="$(awk -F '\t' '$1 == "RACE_ROOT" {print $2}' "$winner_file")"
place_ranking="$race_root/summary/place_ranking.tsv"
route_ranking="$race_root/summary/route_ranking.tsv"
markdown_summary="$repo_root/build/lite/$tag/summary/two_stage_impl_summary.md"

place_count="$(awk 'NR > 1 && NF {count++} END {print count+0}' "$place_ranking")"
route_count="$(awk 'NR > 1 && NF {count++} END {print count+0}' "$route_ranking")"
expected_routes=$(( top_n * route_variants ))
[[ "$place_count" -eq 4 ]] || { echo "ERROR: expected 4 ranked places, got $place_count" >&2; exit 11; }
[[ "$route_count" -eq "$expected_routes" ]] || { echo "ERROR: expected $expected_routes routed candidates, got $route_count" >&2; exit 12; }
[[ -f "$impl_dir/post_route.dcp" ]] || { echo "ERROR: winner post_route.dcp was not published" >&2; exit 13; }
[[ -f "$markdown_summary" ]] || { echo "ERROR: missing Markdown summary: $markdown_summary" >&2; exit 14; }
grep -q 'place3_SSI_SpreadLogicHigh.*SUCCESS' "$markdown_summary" || {
  echo "ERROR: SLR-aware placement is missing or failed in Markdown summary" >&2
  exit 15
}
grep -q '| BEST |' "$markdown_summary" || { echo "ERROR: Markdown summary does not mark a BEST route" >&2; exit 16; }

echo "[rank-smoke] place ranking"
cat "$place_ranking"
echo "[rank-smoke] route ranking"
cat "$route_ranking"
echo "[rank-smoke] Markdown summary: $markdown_summary"
echo "RANK_SMOKE_PASS tag=$tag places=$place_count top_n=$top_n variants=$route_variants routed=$route_count"
