#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
runtime_script="${STENCIL_RUNTIME_SCRIPT:-${repo_root}/05_runtime_validation/run_server_module.sh}"
manifest="${STENCIL_CASE_MANIFEST:-${repo_root}/profiles/tuning_cases.csv}"
tuning_root="${STENCIL_TUNING_ROOT:-${repo_root}/05_runtime_validation/output/server-profile-tuning}"
profile_file="${STENCIL_PROFILE_FILE:-${repo_root}/profiles/server-sme.env}"
profile_work_file="${profile_file}.tuning"
model_input_file="${SME_PREFETCH_MODEL_INPUT_FILE:-${repo_root}/profiles/server-model.env}"
results_csv="${tuning_root}/candidate_results.csv"
selection_csv="${tuning_root}/profile_selection.csv"
thresholds_file="${tuning_root}/score_thresholds.txt"
hardware_file="${tuning_root}/hardware_metadata.txt"

warmups="${STENCIL_TUNE_WARMUPS:-2}"
samples="${STENCIL_TUNE_SAMPLES:-7}"
minimum_speedup="${STENCIL_TUNE_MIN_CASE_SPEEDUP:-1.00}"
minimum_geomean="${STENCIL_TUNE_MIN_GEOMEAN:-1.03}"
maximum_relative_mad="${STENCIL_TUNE_MAX_RELATIVE_MAD:-0.03}"
timeout_seconds="${STENCIL_TIMEOUT_SECONDS:-1800}"
resume="${STENCIL_TUNE_RESUME:-1}"

if [[ -f "${model_input_file}" ]]; then
  if grep -Ev '^(#.*|[[:space:]]*|export SME_PREFETCH_[A-Z0-9_]+=[0-9]*)$' \
      "${model_input_file}" | grep -q .; then
    printf 'model input file contains an unsupported line: %s\n' \
      "${model_input_file}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "${model_input_file}"
fi

size_to_bytes() {
  local raw="$1"
  case "${raw}" in
    *K) printf '%s' $(( ${raw%K} * 1024 )) ;;
    *M) printf '%s' $(( ${raw%M} * 1024 * 1024 )) ;;
    *G) printf '%s' $(( ${raw%G} * 1024 * 1024 * 1024 )) ;;
    *) printf '%s' "${raw}" ;;
  esac
}

detect_cache_value() {
  local requested_level="$1"
  local field="$2"
  local cache_dir level type value
  for cache_dir in /sys/devices/system/cpu/cpu0/cache/index*; do
    [[ -r "${cache_dir}/level" && -r "${cache_dir}/type" &&
       -r "${cache_dir}/${field}" ]] || continue
    level="$(<"${cache_dir}/level")"
    type="$(<"${cache_dir}/type")"
    [[ "${level}" == "${requested_level}" &&
       ( "${type}" == Data || "${type}" == Unified ) ]] || continue
    value="$(<"${cache_dir}/${field}")"
    [[ "${field}" != size ]] || value="$(size_to_bytes "${value}")"
    printf '%s' "${value}"
    return
  done
}

detected_l1_capacity="$(detect_cache_value 1 size)"
detected_l2_capacity="$(detect_cache_value 2 size)"
detected_cache_line="$(detect_cache_value 1 coherency_line_size)"
detected_streaming_vl=''
if [[ -r /proc/sys/abi/sme_default_vector_length ]]; then
  detected_streaming_vl="$(</proc/sys/abi/sme_default_vector_length)"
fi

