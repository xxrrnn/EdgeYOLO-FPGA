#!/usr/bin/env bash
set -Eeuo pipefail

# Build a human-readable timing report for a completed (or partially completed)
# two-stage implementation race.  The report is refreshed once after routing and
# again after the canonical .bit/.ltx files have been written.

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tag="${BUILD_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)}"
impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"
winner_file="$impl_dir/two_stage_winner.txt"
race_root="${RACE_ROOT:-}"
min_wns="${RACE_MIN_WNS_NS:-0.05}"
min_whs="${RACE_MIN_WHS_NS:-0.02}"
vivado_bin="${VIVADO:-vivado}"

status_value() {
  local file="$1" key="$2"
  awk -F '\t' -v k="$key" '$1 == k {print $2; exit}' "$file" 2>/dev/null || true
}

timing_summary_value() {
  local report="$1" mode="$2" column="$3"
  [[ -f "$report" ]] || return 0
  awk -v mode="$mode" -v col="$column" '
    function is_number(x) { return x ~ /^[-+]?[0-9]+([.][0-9]+)?$/ }
    function emit_fields() {
      n = 0
      delete values
      for (i = 1; i <= NF; i++) if (is_number($i)) values[++n] = $i
      if (n >= col) { print values[col]; exit }
    }
    mode == "setup" && /WNS\(ns\)/ && /TNS\(ns\)/ { want = 1; next }
    mode == "hold"  && /WHS\(ns\)/ && /THS\(ns\)/ { want = 1; next }
    want { emit_fields() }
  ' "$report" 2>/dev/null || true
}

md_cell() {
  local value="${1:-}"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  value="${value//|/\\|}"
  printf '%s' "${value:-NA}"
}

if [[ -z "$race_root" && -f "$winner_file" ]]; then
  race_root="$(status_value "$winner_file" RACE_ROOT)"
fi
if [[ -z "$race_root" || ! -d "$race_root" ]]; then
  echo "ERROR: RACE_ROOT is missing or not a directory: ${race_root:-unset}" >&2
  exit 1
fi

place_root="$race_root/place"
route_root="$race_root/route"
race_summary="$race_root/summary"
place_ranking="$race_summary/place_ranking.tsv"
route_ranking="$race_summary/route_ranking.tsv"
summary_dir="$repo_root/build/lite/$tag/summary"
md="$summary_dir/two_stage_impl_summary.md"
place_tsv="$summary_dir/two_stage_place_results.tsv"
route_tsv="$summary_dir/two_stage_route_results.tsv"
mkdir -p "$summary_dir"

winner_task="$(status_value "$winner_file" WINNER_TASK)"
winner_status="$(status_value "$winner_file" WINNER_STATUS)"
winner_wns="$(status_value "$winner_file" WINNER_WNS)"
winner_whs="$(status_value "$winner_file" WINNER_WHS)"
winner_dcp="$(status_value "$winner_file" WINNER_DCP)"

declare -A place_rank=()
declare -A selected_place=()
declare -A route_rank=()
if [[ -f "$place_ranking" ]]; then
  rank=0
  while IFS=$'\t' read -r candidate _rest; do
    [[ "$candidate" == "candidate" || -z "$candidate" ]] && continue
    rank=$((rank + 1))
    place_rank["$candidate"]="$rank"
  done <"$place_ranking"
fi
if [[ -f "$route_ranking" ]]; then
  rank=0
  while IFS=$'\t' read -r task _status _wns _whs source_candidate _rest; do
    [[ "$task" == "task" || -z "$task" ]] && continue
    rank=$((rank + 1))
    route_rank["$task"]="$rank"
    selected_place["$source_candidate"]=1
  done <"$route_ranking"
fi

printf 'rank\tselected\tcandidate\tstatus\tdirective\tsubdirective\twns\ttns\tfailing_endpoints\tdcp\tdetail\n' >"$place_tsv"
if [[ -d "$place_root" ]]; then
  while IFS= read -r dir; do
    candidate="$(basename "$dir")"
    status_file="$dir/status.txt"
    report="$dir/post_place_timing_summary.rpt"
    status="$(status_value "$status_file" STATUS)"
    directive="$(status_value "$status_file" PLACE)"
    subdirective="$(status_value "$status_file" PLACE_SUBDIRECTIVE)"
    wns="$(status_value "$status_file" POST_PLACE_WNS)"
    tns="$(timing_summary_value "$report" setup 2)"
    failing="$(timing_summary_value "$report" setup 3)"
    detail="$(status_value "$status_file" DETAIL)"
    dcp=""
    [[ -f "$dir/post_place.dcp" ]] && dcp="$dir/post_place.dcp"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${place_rank[$candidate]:-}" "${selected_place[$candidate]:-0}" "$candidate" \
      "${status:-NO_STATUS}" "$directive" "$subdirective" "$wns" "$tns" "$failing" "$dcp" "$detail" >>"$place_tsv"
  done < <(find "$place_root" -mindepth 1 -maxdepth 1 -type d | sort)
fi

