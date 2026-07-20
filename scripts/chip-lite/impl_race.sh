#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tag="${TAG:-${BUILD_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)}}"
vivado_bin="${VIVADO:-vivado}"
impl_jobs="${IMPL_JOBS:-4}"
poll_sec="${RACE_POLL_SEC:-60}"
stop_on_win="${RACE_STOP_ON_WIN:-1}"

place_threads="${PLACE_THREADS:-16}"
route_threads="${ROUTE_THREADS:-16}"
vivado_threads="${VIVADO_THREADS:-32}"
synth_jobs="${SYNTH_JOBS:-128}"

impl_dir="$repo_root/build/lite/$tag/ImplOutputDir"
source_dcp="$impl_dir/post_opt.dcp"
race_root="$impl_dir/race"
log_dir="$repo_root/logs"
artifact_dir="$repo_root/artifacts/bitstreams"

if [[ ! -f "$source_dcp" ]]; then
  echo "ERROR: missing post_opt checkpoint: $source_dcp" >&2
  echo "Run first: make synth-to-opt TAG=$tag" >&2
  exit 1
fi

mkdir -p "$race_root" "$log_dir" "$artifact_dir"

strategies=(
  "ExtraTimingOpt|AggressiveExplore|NoTimingRelaxation"
  "ExtraTimingOpt|AggressiveExplore|AggressiveExplore"
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

echo "[impl-race] tag=$tag jobs=$impl_jobs place_threads=$place_threads route_threads=$route_threads"
echo "[impl-race] source=$source_dcp"

pids=()
attempt_dirs=()

launch_attempt() {
  local idx="$1"
  local strategy="${strategies[$idx]}"
  local place="${strategy%%|*}"
  local rest="${strategy#*|}"
  local phys="${rest%%|*}"
  local route="${rest#*|}"
  local attempt="attempt${idx}_${place}_${phys}_${route}"
  local attempt_dir="$race_root/$attempt"
  local stdout_log="$log_dir/${tag}_race_${idx}.stdout.log"
  local vivado_log="$log_dir/${tag}_race_${idx}.vivado.log"
  local journal="$log_dir/${tag}_race_${idx}.jou"

  mkdir -p "$attempt_dir"
  echo "[impl-race] launch $attempt"
  setsid bash -c "exec env \
    BUILD_TAG='$tag' \
    SOURCE_DCP='$source_dcp' \
    RACE_ROOT='$race_root' \
    IMPL_ATTEMPT='$attempt' \
    PLACE_DIRECTIVE='$place' \
    PHYS_OPT_DIRECTIVE='$phys' \
    ROUTE_DIRECTIVE='$route' \
    VIVADO_THREADS='$vivado_threads' \
    PLACE_THREADS='$place_threads' \
    ROUTE_THREADS='$route_threads' \
    SYNTH_JOBS='$synth_jobs' \
    '$vivado_bin' -mode batch \
      -source '$repo_root/scripts/chip-lite/impl_race_worker.tcl' \
      -journal '$journal' \
      -log '$vivado_log'" >"$stdout_log" 2>&1 &

  pids+=("$!")
  attempt_dirs+=("$attempt_dir")
}

status_value() {
  local file="$1"
  local key="$2"
  awk -F '\t' -v k="$key" '$1 == k {print $2; exit}' "$file" 2>/dev/null || true
}

find_success() {
  local dir status_file status
  for dir in "${attempt_dirs[@]}"; do
    status_file="$dir/status.txt"
    [[ -f "$status_file" ]] || continue
    status="$(status_value "$status_file" STATUS)"
    if [[ "$status" == "SUCCESS" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

copy_winner() {
  local winner_dir="$1"
  local status_file="$winner_dir/status.txt"
  local bit="$winner_dir/top.bit"
  local bin="$winner_dir/top.bin"

  if [[ ! -f "$bit" ]]; then
    echo "ERROR: winner has no bitstream: $bit" >&2
    return 1
  fi

  cp -f "$bit" "$artifact_dir/${tag}.bit"
  if [[ -f "$bin" ]]; then
    cp -f "$bin" "$artifact_dir/${tag}.bin"
  fi

  local attempt place phys route wns whs
  attempt="$(status_value "$status_file" ATTEMPT)"
  place="$(status_value "$status_file" PLACE)"
  phys="$(status_value "$status_file" PHYS_OPT)"
  route="$(status_value "$status_file" ROUTE)"
  wns="$(status_value "$status_file" POST_ROUTE_WNS)"
  whs="$(status_value "$status_file" POST_ROUTE_WHS)"

  cat >"$artifact_dir/${tag}.manifest.json" <<EOF_MANIFEST
{
  "tag": "$tag",
  "source_commit": "$(git rev-parse HEAD 2>/dev/null || echo unknown)",
  "vivado": "$("$vivado_bin" -version 2>/dev/null | head -1 | sed 's/"/\\"/g')",
  "winner_attempt": "$attempt",
  "place_directive": "$place",
  "phys_opt_directive": "$phys",
  "route_directive": "$route",
  "place_threads": "$place_threads",
  "route_threads": "$route_threads",
  "post_route_wns": "$wns",
  "post_route_whs": "$whs",
  "remote_build_dir": "$impl_dir",
  "bitstream": "$artifact_dir/${tag}.bit"
}
EOF_MANIFEST

  echo "[impl-race] WINNER $attempt WNS=$wns WHS=$whs"
  echo "[impl-race] artifact: $artifact_dir/${tag}.bit"
}

terminate_workers() {
  local pid
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
  done
}

for ((i = 0; i < impl_jobs; i++)); do
  launch_attempt "$i"
done

if [[ "$stop_on_win" == "1" ]]; then
  while :; do
    if winner_dir="$(find_success)"; then
      copy_winner "$winner_dir"
      terminate_workers
      for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
      exit 0
    fi

    live=0
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then live=1; fi
    done
    if (( live == 0 )); then
      break
    fi
    sleep "$poll_sec"
  done
else
  for pid in "${pids[@]}"; do wait "$pid" || true; done
fi

if winner_dir="$(find_success)"; then
  copy_winner "$winner_dir"
  exit 0
fi

echo "[impl-race] no timing-clean winner"
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
