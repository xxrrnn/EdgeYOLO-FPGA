#!/usr/bin/env bash
set -Eeuo pipefail

# Two-stage implementation race:
#   1) run unique deterministic place directives in parallel;
#   2) rank post-place checkpoints and route only the most promising choices.

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tag="${BUILD_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)}"
vivado_bin="${VIVADO:-vivado}"
place_threads="${PLACE_THREADS:-32}"
route_threads="${ROUTE_THREADS:-32}"
vivado_threads="${VIVADO_THREADS:-32}"
route_top_k="${IMPL_ROUTE_TOP_K:-3}"
min_wns="${RACE_MIN_WNS_NS:-0.05}"
min_whs="${RACE_MIN_WHS_NS:-0.02}"
race_id="${RACE_ID:-$(date +%y%m%d_%H%M%S)}"

impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"
source_dcp="${SOURCE_DCP:-$impl_dir/post_opt.dcp}"
race_root="$impl_dir/two_stage_race/$race_id"
place_root="$race_root/place"
route_root="$race_root/route"
log_root="$race_root/logs"
summary_root="$race_root/summary"

place_directives=(ExtraTimingOpt Explore Default)
route_variants=(
  "AggressiveExplore|NoTimingRelaxation"
  "AggressiveExplore|AggressiveExplore"
  "ExploreWithHoldFix|NoTimingRelaxation"
  "ExploreWithHoldFix|Explore"
)

if [[ ! -f "$source_dcp" ]]; then
  echo "ERROR: missing shared post_opt checkpoint: $source_dcp" >&2
  exit 1
fi
if [[ ! "$route_top_k" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: IMPL_ROUTE_TOP_K must be a positive integer" >&2
  exit 1
fi
if (( route_top_k > 8 )); then
  echo "WARNING: limiting IMPL_ROUTE_TOP_K=$route_top_k to 8"
  route_top_k=8
fi

mkdir -p "$place_root" "$route_root" "$log_root" "$summary_root"

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
      for (i = 1; i <= NF; i++) if (is_number($i)) values[++n] = $i
      if (n >= col) { print values[col]; exit }
    }
    mode == "setup" && /WNS\(ns\)/ && /TNS\(ns\)/ { want = 1; next }
    mode == "hold"  && /WHS\(ns\)/ && /THS\(ns\)/ { want = 1; next }
    want { emit_fields() }
  ' "$report" 2>/dev/null || true
}

echo "[two-stage] tag=$tag race_id=$race_id"
echo "[two-stage] source=$source_dcp"
echo "[two-stage] place=${#place_directives[@]}x${place_threads} threads; route_top_k=${route_top_k}x${route_threads} threads"

# -----------------------------------------------------------------------------
# Stage 1: unique place directives. Repeating the same directive from the same
# checkpoint is deterministic and provides no useful diversity.
# -----------------------------------------------------------------------------
place_pids=()
place_names=()
for idx in "${!place_directives[@]}"; do
  directive="${place_directives[$idx]}"
  candidate="place${idx}_${directive}"
  candidate_dir="$place_root/$candidate"
  mkdir -p "$candidate_dir"
  echo "[two-stage] launch place candidate $candidate"
  setsid env \
    BUILD_TAG="$tag" SOURCE_DCP="$source_dcp" RACE_ROOT="$race_root" \
    IMPL_CANDIDATE="$candidate" PLACE_DIRECTIVE="$directive" \
    PLACE_THREADS="$place_threads" ROUTE_THREADS="$route_threads" \
    VIVADO_THREADS="$vivado_threads" \
    "$vivado_bin" -mode batch \
      -source "$repo_root/scripts/chip-lite/impl_place_worker.tcl" \
      -journal "$log_root/${candidate}.jou" \
      -log "$log_root/${candidate}.vivado.log" \
      >"$log_root/${candidate}.stdout.log" 2>&1 &
  place_pids+=("$!")
  place_names+=("$candidate")