printf 'rank\trecommended\ttask\tstatus\tsource_candidate\tphys_opt\troute\twns\ttns\tsetup_fail_endpoints\twhs\tths\thold_fail_endpoints\tdcp\tbitstream\tdetail\n' >"$route_tsv"
if [[ -d "$route_root" ]]; then
  while IFS= read -r dir; do
    task="$(basename "$dir")"
    status_file="$dir/status.txt"
    report="$dir/post_route_timing_summary.rpt"
    status="$(status_value "$status_file" STATUS)"
    source_candidate="$(status_value "$status_file" SOURCE_CANDIDATE)"
    phys="$(status_value "$status_file" PHYS_OPT)"
    route="$(status_value "$status_file" ROUTE)"
    wns="$(status_value "$status_file" POST_ROUTE_WNS)"
    whs="$(status_value "$status_file" POST_ROUTE_WHS)"
    tns="$(timing_summary_value "$report" setup 2)"
    setup_fail="$(timing_summary_value "$report" setup 3)"
    ths="$(timing_summary_value "$report" hold 2)"
    hold_fail="$(timing_summary_value "$report" hold 3)"
    detail="$(status_value "$status_file" DETAIL)"
    dcp=""
    bitstream=""
    recommended=0
    [[ -f "$dir/post_route.dcp" ]] && dcp="$dir/post_route.dcp"
    if [[ "$task" == "$winner_task" ]]; then
      recommended=1
      [[ -f "$impl_dir/top.bit" ]] && bitstream="$impl_dir/top.bit"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${route_rank[$task]:-}" "$recommended" "$task" "${status:-NO_STATUS}" "$source_candidate" \
      "$phys" "$route" "$wns" "$tns" "$setup_fail" "$whs" "$ths" "$hold_fail" \
      "$dcp" "$bitstream" "$detail" >>"$route_tsv"
  done < <(find "$route_root" -mindepth 1 -maxdepth 1 -type d | sort)
fi

bit_state="not generated"
ltx_state="not generated"
[[ -f "$impl_dir/top.bit" ]] && bit_state="[top.bit](../ImplOutputDir/top.bit)"
[[ -f "$impl_dir/top.ltx" ]] && ltx_state="[top.ltx](../ImplOutputDir/top.ltx)"
dcp_state="not generated"
[[ -f "$impl_dir/post_route.dcp" ]] && dcp_state="[post_route.dcp](../ImplOutputDir/post_route.dcp)"

if [[ "$winner_status" == "SUCCESS" ]]; then
  recommendation="Recommended. Setup and hold timing meet the requested guard bands."
elif [[ "$winner_status" == "LOW_MARGIN" ]]; then
  recommendation="Conditionally usable. Timing is legal, but one or both requested guard bands are not met."
elif [[ "$winner_status" == "TIMING_FAIL" ]]; then
  recommendation="Do not deploy. The best routed checkpoint still violates setup or hold timing."
else
  recommendation="No deployable winner is available. Inspect failed workers below."
fi

{
  echo "# Two-stage Implementation Timing Summary"
  echo
  echo "## Recommendation"
  echo
  echo "- decision: **$(md_cell "$recommendation")**"
  echo "- winner: \`$(md_cell "$winner_task")\`"
  echo "- status: \`$(md_cell "$winner_status")\`"
  echo "- post-route WNS/WHS: **$(md_cell "$winner_wns") ns / $(md_cell "$winner_whs") ns**"
  echo "- required guard bands: WNS >= ${min_wns} ns, WHS >= ${min_whs} ns"
  echo "- canonical artifacts: bitstream $bit_state; probes $ltx_state; checkpoint $dcp_state"
  echo
  echo "Selection order is timing class (SUCCESS > LOW_MARGIN > TIMING_FAIL), then WNS, then WHS. A negative WNS or WHS is never recommended as a deployable bitstream."
  echo
  echo "## Build"
  echo
  echo "- tag: \`$tag\`"
  echo "- source commit: \`$(git rev-parse HEAD 2>/dev/null || echo unknown)\`"
  echo "- Vivado: \`$($vivado_bin -version 2>/dev/null | head -1 || echo unknown)\`"
  echo "- race root: \`$race_root\`"
  echo
  echo "## Placement results"
  echo
  echo "| Rank | Selected | Candidate | Status | Directive | Subdirective | WNS (ns) | TNS (ns) | Failing endpoints | Detail |"
  echo "| ---: | :---: | --- | --- | --- | --- | ---: | ---: | ---: | --- |"
  tail -n +2 "$place_tsv" | \
    awk -F '\t' '{ key = ($1 == "" ? 999999 : $1); print key "\t" $0 }' | \
    sort -t $'\t' -k1,1n -k4,4 | cut -f2- | \
    awk -F '\t' '
      function cell(x) { gsub(/\|/, "\\|", x); return x == "" ? "NA" : x }
      {
        selected = ($2 == "1" ? "yes" : "no")
        printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", \
          cell($1), selected, cell($3), cell($4), cell($5), cell($6), \
          cell($7), cell($8), cell($9), cell($11)
      }
    '
  echo
  echo "## Routing results"
  echo
  echo "| Rank | Pick | Task | Status | Placement | Phys Opt | Route | WNS | TNS | Setup Fail | WHS | THS | Hold Fail | Artifact | Detail |"
  echo "| ---: | :---: | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |"
  tail -n +2 "$route_tsv" | \
    awk -F '\t' '{ key = ($1 == "" ? 999999 : $1); print key "\t" $0 }' | \
    sort -t $'\t' -k1,1n -k4,4 | cut -f2- | \
    awk -F '\t' '
      function cell(x) { gsub(/\|/, "\\|", x); return x == "" ? "NA" : x }
      {
        pick = ($2 == "1" ? "BEST" : "")
        artifact = ($14 == "" ? "none" : "DCP only")
        if ($15 != "") artifact = "[top.bit](../ImplOutputDir/top.bit)"
        printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", \
          cell($1), cell(pick), cell($3), cell($4), cell($5), cell($6), \
          cell($7), cell($8), cell($9), cell($10), cell($11), cell($12), \
          cell($13), artifact, cell($16)
      }
    '
  echo
  echo "Machine-readable tables: [place TSV](two_stage_place_results.tsv) and [route TSV](two_stage_route_results.tsv)."
} >"$md"

echo "[two-stage-summary] Markdown: $md"
echo "[two-stage-summary] place TSV: $place_tsv"
echo "[two-stage-summary] route TSV: $route_tsv"
