#!/usr/bin/env bash
set -Eeo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tag="${TAG:-${BUILD_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)}}"
vivado_bin="${VIVADO:-vivado}"
impl_jobs="${IMPL_JOBS:-8}"
min_wns="${RACE_MIN_WNS_NS:-0.05}"
min_whs="${RACE_MIN_WHS_NS:-0.02}"
incremental_dcp="${RACE_INCREMENTAL_DCP:-}"
incremental_attempts="${RACE_INCREMENTAL_ATTEMPTS:-4}"
race_id="${RACE_ID:-$(date +%y%m%d_%H%M%S)}"

place_threads="${PLACE_THREADS:-16}"
route_threads="${ROUTE_THREADS:-16}"
vivado_threads="${VIVADO_THREADS:-32}"
synth_jobs="${SYNTH_JOBS:-128}"

impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"
build_dir="$repo_root/build/lite/$tag"
source_dcp="$impl_dir/post_opt.dcp"
race_root="$impl_dir/full_race/$race_id"
log_dir="$build_dir/logs"
bitstream_dir="$build_dir/bitstreams"
summary_dir="$build_dir/summary"

if [[ ! -f "$source_dcp" ]]; then
  echo "ERROR: missing post_opt checkpoint: $source_dcp" >&2
  echo "Run first: make synth-to-opt TAG=$tag" >&2
  exit 1
fi

mkdir -p "$race_root" "$log_dir" "$bitstream_dir" "$summary_dir"

strategies=(
  "ExtraTimingOpt|AggressiveExplore|AggressiveExplore"
  "ExtraTimingOpt|AggressiveExplore|NoTimingRelaxation"
  "Explore|AggressiveExplore|NoTimingRelaxation"
  "Explore|AggressiveExplore|AggressiveExplore"
  "ExtraTimingOpt|ExploreWithHoldFix|NoTimingRelaxation"
  "Explore|ExploreWithHoldFix|Explore"
  "Default|AggressiveExplore|AggressiveExplore"
  "Default|ExploreWithHoldFix|Explore"
)

if (( impl_jobs < 1 )); then
  echo "ERROR: IMPL_JOBS must be >= 1" >&2
  exit 1
fi
if (( impl_jobs > 8 )); then
  echo "WARNING: IMPL_JOBS=$impl_jobs exceeds the aggressive parallel cap; using 8." >&2
  impl_jobs=8