done

for pid in "${place_pids[@]}"; do
  if ! wait "$pid"; then
    echo "WARNING: a place worker exited non-zero; status files will decide eligibility"
  fi
done

ranking="$summary_root/place_ranking.tsv"
printf "candidate\twns\ttns\tfailing_endpoints\tdirective\tdcp\n" >"$ranking"
sortable="$summary_root/place_sortable.tsv"
: >"$sortable"

for candidate in "${place_names[@]}"; do
  candidate_dir="$place_root/$candidate"
  status_file="$candidate_dir/status.txt"
  report="$candidate_dir/post_place_timing_summary.rpt"
  dcp="$candidate_dir/post_place.dcp"
  [[ -f "$status_file" && -f "$dcp" ]] || continue
  [[ "$(status_value "$status_file" STATUS)" == "SUCCESS" ]] || continue
  directive="$(status_value "$status_file" PLACE)"
  wns="$(status_value "$status_file" POST_PLACE_WNS)"
  tns="$(timing_summary_value "$report" setup 2)"
  failing="$(timing_summary_value "$report" setup 3)"
  tns="${tns:-0}"
  failing="${failing:-0}"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$candidate" "$wns" "$tns" "$failing" "$directive" "$dcp" >>"$sortable"
done

if [[ ! -s "$sortable" ]]; then
  echo "ERROR: no place candidate passed the post-place gate" >&2
  exit 2
fi

# Higher WNS/TNS and fewer failing endpoints rank first. WNS is intentionally
# primary because it is the strongest inexpensive predictor available here.
sort -t $'\t' -k2,2gr -k3,3gr -k4,4n "$sortable" >>"$ranking"
mapfile -t ranked_lines < <(tail -n +2 "$ranking")

echo "[two-stage] post-place ranking:"
column -t -s $'\t' "$ranking" 2>/dev/null || cat "$ranking"