profile_l1_capacity="${SME_PREFETCH_L1_CAPACITY_BYTES:-${detected_l1_capacity}}"
profile_l2_capacity="${SME_PREFETCH_L2_CAPACITY_BYTES:-${detected_l2_capacity}}"
profile_cache_line="${SME_PREFETCH_CACHE_LINE_BYTES:-${detected_cache_line}}"
profile_streaming_vl="${SME_PREFETCH_STREAMING_VL_BYTES:-${detected_streaming_vl}}"
profile_l1_capacity_percent="${SME_PREFETCH_L1_CAPACITY_PERCENT:-}"
profile_l2_capacity_percent="${SME_PREFETCH_L2_CAPACITY_PERCENT:-}"
profile_l1_latency="${SME_PREFETCH_L1_LATENCY_CYCLES:-}"
profile_l2_latency="${SME_PREFETCH_L2_LATENCY_CYCLES:-}"
profile_memory_latency="${SME_PREFETCH_MEMORY_LATENCY_CYCLES:-}"
profile_useful_cycles_2d="${SME_PREFETCH_USEFUL_CYCLES_2D:-}"
profile_useful_cycles_3d="${SME_PREFETCH_USEFUL_CYCLES_3D:-}"
profile_max_distance="${SME_PREFETCH_MAX_DISTANCE:-}"
profile_max_streams="${SME_PREFETCH_MAX_STREAMS:-}"
profile_max_instructions="${SME_PREFETCH_MAX_INSTRUCTIONS:-}"
profile_max_bytes="${SME_PREFETCH_MAX_BYTES:-}"
profile_min_confidence="${SME_PREFETCH_MIN_CONFIDENCE:-}"
profile_issue_cost="${SME_PREFETCH_ISSUE_COST:-}"
profile_pressure_weight="${SME_PREFETCH_CACHE_PRESSURE_WEIGHT:-}"
profile_bandwidth_weight="${SME_PREFETCH_BANDWIDTH_WEIGHT:-}"
profile_unknown_trip_penalty="${SME_PREFETCH_UNKNOWN_TRIP_PENALTY:-}"

required_model_values=(
  "SME_PREFETCH_L1_CAPACITY_BYTES:${profile_l1_capacity}"
  "SME_PREFETCH_L2_CAPACITY_BYTES:${profile_l2_capacity}"
  "SME_PREFETCH_CACHE_LINE_BYTES:${profile_cache_line}"
  "SME_PREFETCH_STREAMING_VL_BYTES:${profile_streaming_vl}"
  "SME_PREFETCH_L1_CAPACITY_PERCENT:${profile_l1_capacity_percent}"
  "SME_PREFETCH_L2_CAPACITY_PERCENT:${profile_l2_capacity_percent}"
  "SME_PREFETCH_L1_LATENCY_CYCLES:${profile_l1_latency}"
  "SME_PREFETCH_L2_LATENCY_CYCLES:${profile_l2_latency}"
  "SME_PREFETCH_MEMORY_LATENCY_CYCLES:${profile_memory_latency}"
  "SME_PREFETCH_USEFUL_CYCLES_2D:${profile_useful_cycles_2d}"
  "SME_PREFETCH_USEFUL_CYCLES_3D:${profile_useful_cycles_3d}"
  "SME_PREFETCH_MAX_DISTANCE:${profile_max_distance}"
  "SME_PREFETCH_MAX_STREAMS:${profile_max_streams}"
  "SME_PREFETCH_MAX_INSTRUCTIONS:${profile_max_instructions}"
  "SME_PREFETCH_MAX_BYTES:${profile_max_bytes}"
  "SME_PREFETCH_MIN_CONFIDENCE:${profile_min_confidence}"
  "SME_PREFETCH_ISSUE_COST:${profile_issue_cost}"
  "SME_PREFETCH_CACHE_PRESSURE_WEIGHT:${profile_pressure_weight}"
  "SME_PREFETCH_BANDWIDTH_WEIGHT:${profile_bandwidth_weight}"
  "SME_PREFETCH_UNKNOWN_TRIP_PENALTY:${profile_unknown_trip_penalty}"
)
missing=()
for specification in "${required_model_values[@]}"; do
  key="${specification%%:*}"
  value="${specification#*:}"
  if [[ -z "${value}" || ! "${value}" =~ ^[0-9]+$ ]]; then
    missing+=("${key}")
  fi
done
if [[ "${#missing[@]}" -ne 0 ]]; then
  printf 'missing measured model inputs:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  printf 'run scripts/calibrate_server_model.sh first\n' >&2
  exit 1
fi

for value in "${warmups}" "${samples}" "${timeout_seconds}"; do
  [[ "${value}" =~ ^[0-9]+$ ]] || {
    printf 'warmups, samples, and timeout must be unsigned integers\n' >&2
    exit 1
  }