fi
if (( impl_jobs > ${#strategies[@]} )); then
  impl_jobs="${#strategies[@]}"
fi

if [[ ! "$incremental_attempts" =~ ^[0-9]+$ ]]; then
  echo "ERROR: RACE_INCREMENTAL_ATTEMPTS must be a non-negative integer" >&2
  exit 1
fi
if [[ -n "$incremental_dcp" ]]; then
  if [[ "$incremental_dcp" != /* ]]; then
    incremental_dcp="$repo_root/$incremental_dcp"
  fi
  if [[ ! -f "$incremental_dcp" ]]; then
    echo "ERROR: stable incremental checkpoint not found: $incremental_dcp" >&2
    exit 1
  fi
  if (( incremental_attempts > impl_jobs )); then
    incremental_attempts="$impl_jobs"
  fi
else
  incremental_attempts=0
fi

echo "[impl-race] tag=$tag race_id=$race_id attempts=$impl_jobs place_threads=$place_threads route_threads=$route_threads"
echo "[impl-race] source=$source_dcp"
echo "[impl-race] acceptance WNS>=${min_wns}ns WHS>=${min_whs}ns"
echo "[impl-race] incremental_attempts=$incremental_attempts reference=${incremental_dcp:-none}"

pids=()
attempt_dirs=()

terminate_workers() {
  local pid
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
  done
}
trap terminate_workers EXIT
trap 'terminate_workers; exit 130' INT TERM

launch_attempt() {
  local idx="$1"
  local strategy="${strategies[$idx]}"
  local place="${strategy%%|*}"
  local rest="${strategy#*|}"
  local phys="${rest%%|*}"
  local route="${rest#*|}"
  local mode="clean"
  local reference=""
  if (( idx < incremental_attempts )); then
    mode="incremental"
    reference="$incremental_dcp"
  fi
  local attempt="attempt${idx}_${mode}_${place}_${phys}_${route}"
  local attempt_dir="$race_root/$attempt"
  local stdout_log="$log_dir/${tag}_race_${idx}.stdout.log"
  local vivado_log="$log_dir/${tag}_race_${idx}.vivado.log"
  local journal="$log_dir/${tag}_race_${idx}.jou"
  local env_cmd=(
    env
    "BUILD_TAG=$tag"
    "SOURCE_DCP=$source_dcp"
    "RACE_ROOT=$race_root"
    "IMPL_ATTEMPT=$attempt"
    "PLACE_DIRECTIVE=$place"
    "PHYS_OPT_DIRECTIVE=$phys"
    "ROUTE_DIRECTIVE=$route"
    "IMPL_MODE=$mode"
    "INCREMENTAL_DCP=$reference"
    "RACE_MIN_WNS_NS=$min_wns"
    "RACE_MIN_WHS_NS=$min_whs"
    "VIVADO_THREADS=$vivado_threads"
    "PLACE_THREADS=$place_threads"
    "ROUTE_THREADS=$route_threads"
    "SYNTH_JOBS=$synth_jobs"
    "$vivado_bin"
    -mode batch
    -source "$repo_root/scripts/chip-lite/impl_race_worker.tcl"
    -journal "$journal"
    -log "$vivado_log"
  )

  mkdir -p "$attempt_dir"
  echo "[impl-race] launch $attempt"
  setsid "${env_cmd[@]}" >"$stdout_log" 2>&1 &

  pids+=("$!")
  attempt_dirs+=("$attempt_dir")
}

status_value() {
  local file="$1"
  local key="$2"
  awk -F '\t' -v k="$key" '$1 == k {print $2; exit}' "$file" 2>/dev/null || true
}

find_winner() {
  local dir status_file status status_rank wns whs
  local sortable="$race_root/winner_sortable.tsv"
  : >"$sortable"
  for dir in "${attempt_dirs[@]}"; do
    status_file="$dir/status.txt"
    [[ -f "$status_file" ]] || continue
    status="$(status_value "$status_file" STATUS)"
    case "$status" in
      SUCCESS) status_rank=2 ;;
      LOW_MARGIN) status_rank=1 ;;
      *) continue ;;
    esac
    wns="$(status_value "$status_file" POST_ROUTE_WNS)"
    whs="$(status_value "$status_file" POST_ROUTE_WHS)"
    printf "%s\t%s\t%s\t%s\n" "$status_rank" "$wns" "$whs" "$dir" >>"$sortable"
  done
  [[ -s "$sortable" ]] || return 1
  sort -t $'\t' -k1,1gr -k2,2gr -k3,3gr "$sortable" | sed -n '1s/^[^\t]*\t[^\t]*\t[^\t]*\t//p'
}

publish_winner() {
  local winner_dir="$1" status_file attempt status wns whs
  status_file="$winner_dir/status.txt"
  attempt="$(status_value "$status_file" ATTEMPT)"
  status="$(status_value "$status_file" STATUS)"
  wns="$(status_value "$status_file" POST_ROUTE_WNS)"
  whs="$(status_value "$status_file" POST_ROUTE_WHS)"

  cp -f "$winner_dir/post_route.dcp" "$impl_dir/post_route.dcp"
  cp -f "$winner_dir/post_route_timing_summary.rpt" "$impl_dir/post_route_timing_summary.rpt"
  cp -f "$winner_dir/post_route_util.rpt" "$impl_dir/post_route_util.rpt"
  cp -f "$winner_dir/top.bit" "$impl_dir/top.bit"
  [[ ! -f "$winner_dir/top.bin" ]] || cp -f "$winner_dir/top.bin" "$impl_dir/top.bin"
  cp -f "$winner_dir/top.ltx" "$impl_dir/top.ltx"
  {
    printf "RACE_ROOT\t%s\n" "$race_root"
    printf "WINNER_ATTEMPT\t%s\n" "$attempt"
    printf "WINNER_STATUS\t%s\n" "$status"
    printf "WINNER_WNS\t%s\n" "$wns"
    printf "WINNER_WHS\t%s\n" "$whs"
    printf "WINNER_DCP\t%s\n" "$winner_dir/post_route.dcp"
  } >"$impl_dir/full_race_winner.txt"
}

timing_summary_value() {
  local report="$1"
  local mode="$2"
  local column="$3"

  [[ -f "$report" ]] || return 0
  awk -v mode="$mode" -v col="$column" '
    function is_number(x) { return x ~ /^[-+]?[0-9]+([.][0-9]+)?$/ }
    function emit_fields() {
      n = 0
      for (i = 1; i <= NF; i++) {
        if (is_number($i)) {
          n++
          vals[n] = $i
        }
      }
      if (n >= col) {
        print vals[col]
        exit
      }
    }
    mode == "setup" && /WNS\(ns\)/ && /TNS\(ns\)/ { want = 1; next }
    mode == "hold" && /WHS\(ns\)/ && /THS\(ns\)/ { want = 1; next }
    want { emit_fields() }
  ' "$report" 2>/dev/null || true
}

copy_timing_met_bitstreams() {
  local dir status_file attempt bit bin ltx out_base
  for dir in "${attempt_dirs[@]}"; do
    status_file="$dir/status.txt"
    [[ -f "$status_file" ]] || continue
    case "$(status_value "$status_file" STATUS)" in
      SUCCESS|LOW_MARGIN) ;;
      *) continue ;;
    esac

    attempt="$(status_value "$status_file" ATTEMPT)"
    bit="$dir/top.bit"
    bin="$dir/top.bin"
    ltx="$dir/top.ltx"
    out_base="$bitstream_dir/${tag}_${attempt}"
    if [[ -f "$bit" ]]; then
      cp -f "$bit" "${out_base}.bit"
    fi
    if [[ -f "$bin" ]]; then
      cp -f "$bin" "${out_base}.bin"
    fi
    if [[ -f "$ltx" ]]; then
      cp -f "$ltx" "${out_base}.ltx"
    fi
  done
}

write_summary() {
  local tsv="$summary_dir/impl_race_summary.tsv"
  local md="$summary_dir/impl_race_summary.md"
  local dir status_file report attempt status detail place phys route mode
  local pp_wns wns tns setup_fail whs ths hold_fail bitstream rel_bitstream
  local success_count=0

  copy_timing_met_bitstreams

  printf "attempt\tstatus\tmode\tplace\tphys_opt\troute\tpost_place_wns\tpost_route_wns\tpost_route_tns\tsetup_fail_endpoints\tpost_route_whs\tpost_route_ths\thold_fail_endpoints\tbitstream\tdetail\n" >"$tsv"

  {
    echo "# Impl Race Summary"
    echo
    echo "- tag: $tag"
    echo "- source_commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "- vivado: $("$vivado_bin" -version 2>/dev/null | head -1)"
    echo "- build_dir: $build_dir"
    echo "- jobs: $impl_jobs"
    echo "- place_threads: $place_threads"
    echo "- route_threads: $route_threads"
    echo "- min_wns_ns: $min_wns"
    echo "- min_whs_ns: $min_whs"
    echo "- incremental_attempts: $incremental_attempts"
    echo "- incremental_reference: ${incremental_dcp:-none}"
    echo
    echo "| Attempt | Status | Mode | Place | Phys Opt | Route | WNS | TNS | Setup Fail | WHS | THS | Hold Fail | Bitstream | Detail |"
    echo "| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |"
  } >"$md"

  for dir in "${attempt_dirs[@]}"; do
    status_file="$dir/status.txt"
    report="$dir/post_route_timing_summary.rpt"

    if [[ -f "$status_file" ]]; then
      attempt="$(status_value "$status_file" ATTEMPT)"
      status="$(status_value "$status_file" STATUS)"
      detail="$(status_value "$status_file" DETAIL)"
      place="$(status_value "$status_file" PLACE)"
      phys="$(status_value "$status_file" PHYS_OPT)"
      route="$(status_value "$status_file" ROUTE)"
      mode="$(status_value "$status_file" MODE)"
      pp_wns="$(status_value "$status_file" POST_PLACE_WNS)"
      wns="$(status_value "$status_file" POST_ROUTE_WNS)"
      whs="$(status_value "$status_file" POST_ROUTE_WHS)"
    else
      attempt="$(basename "$dir")"
      status="NO_STATUS"
      detail="worker did not write status.txt"
      place=""
      phys=""
      route=""
      mode=""
      pp_wns=""
      wns=""
      whs=""
    fi

    tns="$(timing_summary_value "$report" setup 2)"
    setup_fail="$(timing_summary_value "$report" setup 3)"
    ths="$(timing_summary_value "$report" hold 2)"
    hold_fail="$(timing_summary_value "$report" hold 3)"

    bitstream=""
    rel_bitstream=""
    if [[ "$status" == "SUCCESS" || "$status" == "LOW_MARGIN" ]]; then
      rel_bitstream="bitstreams/${tag}_${attempt}.bit"
      if [[ -f "$build_dir/$rel_bitstream" ]]; then
        bitstream="$build_dir/$rel_bitstream"
      else
        rel_bitstream=""
      fi
      if [[ "$status" == "SUCCESS" ]]; then
        ((success_count += 1))
      fi
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$attempt" "$status" "$mode" "$place" "$phys" "$route" "$pp_wns" "$wns" "$tns" \
      "$setup_fail" "$whs" "$ths" "$hold_fail" "$bitstream" "$detail" >>"$tsv"

    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" \
      "$attempt" "$status" "$mode" "$place" "$phys" "$route" "${wns:-NA}" "${tns:-NA}" \
      "${setup_fail:-NA}" "${whs:-NA}" "${ths:-NA}" "${hold_fail:-NA}" \
      "${rel_bitstream:-}" "$detail" >>"$md"
  done

  echo "$success_count" >"$summary_dir/success_count.txt"
  echo "[impl-race] summary: $md"
  echo "[impl-race] summary TSV: $tsv"
  return 0
}

for ((i = 0; i < impl_jobs; i++)); do
  launch_attempt "$i"
done

for pid in "${pids[@]}"; do wait "$pid" || true; done

if winner_dir="$(find_winner)"; then
  write_summary
  publish_winner "$winner_dir"
  winner_status="$winner_dir/status.txt"
  winner_attempt="$(status_value "$winner_status" ATTEMPT)"
  winner_wns="$(status_value "$winner_status" POST_ROUTE_WNS)"
  winner_whs="$(status_value "$winner_status" POST_ROUTE_WHS)"
  echo "[impl-race] WINNER $winner_attempt WNS=$winner_wns WHS=$winner_whs"
  echo "[impl-race] canonical bitstream: $impl_dir/top.bit"
  exit 0
fi

write_summary
echo "[impl-race] no timing-met winner; routed failures are preserved for diagnosis"
for dir in "${attempt_dirs[@]}"; do
  status_file="$dir/status.txt"
  if [[ -f "$status_file" ]]; then
    echo "---- $dir ----"
    cat "$status_file"
  else
    echo "---- $dir ----"
    echo "STATUS	NO_STATUS"
  fi
done
exit 2
