#!/usr/bin/env bash
set -Eeuo pipefail

# Two-stage implementation race:
#   1) run unique deterministic place directives in parallel;
#   2) rank post-place checkpoints and route only the most promising choices.

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tag="${BUILD_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)}"
vivado_bin="${VIVADO:-vivado}"
place_threads="${PLACE_THREADS:-24}"
route_threads="${ROUTE_THREADS:-16}"
vivado_threads="${VIVADO_THREADS:-32}"
place_top_n="${IMPL_PLACE_TOP_N:-0}"
route_variant_count="${IMPL_ROUTE_VARIANTS:-4}"
route_task_limit="${IMPL_ROUTE_TOP_K:-0}"
min_wns="${RACE_MIN_WNS_NS:-0.05}"
min_whs="${RACE_MIN_WHS_NS:-0.02}"
race_id="${RACE_ID:-$(date +%y%m%d_%H%M%S)}"
resume_after_place="${RACE_RESUME_AFTER_PLACE:-0}"

impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"
source_dcp="${SOURCE_DCP:-$impl_dir/post_opt.dcp}"
race_root="$impl_dir/two_stage_race/$race_id"
place_root="$race_root/place"
route_root="$race_root/route"
log_root="$race_root/logs"
summary_root="$race_root/summary"

# Format: candidate key | top-level directive | optional subdirective list.
place_strategies=(
  "ExtraTimingOpt|ExtraTimingOpt|"
  "Explore|Explore|"
  "Default|Default|"
  "SSI_SpreadLogicHigh|SSI_SpreadLogic_high|"
)
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
if [[ ! "$place_top_n" =~ ^[0-9]+$ ]]; then
  echo "ERROR: IMPL_PLACE_TOP_N must be a non-negative integer (0 means ceil(place_count/2))" >&2
  exit 1
fi
if [[ ! "$route_variant_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: IMPL_ROUTE_VARIANTS must be a positive integer" >&2
  exit 1
fi
if (( route_variant_count > ${#route_variants[@]} )); then
  echo "WARNING: limiting IMPL_ROUTE_VARIANTS=$route_variant_count to ${#route_variants[@]}"
  route_variant_count="${#route_variants[@]}"
fi
if [[ ! "$route_task_limit" =~ ^[0-9]+$ ]]; then
  echo "ERROR: IMPL_ROUTE_TOP_K must be a non-negative integer (0 means unlimited)" >&2
  exit 1
fi
if [[ "$resume_after_place" != "0" && "$resume_after_place" != "1" ]]; then
  echo "ERROR: RACE_RESUME_AFTER_PLACE must be 0 or 1" >&2
  exit 1
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
echo "[two-stage] place=${#place_strategies[@]}x${place_threads} threads; place_top_n=${place_top_n}; route_variants=${route_variant_count}; route_threads=${route_threads}"
echo "[two-stage] resume_after_place=$resume_after_place"

# -----------------------------------------------------------------------------
# Stage 1: unique place directives. Repeating the same directive from the same
# checkpoint is deterministic and provides no useful diversity.
# -----------------------------------------------------------------------------
place_pids=()
place_names=()
for idx in "${!place_strategies[@]}"; do
  strategy="${place_strategies[$idx]}"
  IFS='|' read -r strategy_key directive subdirective <<<"$strategy"
  candidate="place${idx}_${strategy_key}"
  candidate_dir="$place_root/$candidate"
  place_names+=("$candidate")
  if [[ "$resume_after_place" == "1" ]]; then
    continue
  fi
  mkdir -p "$candidate_dir"
  echo "[two-stage] launch place candidate $candidate"
  setsid env \
    BUILD_TAG="$tag" SOURCE_DCP="$source_dcp" RACE_ROOT="$race_root" \
    IMPL_CANDIDATE="$candidate" PLACE_DIRECTIVE="$directive" \
    PLACE_SUBDIRECTIVE="$subdirective" \
    PLACE_THREADS="$place_threads" ROUTE_THREADS="$route_threads" \
    VIVADO_THREADS="$vivado_threads" \
    "$vivado_bin" -mode batch \
      -source "$repo_root/scripts/chip-lite/impl_place_worker.tcl" \
      -journal "$log_root/${candidate}.jou" \
      -log "$log_root/${candidate}.vivado.log" \
      >"$log_root/${candidate}.stdout.log" 2>&1 &
  place_pids+=("$!")
done

if [[ "$resume_after_place" == "1" ]]; then
  echo "[two-stage] reusing completed post-place checkpoints from $place_root"
else
  for pid in "${place_pids[@]}"; do
    if ! wait "$pid"; then
      echo "WARNING: a place worker exited non-zero; status files will decide eligibility"
    fi
  done
fi

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

available_places="${#ranked_lines[@]}"
if (( place_top_n == 0 )); then
  place_top_n=$(( (available_places + 1) / 2 ))
fi
if (( place_top_n > available_places )); then
  echo "WARNING: limiting IMPL_PLACE_TOP_N=$place_top_n to available places=$available_places"
  place_top_n="$available_places"
fi

echo "[two-stage] post-place ranking:"
column -t -s $'\t' "$ranking" 2>/dev/null || cat "$ranking"

# -----------------------------------------------------------------------------
# Stage 2: Cartesian expansion of the top half of ranked placements and all
# requested routing variants. Four places -> top two -> 2 x 4 = 8 route workers.
# -----------------------------------------------------------------------------
declare -a route_specs=()
for ((rank = 0; rank < place_top_n; rank++)); do
  for ((variant = 0; variant < route_variant_count; variant++)); do
    route_specs+=("$rank|$variant")
  done
done
if (( route_task_limit > 0 && ${#route_specs[@]} > route_task_limit )); then
  route_specs=("${route_specs[@]:0:route_task_limit}")
fi
echo "[two-stage] selected_places=$place_top_n route_tasks=${#route_specs[@]}"

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

BUILD_TAG="$tag" RACE_ROOT="$race_root" VIVADO="$vivado_bin" \
  RACE_MIN_WNS_NS="$min_wns" RACE_MIN_WHS_NS="$min_whs" \
  bash "$repo_root/scripts/chip-lite/impl_two_stage_summary.sh"

echo "[two-stage] route ranking:"
column -t -s $'\t' "$route_summary" 2>/dev/null || cat "$route_summary"
echo "[two-stage] winner=$winner_task status=$winner_status WNS=${winner_wns}ns WHS=${winner_whs}ns"
echo "[two-stage] canonical checkpoint=$impl_dir/post_route.dcp"