# -----------------------------------------------------------------------------
# Stage 2: construct a compact route portfolio.
# Default order is best-place/base-route, second-place/base-route, then
# best-place/alternate-route. This avoids routing all eight legacy combinations.
# -----------------------------------------------------------------------------
declare -a route_specs=()
add_route_spec() {
  local rank="$1" variant="$2"
  (( rank < ${#ranked_lines[@]} )) || return 0
  (( variant < ${#route_variants[@]} )) || return 0
  local key="${rank}|${variant}"
  local existing
  for existing in "${route_specs[@]}"; do
    [[ "$existing" == "$key" ]] && return 0
  done
  route_specs+=("$rank|$variant")
}

add_route_spec 0 0
add_route_spec 1 0
add_route_spec 0 1
add_route_spec 2 0
add_route_spec 0 2
add_route_spec 1 1
add_route_spec 0 3
add_route_spec 2 1
if (( ${#route_specs[@]} > route_top_k )); then
  route_specs=("${route_specs[@]:0:route_top_k}")
fi

route_pids=()
route_names=()
for task_idx in "${!route_specs[@]}"; do
  spec="${route_specs[$task_idx]}"
  rank="${spec%%|*}"
  variant="${spec##*|}"
  line="${ranked_lines[$rank]}"
  IFS=$'\t' read -r candidate _wns _tns _failing place_dir place_dcp <<<"$line"
  route_variant="${route_variants[$variant]}"
  phys_dir="${route_variant%%|*}"
  route_dir="${route_variant##*|}"
  task="route${task_idx}_${candidate}_${phys_dir}_${route_dir}"
  mkdir -p "$route_root/$task"
  echo "[two-stage] launch $task"
  setsid env \
    BUILD_TAG="$tag" SOURCE_DCP="$place_dcp" RACE_ROOT="$race_root" \
    IMPL_TASK="$task" SOURCE_CANDIDATE="$candidate" \
    PHYS_OPT_DIRECTIVE="$phys_dir" ROUTE_DIRECTIVE="$route_dir" \
    RACE_MIN_WNS_NS="$min_wns" RACE_MIN_WHS_NS="$min_whs" \
    PLACE_THREADS="$place_threads" ROUTE_THREADS="$route_threads" \
    VIVADO_THREADS="$vivado_threads" \
    "$vivado_bin" -mode batch \
      -source "$repo_root/scripts/chip-lite/impl_route_worker.tcl" \
      -journal "$log_root/${task}.jou" \
      -log "$log_root/${task}.vivado.log" \
      >"$log_root/${task}.stdout.log" 2>&1 &
  route_pids+=("$!")
  route_names+=("$task")
done

for pid in "${route_pids[@]}"; do
  if ! wait "$pid"; then
    echo "WARNING: a route worker exited non-zero; remaining candidates are preserved"
  fi
done

route_summary="$summary_root/route_ranking.tsv"
printf "task\tstatus\twns\twhs\tsource_candidate\tphys_opt\troute\tdcp\n" >"$route_summary"
route_sortable="$summary_root/route_sortable.tsv"
: >"$route_sortable"

for task in "${route_names[@]}"; do
  task_dir="$route_root/$task"
  status_file="$task_dir/status.txt"
  dcp="$task_dir/post_route.dcp"
  [[ -f "$status_file" && -f "$dcp" ]] || continue
  status="$(status_value "$status_file" STATUS)"
  case "$status" in
    SUCCESS) timing_rank=3 ;;
    LOW_MARGIN) timing_rank=2 ;;
    TIMING_FAIL) timing_rank=1 ;;
    *) continue ;;
  esac
  wns="$(status_value "$status_file" POST_ROUTE_WNS)"
  whs="$(status_value "$status_file" POST_ROUTE_WHS)"
  candidate="$(status_value "$status_file" SOURCE_CANDIDATE)"
  phys="$(status_value "$status_file" PHYS_OPT)"
  route="$(status_value "$status_file" ROUTE)"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$timing_rank" "$task" "$status" "$wns" "$whs" "$candidate" "$phys" "$route" "$dcp" >>"$route_sortable"
done

if [[ ! -s "$route_sortable" ]]; then
  echo "ERROR: no routing task produced a checkpoint" >&2
  exit 3
fi

# Always prefer a timing-met checkpoint over a setup-only improvement. Within
# the same status class, rank by setup margin and then hold margin.
sort -t $'\t' -k1,1gr -k4,4gr -k5,5gr "$route_sortable" | cut -f2- >>"$route_summary"
winner_line="$(sed -n '2p' "$route_summary")"
IFS=$'\t' read -r winner_task winner_status winner_wns winner_whs winner_candidate winner_phys winner_route winner_dcp <<<"$winner_line"
winner_dir="$route_root/$winner_task"

cp -f "$winner_dcp" "$impl_dir/post_route.dcp"
cp -f "$winner_dir/post_route_timing_summary.rpt" "$impl_dir/post_route_timing_summary.rpt"
cp -f "$winner_dir/post_route_util.rpt" "$impl_dir/post_route_util.rpt"

{
  printf "RACE_ROOT\t%s\n" "$race_root"
  printf "WINNER_TASK\t%s\n" "$winner_task"
  printf "WINNER_STATUS\t%s\n" "$winner_status"
  printf "WINNER_WNS\t%s\n" "$winner_wns"
  printf "WINNER_WHS\t%s\n" "$winner_whs"
  printf "WINNER_DCP\t%s\n" "$winner_dcp"
} >"$impl_dir/two_stage_winner.txt"

echo "[two-stage] route ranking:"
column -t -s $'\t' "$route_summary" 2>/dev/null || cat "$route_summary"
echo "[two-stage] winner=$winner_task status=$winner_status WNS=${winner_wns}ns WHS=${winner_whs}ns"
echo "[two-stage] canonical checkpoint=$impl_dir/post_route.dcp"