done
for value in "${minimum_speedup}" "${minimum_geomean}" \
    "${maximum_relative_mad}"; do
  [[ "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
    printf 'speedup and MAD thresholds must be non-negative numbers\n' >&2
    exit 1
  }
done
[[ "${samples}" -gt 0 ]] || { printf 'STENCIL_TUNE_SAMPLES must be positive\n' >&2; exit 1; }
[[ "${resume}" == 0 || "${resume}" == 1 ]] || { printf 'STENCIL_TUNE_RESUME must be 0 or 1\n' >&2; exit 1; }
[[ -x "${runtime_script}" ]] || { printf 'missing runtime script: %s\n' "${runtime_script}" >&2; exit 1; }
[[ -f "${manifest}" ]] || { printf 'missing tuning manifest: %s\n' "${manifest}" >&2; exit 1; }
if [[ "$(sed -n '1p' "${manifest}")" != \
      'argument,kind,size_class,role,weight' ]]; then
  printf 'unexpected tuning manifest header: %s\n' "${manifest}" >&2
  exit 1
fi
if ! awk -F, '
    NR == 1 { next }
    NF != 5 { exit 1 }
    $1 !~ /^--[a-z0-9-]+$/ { exit 1 }
    $4 !~ /^(train|validate)$/ { exit 1 }
    $5 !~ /^[0-9]+([.][0-9]+)?$/ || $5 <= 0 { exit 1 }
    END { if (NR < 2) exit 1 }
  ' "${manifest}"; then
  printf 'invalid tuning manifest: %s\n' "${manifest}" >&2
  exit 1
fi

mkdir -p "${tuning_root}" "$(dirname "${profile_file}")"
manifest_signature="$(cksum "${manifest}" | awk '{ print $1 ":" $2 }')"
all_cases="$(awk -F, 'NR > 1 { printf "%s%s", separator, $1; separator=" " }' "${manifest}")"
train_count="$(awk -F, 'NR > 1 && $4 == "train" { count++ } END { print count + 0 }' "${manifest}")"
validate_count="$(awk -F, 'NR > 1 && $4 == "validate" { count++ } END { print count + 0 }' "${manifest}")"
[[ "${train_count}" -gt 0 ]] || { printf 'manifest has no training cases\n' >&2; exit 1; }

profile_environment=(
  "SME_PREFETCH_PROFILE=generic-sme"
  "SME_PREFETCH_DISTANCE_CURRENT_L1=0"
  "SME_PREFETCH_DISTANCE_ROW_L1=0"
  "SME_PREFETCH_DISTANCE_PLANE_L1=0"
  "SME_PREFETCH_DISTANCE_PLANE_L2=0"
  "SME_PREFETCH_POLICY_CURRENT_L1=AUTO"
  "SME_PREFETCH_POLICY_ROW_L1=AUTO"
  "SME_PREFETCH_POLICY_PLANE_L1=AUTO"
  "SME_PREFETCH_POLICY_PLANE_L2=AUTO"
  "SME_PREFETCH_CACHE_LINE_BYTES=${profile_cache_line}"
  "SME_PREFETCH_STREAMING_VL_BYTES=${profile_streaming_vl}"
  "SME_PREFETCH_L1_CAPACITY_BYTES=${profile_l1_capacity}"
  "SME_PREFETCH_L2_CAPACITY_BYTES=${profile_l2_capacity}"
  "SME_PREFETCH_L1_CAPACITY_PERCENT=${profile_l1_capacity_percent}"
  "SME_PREFETCH_L2_CAPACITY_PERCENT=${profile_l2_capacity_percent}"
  "SME_PREFETCH_L1_LATENCY_CYCLES=${profile_l1_latency}"
  "SME_PREFETCH_L2_LATENCY_CYCLES=${profile_l2_latency}"
  "SME_PREFETCH_MEMORY_LATENCY_CYCLES=${profile_memory_latency}"
  "SME_PREFETCH_USEFUL_CYCLES_2D=${profile_useful_cycles_2d}"
  "SME_PREFETCH_USEFUL_CYCLES_3D=${profile_useful_cycles_3d}"
  "SME_PREFETCH_MAX_DISTANCE=${profile_max_distance}"
  "SME_PREFETCH_MAX_STREAMS=${profile_max_streams}"
  "SME_PREFETCH_MAX_INSTRUCTIONS=${profile_max_instructions}"
  "SME_PREFETCH_MAX_BYTES=${profile_max_bytes}"
  "SME_PREFETCH_MIN_CONFIDENCE=${profile_min_confidence}"
  "SME_PREFETCH_ISSUE_COST=${profile_issue_cost}"
  "SME_PREFETCH_CACHE_PRESSURE_WEIGHT=${profile_pressure_weight}"
  "SME_PREFETCH_BANDWIDTH_WEIGHT=${profile_bandwidth_weight}"
  "SME_PREFETCH_UNKNOWN_TRIP_PENALTY=${profile_unknown_trip_penalty}"
)

discovery_dir="${tuning_root}/score-discovery"
mkdir -p "${discovery_dir}"
env "${profile_environment[@]}" \
  SME_PREFETCH_MIN_PROFIT_SCORE=0 \
  STENCIL_RUNTIME_BUILD_DIR="${discovery_dir}/build" \
  STENCIL_RUNTIME_OUTPUT_DIR="${discovery_dir}" \
  STENCIL_BUILD_ONLY=1 \
  STENCIL_ALLOW_ZERO_PREFETCH=1 \
  EXPECTED_PREFETCH_COUNT= \
  "${runtime_script}"

discovery_log="${discovery_dir}/pass_run.log"
[[ -f "${discovery_log}" ]] || { printf 'missing score discovery log\n' >&2; exit 1; }
if ! grep -q '^StencilDecision:' "${discovery_log}"; then
  printf 'score discovery found no stencil decisions\n' >&2
  exit 1
fi
{
  printf '0\n'
  awk '
    /^StencilDecision:/ {
      for (i = 1; i <= NF; ++i) {
        if ($i ~ /^score=-?[0-9]+$/) {
          split($i, value, "=")
          if (value[2] >= 0)
            print value[2] + 1
        }
      }
    }
  ' "${discovery_log}"
} | sort -n -u > "${thresholds_file}"
disable_threshold="$(tail -n 1 "${thresholds_file}")"

printf 'candidate,min_profit_score,argument,kind,size_class,role,weight,baseline_median_s,prefetch_median_s,speedup,relative_mad\n' > "${results_csv}"
printf 'scope,min_profit_score,outcome,geomean_speedup,worst_speedup,worst_relative_mad,training_cases,prefetch_count\n' > "${selection_csv}"

median_for() {
  local timing_file="$1" test_case="$2" variant="$3"
  awk -F '\t' -v test_case="${test_case}" -v variant="${variant}" \
    '$1 == test_case && $2 == variant { print $4 }' "${timing_file}" |
    sort -n | awk '{ value[NR]=$1 } END {
      if (!NR) exit 1
      if (NR % 2) printf "%.9f", value[(NR + 1) / 2]
      else printf "%.9f", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

mad_for() {
  local timing_file="$1" test_case="$2" variant="$3" median="$4"
  awk -F '\t' -v test_case="${test_case}" -v variant="${variant}" \
    -v median="${median}" '$1 == test_case && $2 == variant {
      difference=$4-median; if (difference < 0) difference=-difference; print difference
    }' "${timing_file}" | sort -n | awk '{ value[NR]=$1 } END {
      if (!NR) exit 1
      if (NR % 2) printf "%.9f", value[(NR + 1) / 2]
      else printf "%.9f", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

append_results() {
  local candidate="$1" threshold="$2" timing_file="$3"
  local test_case kind size_class role weight baseline prefetch baseline_mad prefetch_mad speedup relative_mad
  while IFS=, read -r test_case kind size_class role weight; do
    [[ "${test_case}" != argument ]] || continue
    baseline="$(median_for "${timing_file}" "${test_case}" baseline)"
    prefetch="$(median_for "${timing_file}" "${test_case}" prefetch)"
    baseline_mad="$(mad_for "${timing_file}" "${test_case}" baseline "${baseline}")"
    prefetch_mad="$(mad_for "${timing_file}" "${test_case}" prefetch "${prefetch}")"
    read -r speedup relative_mad < <(awk -v baseline="${baseline}" -v prefetch="${prefetch}" \
      -v baseline_mad="${baseline_mad}" -v prefetch_mad="${prefetch_mad}" 'BEGIN {
        speedup=baseline/prefetch
        br=baseline_mad/baseline; pr=prefetch_mad/prefetch
        mad=br > pr ? br : pr
        printf "%.9f %.9f\n", speedup, mad
      }')
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "${candidate}" "${threshold}" "${test_case}" "${kind}" "${size_class}" \
      "${role}" "${weight}" "${baseline}" "${prefetch}" "${speedup}" \
      "${relative_mad}" >> "${results_csv}"
  done < "${manifest}"
}

run_candidate() {
  local threshold="$1" candidate="score-${threshold}"
  local candidate_dir="${tuning_root}/${candidate}"
  local signature_file="${candidate_dir}/candidate.signature"
  local timing_file="${candidate_dir}/program_time_seconds.tsv"
  local signature expected_rows actual_rows=0
  signature="manifest=${manifest_signature};threshold=${threshold};cases=${all_cases};warmups=${warmups};samples=${samples};model=${profile_l1_capacity}:${profile_l2_capacity}:${profile_cache_line}:${profile_streaming_vl}:${profile_l1_capacity_percent}:${profile_l2_capacity_percent}:${profile_l1_latency}:${profile_l2_latency}:${profile_memory_latency}:${profile_useful_cycles_2d}:${profile_useful_cycles_3d}:${profile_max_distance}:${profile_max_streams}:${profile_max_instructions}:${profile_max_bytes}:${profile_min_confidence}:${profile_issue_cost}:${profile_pressure_weight}:${profile_bandwidth_weight}:${profile_unknown_trip_penalty}"
  expected_rows=$(( $(wc -w <<< "${all_cases}") * 2 * samples ))
  [[ ! -f "${timing_file}" ]] || actual_rows="$(wc -l < "${timing_file}")"
  if [[ "${resume}" == 1 && -f "${signature_file}" &&
        "$(<"${signature_file}")" == "${signature}" &&
        "${actual_rows}" -eq "${expected_rows}" ]]; then
    printf '[profile-tuning] reuse threshold=%s samples=%s\n' "${threshold}" "${actual_rows}" >&2
  else
    printf '[profile-tuning] threshold=%s cases=%s\n' "${threshold}" "${all_cases}" >&2
    mkdir -p "${candidate_dir}"
    env "${profile_environment[@]}" \
      SME_PREFETCH_MIN_PROFIT_SCORE="${threshold}" \
      STENCIL_RUNTIME_BUILD_DIR="${candidate_dir}/build" \
      STENCIL_RUNTIME_OUTPUT_DIR="${candidate_dir}" \
      STENCIL_BUILD_ONLY=0 \
      STENCIL_CASES="${all_cases}" \
      STENCIL_SKIP_CORRECTNESS=1 \
      STENCIL_SINGLE_RUN=0 \
      STENCIL_WARMUPS="${warmups}" \
      STENCIL_SAMPLES="${samples}" \
      STENCIL_TIMEOUT_SECONDS="${timeout_seconds}" \
      STENCIL_ALLOW_ZERO_PREFETCH=1 \
      EXPECTED_PREFETCH_COUNT= \
      "${runtime_script}"
    printf '%s\n' "${signature}" > "${signature_file}"
  fi
  append_results "${candidate}" "${threshold}" "${timing_file}"
}

while IFS= read -r threshold; do
  run_candidate "${threshold}"
done < "${thresholds_file}"

candidate_score() {
  local threshold="$1"
  awk -F, -v threshold="${threshold}" -v minimum="${minimum_speedup}" \
    -v gain="${minimum_geomean}" -v maximum_mad="${maximum_relative_mad}" '
    NR > 1 && $2 == threshold && $6 == "train" {
      count++; weight=$7; speedup=$10; mad=$11
      sum += weight * log(speedup); total_weight += weight
      if (count == 1 || speedup < worst) worst=speedup
      if (mad > worst_mad) worst_mad=mad
    }
    END {
      if (!count) { print "0 0 0 1 0"; exit }
      score=exp(sum/total_weight)
      eligible=worst >= minimum && score >= gain && worst_mad <= maximum_mad
      printf "%.9f %d %.9f %.9f %d\n", score, eligible, worst, worst_mad, count
    }' "${results_csv}"
}

best_threshold="${disable_threshold}"
best_score=1.0
best_worst=1.0
best_mad=0.0
best_count="${train_count}"
outcome=no-eligible-threshold
while IFS= read -r threshold; do
  read -r score eligible worst mad count < <(candidate_score "${threshold}")
  if [[ "${eligible}" == 1 ]] && awk -v score="${score}" -v best="${best_score}" \
      'BEGIN { exit !(score > best) }'; then
    best_threshold="${threshold}"
    best_score="${score}"
    best_worst="${worst}"
    best_mad="${mad}"
    best_count="${count}"
    outcome=selected
  fi
done < "${thresholds_file}"

selected_ir="${tuning_root}/score-${best_threshold}/build/stencil_all_sme.prefetch.ll"
selected_prefetch_count="$(grep -c 'call void @llvm.aarch64.prefetch' "${selected_ir}" 2>/dev/null || true)"
printf 'global,%s,%s,%s,%s,%s,%s,%s\n' \
  "${best_threshold}" "${outcome}" "${best_score}" "${best_worst}" \
  "${best_mad}" "${best_count}" "${selected_prefetch_count:-0}" >> "${selection_csv}"

cat > "${profile_work_file}" <<EOF
# Generated by scripts/04_tune_server_profile.sh.
# Global analytical-score threshold selected across all training workloads.
# Manifest signature: ${manifest_signature}; train=${train_count}; validate=${validate_count}.
export SME_PREFETCH_PROFILE=generic-sme
export SME_PREFETCH_MIN_PROFIT_SCORE=${best_threshold}
export SME_PREFETCH_MIN_CONFIDENCE=${profile_min_confidence}
export SME_PREFETCH_ISSUE_COST=${profile_issue_cost}
export SME_PREFETCH_CACHE_PRESSURE_WEIGHT=${profile_pressure_weight}
export SME_PREFETCH_BANDWIDTH_WEIGHT=${profile_bandwidth_weight}
export SME_PREFETCH_UNKNOWN_TRIP_PENALTY=${profile_unknown_trip_penalty}
export SME_PREFETCH_DISTANCE_CURRENT_L1=0
export SME_PREFETCH_DISTANCE_ROW_L1=0
export SME_PREFETCH_DISTANCE_PLANE_L1=0
export SME_PREFETCH_DISTANCE_PLANE_L2=0
export SME_PREFETCH_POLICY_CURRENT_L1=AUTO
export SME_PREFETCH_POLICY_ROW_L1=AUTO
export SME_PREFETCH_POLICY_PLANE_L1=AUTO
export SME_PREFETCH_POLICY_PLANE_L2=AUTO
export SME_PREFETCH_CACHE_LINE_BYTES=${profile_cache_line}
export SME_PREFETCH_STREAMING_VL_BYTES=${profile_streaming_vl}
export SME_PREFETCH_L1_CAPACITY_BYTES=${profile_l1_capacity}
export SME_PREFETCH_L2_CAPACITY_BYTES=${profile_l2_capacity}
export SME_PREFETCH_L1_CAPACITY_PERCENT=${profile_l1_capacity_percent}
export SME_PREFETCH_L2_CAPACITY_PERCENT=${profile_l2_capacity_percent}
export SME_PREFETCH_L1_LATENCY_CYCLES=${profile_l1_latency}
export SME_PREFETCH_L2_LATENCY_CYCLES=${profile_l2_latency}
export SME_PREFETCH_MEMORY_LATENCY_CYCLES=${profile_memory_latency}
export SME_PREFETCH_USEFUL_CYCLES_2D=${profile_useful_cycles_2d}
export SME_PREFETCH_USEFUL_CYCLES_3D=${profile_useful_cycles_3d}
export SME_PREFETCH_MAX_DISTANCE=${profile_max_distance}
export SME_PREFETCH_MAX_STREAMS=${profile_max_streams}
export SME_PREFETCH_MAX_INSTRUCTIONS=${profile_max_instructions}
export SME_PREFETCH_MAX_BYTES=${profile_max_bytes}
EOF
mv "${profile_work_file}" "${profile_file}"

{
  printf 'model-input=%s\nmanifest=%s\nthresholds=%s\n' \
    "${model_input_file}" "${manifest_signature}" "$(tr '\n' ' ' < "${thresholds_file}")"
  printf '\n[final-profile]\n'
  cat "${profile_file}"
} > "${hardware_file}"

printf '[profile-tuning] profile=%s\n' "${profile_file}"
printf '[profile-tuning] candidates=%s\n' "${results_csv}"
printf '[profile-tuning] selection=%s\n' "${selection_csv}"
printf '[profile-tuning] thresholds=%s\n' "${thresholds_file}"
cat "${selection_csv}"
