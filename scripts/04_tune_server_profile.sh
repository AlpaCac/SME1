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
  local cache_dir
  local level
  local type
  local value

  for cache_dir in /sys/devices/system/cpu/cpu0/cache/index*; do
    if [[ ! -r "${cache_dir}/level" || ! -r "${cache_dir}/type" ||
          ! -r "${cache_dir}/${field}" ]]; then
      continue
    fi
    level="$(<"${cache_dir}/level")"
    type="$(<"${cache_dir}/type")"
    if [[ "${level}" != "${requested_level}" ||
          ( "${type}" != "Data" && "${type}" != "Unified" ) ]]; then
      continue
    fi
    value="$(<"${cache_dir}/${field}")"
    if [[ "${field}" == "size" ]]; then
      value="$(size_to_bytes "${value}")"
    fi
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

for specification in \
    "SME_PREFETCH_L1_CAPACITY_BYTES:${profile_l1_capacity}" \
    "SME_PREFETCH_L2_CAPACITY_BYTES:${profile_l2_capacity}" \
    "SME_PREFETCH_CACHE_LINE_BYTES:${profile_cache_line}" \
    "SME_PREFETCH_STREAMING_VL_BYTES:${profile_streaming_vl}"; do
  key="${specification%%:*}"
  value="${specification#*:}"
  if [[ -z "${value}" ]]; then
    printf 'unable to detect %s; export it with the measured server value\n' \
      "${key}" >&2
    exit 1
  fi
done

for value in "${warmups}" "${samples}" "${timeout_seconds}"; do
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    printf 'warmups, samples, and timeout must be non-negative integers\n' >&2
    exit 1
  fi
done
for value in "${minimum_speedup}" "${minimum_geomean}" \
    "${maximum_relative_mad}"; do
  if [[ ! "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf 'speedup and MAD thresholds must be non-negative numbers\n' >&2
    exit 1
  fi
done
if [[ "${samples}" -eq 0 ]]; then
  printf 'STENCIL_TUNE_SAMPLES must be greater than zero\n' >&2
  exit 1
fi
if [[ "${resume}" != "0" && "${resume}" != "1" ]]; then
  printf 'STENCIL_TUNE_RESUME must be 0 or 1\n' >&2
  exit 1
fi
if [[ ! -x "${runtime_script}" ]]; then
  printf 'missing runtime validation script: %s\n' "${runtime_script}" >&2
  exit 1
fi
if [[ ! -f "${manifest}" ]]; then
  printf 'missing tuning case manifest: %s\n' "${manifest}" >&2
  exit 1
fi
if [[ "$(sed -n '1p' "${manifest}")" != \
      'argument,kind,size_class,role,weight' ]]; then
  printf 'unexpected tuning manifest header: %s\n' "${manifest}" >&2
  exit 1
fi
if ! awk -F, '
    NR == 1 { next }
    NF != 5 { exit 1 }
    $1 !~ /^--[a-z0-9-]+$/ { exit 1 }
    $2 !~ /^(1D3P|2D5P|2D9P|3D7P|3D13P|3D25P|3D27P)$/ { exit 1 }
    $4 !~ /^(train|validate)$/ { exit 1 }
    $5 !~ /^[0-9]+([.][0-9]+)?$/ || $5 <= 0 { exit 1 }
    END { if (NR < 3) exit 1 }
  ' "${manifest}"; then
  printf 'invalid row in tuning case manifest: %s\n' "${manifest}" >&2
  exit 1
fi

manifest_signature="$(cksum "${manifest}" | awk '{ print $1 ":" $2 }')"
train_count="$(awk -F, 'NR > 1 && $4 == "train" { count++ } END { print count + 0 }' "${manifest}")"
validate_count="$(awk -F, 'NR > 1 && $4 == "validate" { count++ } END { print count + 0 }' "${manifest}")"
if [[ "${train_count}" -eq 0 ]]; then
  printf 'manifest requires at least one train case\n' >&2
  exit 1
fi

missing_model_inputs=()
for specification in \
    "SME_PREFETCH_L1_CAPACITY_PERCENT:${profile_l1_capacity_percent}" \
    "SME_PREFETCH_L2_CAPACITY_PERCENT:${profile_l2_capacity_percent}" \
    "SME_PREFETCH_L1_LATENCY_CYCLES:${profile_l1_latency}" \
    "SME_PREFETCH_L2_LATENCY_CYCLES:${profile_l2_latency}" \
    "SME_PREFETCH_MEMORY_LATENCY_CYCLES:${profile_memory_latency}" \
    "SME_PREFETCH_USEFUL_CYCLES_2D:${profile_useful_cycles_2d}" \
    "SME_PREFETCH_USEFUL_CYCLES_3D:${profile_useful_cycles_3d}" \
    "SME_PREFETCH_MAX_DISTANCE:${profile_max_distance}" \
    "SME_PREFETCH_MAX_STREAMS:${profile_max_streams}" \
    "SME_PREFETCH_MAX_INSTRUCTIONS:${profile_max_instructions}" \
    "SME_PREFETCH_MAX_BYTES:${profile_max_bytes}"; do
  key="${specification%%:*}"
  value="${specification#*:}"
  if [[ -z "${value}" ]]; then
    missing_model_inputs+=("${key}")
  fi
done
if (( ${#missing_model_inputs[@]} > 0 )); then
  printf 'missing target model inputs; no generic defaults will be used:\n' >&2
  printf '  %s\n' "${missing_model_inputs[@]}" >&2
  printf 'set them in %s or export them explicitly\n' \
    "${model_input_file}" >&2
  exit 1
fi

for value in "${profile_l1_capacity}" "${profile_l2_capacity}" \
    "${profile_cache_line}" "${profile_streaming_vl}" \
    "${profile_l1_capacity_percent}" "${profile_l2_capacity_percent}" \
    "${profile_l1_latency}" "${profile_l2_latency}" \
    "${profile_memory_latency}" "${profile_useful_cycles_2d}" \
    "${profile_useful_cycles_3d}" "${profile_max_distance}" \
    "${profile_max_streams}" "${profile_max_instructions}" \
    "${profile_max_bytes}"; do
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    printf 'prefetch hardware and model parameters must be unsigned integers\n' >&2
    exit 1
  fi
done
if (( profile_l1_capacity_percent > 100 ||
      profile_l2_capacity_percent > 100 )); then
  printf 'prefetch cache capacity percentages must not exceed 100\n' >&2
  exit 1
fi

cases_for() {
  local scope="$1"
  awk -F, -v scope="${scope}" 'NR > 1 && $4 == "train" {
    selected = 0
    if (scope == "current" && $2 == "1D3P")
      selected = 1
    else if (scope == "row" && $2 ~ /^(2D|3D)/)
      selected = 1
    else if (scope == "plane" && $2 ~ /^3D/)
      selected = 1
    if (selected) {
      printf "%s%s", separator, $1
      separator = " "
    }
  }' "${manifest}"
}

current_cases="$(cases_for current)"
row_cases="$(cases_for row)"
plane_cases="$(cases_for plane)"
for scope in current row plane; do
  cases_var="${scope}_cases"
  if [[ -z "${!cases_var}" ]]; then
    printf 'manifest has no training cases for %s candidates\n' "${scope}" >&2
    exit 1
  fi
done

mkdir -p "${tuning_root}" "$(dirname "${profile_file}")"
printf 'candidate,argument,kind,size_class,role,weight,baseline_median_s,prefetch_median_s,speedup,relative_mad\n' \
  > "${results_csv}"
printf 'kind,selected_candidate,outcome,weighted_geomean,min_speedup,max_relative_mad,training_cases\n' \
  > "${selection_csv}"

{
  printf 'manifest=%s\nmanifest_signature=%s\n' "${manifest}" "${manifest_signature}"
  printf 'model_input_file=%s\n' "${model_input_file}"
  printf 'effective_cache_line_bytes=%s\n' "${profile_cache_line}"
  printf 'effective_streaming_vl_bytes=%s\n' "${profile_streaming_vl}"
  printf 'effective_l1_capacity_bytes=%s\n' "${profile_l1_capacity}"
  printf 'effective_l2_capacity_bytes=%s\n' "${profile_l2_capacity}"
  printf 'uname='; uname -a
  if [[ -r /proc/cpuinfo ]]; then
    grep -m1 -E '^(model name|CPU part|Hardware)[[:space:]]*:' /proc/cpuinfo || true
  fi
  if command -v lscpu >/dev/null 2>&1; then
    lscpu || true
  fi
  for cache_dir in /sys/devices/system/cpu/cpu0/cache/index*; do
    if [[ -d "${cache_dir}" ]]; then
      printf 'cache='
      for field in level type size coherency_line_size; do
        if [[ -r "${cache_dir}/${field}" ]]; then
          printf '%s:%s ' "${field}" "$(<"${cache_dir}/${field}")"
        fi
      done
      printf '\n'
    fi
  done
} > "${hardware_file}"

median_for() {
  local timing_file="$1"
  local test_case="$2"
  local variant="$3"

  awk -F '\t' -v test_case="${test_case}" -v variant="${variant}" \
    '$1 == test_case && $2 == variant { print $4 }' "${timing_file}" |
    sort -n |
    awk '{ value[NR] = $1 } END {
      if (NR == 0)
        exit 1
      if (NR % 2)
        printf "%.9f", value[(NR + 1) / 2]
      else
        printf "%.9f", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

mad_for() {
  local timing_file="$1"
  local test_case="$2"
  local variant="$3"
  local median="$4"

  awk -F '\t' -v test_case="${test_case}" -v variant="${variant}" \
    -v median="${median}" \
    '$1 == test_case && $2 == variant {
      difference = $4 - median
      if (difference < 0)
        difference = -difference
      print difference
    }' "${timing_file}" |
    sort -n |
    awk '{ value[NR] = $1 } END {
      if (NR == 0)
        exit 1
      if (NR % 2)
        printf "%.9f", value[(NR + 1) / 2]
      else
        printf "%.9f", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

append_results() {
  local candidate="$1"
  local cases="$2"
  local timing_file="${tuning_root}/${candidate}/program_time_seconds.tsv"
  local test_case
  local metadata
  local baseline
  local prefetch
  local baseline_mad
  local prefetch_mad
  local speedup
  local relative_mad

  for test_case in ${cases}; do
    metadata="$(awk -F, -v test_case="${test_case}" \
      'NR > 1 && $1 == test_case {
        printf "%s,%s,%s,%s", $2, $3, $4, $5
        exit
      }' "${manifest}")"
    if [[ -z "${metadata}" ]]; then
      printf 'case missing from manifest: %s\n' "${test_case}" >&2
      exit 1
    fi
    baseline="$(median_for "${timing_file}" "${test_case}" baseline)"
    prefetch="$(median_for "${timing_file}" "${test_case}" prefetch)"
    baseline_mad="$(mad_for "${timing_file}" "${test_case}" baseline "${baseline}")"
    prefetch_mad="$(mad_for "${timing_file}" "${test_case}" prefetch "${prefetch}")"
    speedup="$(awk -v baseline="${baseline}" -v prefetch="${prefetch}" \
      'BEGIN { printf "%.9f", baseline / prefetch }')"
    relative_mad="$(awk -v baseline="${baseline}" -v prefetch="${prefetch}" \
      -v baseline_mad="${baseline_mad}" -v prefetch_mad="${prefetch_mad}" \
      'BEGIN {
        baseline_relative = 1
        prefetch_relative = 1
        if (baseline > 0)
          baseline_relative = baseline_mad / baseline
        if (prefetch > 0)
          prefetch_relative = prefetch_mad / prefetch
        relative_mad = prefetch_relative
        if (baseline_relative > prefetch_relative)
          relative_mad = baseline_relative
        printf "%.9f", relative_mad
      }')"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "${candidate}" "${test_case}" "${metadata}" "${baseline}" \
      "${prefetch}" "${speedup}" "${relative_mad}" >> "${results_csv}"
  done
}

run_candidate() {
  local candidate="$1"
  local current="$2"
  local row="$3"
  local plane_l1="$4"
  local plane_l2="$5"
  local cases="$6"
  local candidate_dir="${tuning_root}/${candidate}"
  local signature_file="${candidate_dir}/candidate.signature"
  local timing_file="${candidate_dir}/program_time_seconds.tsv"
  local signature
  local expected_rows
  local actual_rows=0

  signature="manifest=${manifest_signature};current=${current};row=${row};plane_l1=${plane_l1};plane_l2=${plane_l2};cases=${cases};warmups=${warmups};samples=${samples};streams=${profile_max_streams};instructions=${profile_max_instructions};bytes=${profile_max_bytes};line=${profile_cache_line};vl=${profile_streaming_vl};l1=${profile_l1_capacity};l2=${profile_l2_capacity};l1pct=${profile_l1_capacity_percent};l2pct=${profile_l2_capacity_percent};l1lat=${profile_l1_latency};l2lat=${profile_l2_latency};memlat=${profile_memory_latency};cycles2d=${profile_useful_cycles_2d};cycles3d=${profile_useful_cycles_3d};maxdistance=${profile_max_distance}"
  expected_rows=$(( $(wc -w <<< "${cases}") * 2 * samples ))
  if [[ -f "${timing_file}" ]]; then
    actual_rows="$(wc -l < "${timing_file}")"
  fi
  if [[ "${resume}" == "1" && -f "${signature_file}" &&
        "$(<"${signature_file}")" == "${signature}" &&
        "${actual_rows}" -eq "${expected_rows}" ]]; then
    printf '[profile-tuning] reuse candidate=%s samples=%s\n' \
      "${candidate}" "${actual_rows}" >&2
    append_results "${candidate}" "${cases}"
    return
  fi

  printf '[profile-tuning] candidate=%s cases=%s\n' \
    "${candidate}" "${cases}" >&2
  SME_PREFETCH_PROFILE=generic-sme \
  SME_PREFETCH_ENABLE_CURRENT_L1="${current}" \
  SME_PREFETCH_ENABLE_ROW_L1="${row}" \
  SME_PREFETCH_ENABLE_PLANE_L1="${plane_l1}" \
  SME_PREFETCH_ENABLE_PLANE_L2="${plane_l2}" \
  SME_PREFETCH_MASK_CURRENT_L1=127 \
  SME_PREFETCH_MASK_ROW_L1=127 \
  SME_PREFETCH_MASK_PLANE_L1=127 \
  SME_PREFETCH_MASK_PLANE_L2=127 \
  SME_PREFETCH_DISTANCE_CURRENT_L1=0 \
  SME_PREFETCH_DISTANCE_ROW_L1=0 \
  SME_PREFETCH_DISTANCE_PLANE_L1=0 \
  SME_PREFETCH_DISTANCE_PLANE_L2=0 \
  SME_PREFETCH_POLICY_CURRENT_L1=AUTO \
  SME_PREFETCH_POLICY_ROW_L1=AUTO \
  SME_PREFETCH_POLICY_PLANE_L1=AUTO \
  SME_PREFETCH_POLICY_PLANE_L2=AUTO \
  SME_PREFETCH_CACHE_LINE_BYTES="${profile_cache_line}" \
  SME_PREFETCH_STREAMING_VL_BYTES="${profile_streaming_vl}" \
  SME_PREFETCH_L1_CAPACITY_BYTES="${profile_l1_capacity}" \
  SME_PREFETCH_L2_CAPACITY_BYTES="${profile_l2_capacity}" \
  SME_PREFETCH_L1_CAPACITY_PERCENT="${profile_l1_capacity_percent}" \
  SME_PREFETCH_L2_CAPACITY_PERCENT="${profile_l2_capacity_percent}" \
  SME_PREFETCH_L1_LATENCY_CYCLES="${profile_l1_latency}" \
  SME_PREFETCH_L2_LATENCY_CYCLES="${profile_l2_latency}" \
  SME_PREFETCH_MEMORY_LATENCY_CYCLES="${profile_memory_latency}" \
  SME_PREFETCH_USEFUL_CYCLES_2D="${profile_useful_cycles_2d}" \
  SME_PREFETCH_USEFUL_CYCLES_3D="${profile_useful_cycles_3d}" \
  SME_PREFETCH_MAX_DISTANCE="${profile_max_distance}" \
  SME_PREFETCH_MAX_STREAMS="${profile_max_streams}" \
  SME_PREFETCH_MAX_INSTRUCTIONS="${profile_max_instructions}" \
  SME_PREFETCH_MAX_BYTES="${profile_max_bytes}" \
  EXPECTED_PREFETCH_COUNT= \
  STENCIL_RUNTIME_BUILD_DIR="${candidate_dir}/build" \
  STENCIL_RUNTIME_OUTPUT_DIR="${candidate_dir}" \
  STENCIL_CASES="${cases}" \
  STENCIL_SKIP_CORRECTNESS=1 \
  STENCIL_SINGLE_RUN=0 \
  STENCIL_WARMUPS="${warmups}" \
  STENCIL_SAMPLES="${samples}" \
  STENCIL_TIMEOUT_SECONDS="${timeout_seconds}" \
    "${runtime_script}"
  printf '%s\n' "${signature}" > "${signature_file}"
  append_results "${candidate}" "${cases}"
}

candidate_score() {
  local candidate="$1"
  local kind="$2"
  awk -F, -v candidate="${candidate}" -v kind="${kind}" \
    -v minimum="${minimum_speedup}" -v gain="${minimum_geomean}" \
    -v maximum_mad="${maximum_relative_mad}" '
    NR > 1 && $1 == candidate && $3 == kind && $5 == "train" {
      count++
      weight = $6
      speedup = $9
      relative_mad = $10
      sum += weight * log(speedup)
      total_weight += weight
      if (count == 1 || speedup < worst_speedup)
        worst_speedup = speedup
      if (relative_mad > worst_mad)
        worst_mad = relative_mad
    }
    END {
      if (count == 0) {
        printf "0 0 0 1 0\n"
        exit
      }
      score = exp(sum / total_weight)
      eligible = worst_speedup >= minimum && score >= gain &&
                 worst_mad <= maximum_mad
      printf "%.9f %d %.9f %.9f %d\n", score, eligible,
             worst_speedup, worst_mad, count
    }' "${results_csv}"
}

choose_candidate() {
  local kind="$1"
  shift
  local best_candidate=baseline
  local best_score=1.0
  local best_min=1.0
  local best_mad=0.0
  local best_count=0
  local evaluated_count=0
  local candidate
  local score
  local eligible
  local worst_speedup
  local worst_mad
  local count
  local outcome

  for candidate in "$@"; do
    read -r score eligible worst_speedup worst_mad count < <(
      candidate_score "${candidate}" "${kind}")
    if (( count > evaluated_count )); then
      evaluated_count="${count}"
    fi
    if [[ "${eligible}" == "1" ]] && awk \
        -v score="${score}" -v best="${best_score}" \
        'BEGIN { exit !(score > best) }'; then
      best_candidate="${candidate}"
      best_score="${score}"
      best_min="${worst_speedup}"
      best_mad="${worst_mad}"
      best_count="${count}"
    fi
  done
  outcome=selected
  if [[ "${best_candidate}" == "baseline" && "${evaluated_count}" -eq 0 ]]; then
    outcome=no-training-data
  elif [[ "${best_candidate}" == "baseline" ]]; then
    outcome=no-eligible-candidate
    best_count="${evaluated_count}"
  fi
  printf '%s,%s,%s,%s,%s,%s,%s\n' "${kind}" "${best_candidate}" \
    "${outcome}" "${best_score}" "${best_min}" "${best_mad}" "${best_count}" \
    >> "${selection_csv}"
  printf '%s' "${best_candidate}"
}

run_candidate current 1 0 0 0 "${current_cases}"
run_candidate row 0 1 0 0 "${row_cases}"
run_candidate plane-l1 0 0 1 0 "${plane_cases}"
run_candidate plane-l2 0 0 0 1 "${plane_cases}"
run_candidate plane-l1-l2 0 0 1 1 "${plane_cases}"
run_candidate all 0 1 1 1 "${plane_cases}"

current_mask=0
row_mask=0
plane_l1_mask=0
plane_l2_mask=0

selected="$(choose_candidate 1D3P current)"
if [[ "${selected}" != "baseline" ]]; then
  current_mask=$((current_mask | 1))
fi

for specification in '2D5P 2' '2D9P 4'; do
  read -r kind bit <<< "${specification}"
  selected="$(choose_candidate "${kind}" row)"
  if [[ "${selected}" != "baseline" ]]; then
    row_mask=$((row_mask | bit))
  fi
done

for specification in '3D7P 8' '3D13P 16' '3D25P 32' '3D27P 64'; do
  read -r kind bit <<< "${specification}"
  selected="$(choose_candidate "${kind}" row plane-l1 plane-l2 plane-l1-l2 all)"
  case "${selected}" in
    row)
      row_mask=$((row_mask | bit))
      ;;
    plane-l1)
      plane_l1_mask=$((plane_l1_mask | bit))
      ;;
    plane-l2)
      plane_l2_mask=$((plane_l2_mask | bit))
      ;;
    plane-l1-l2)
      plane_l1_mask=$((plane_l1_mask | bit))
      plane_l2_mask=$((plane_l2_mask | bit))
      ;;
    all)
      row_mask=$((row_mask | bit))
      plane_l1_mask=$((plane_l1_mask | bit))
      plane_l2_mask=$((plane_l2_mask | bit))
      ;;
  esac
done

enable_current=$((current_mask != 0))
enable_row=$((row_mask != 0))
enable_plane_l1=$((plane_l1_mask != 0))
enable_plane_l2=$((plane_l2_mask != 0))

cat > "${profile_work_file}" <<EOF
# Generated by scripts/04_tune_server_profile.sh.
# Manifest signature: ${manifest_signature}; train=${train_count}; validate=${validate_count}.
# Selection thresholds: case >= ${minimum_speedup}, geomean >= ${minimum_geomean}, relative MAD <= ${maximum_relative_mad}.
export SME_PREFETCH_PROFILE=generic-sme
export SME_PREFETCH_ENABLE_CURRENT_L1=${enable_current}
export SME_PREFETCH_ENABLE_ROW_L1=${enable_row}
export SME_PREFETCH_ENABLE_PLANE_L1=${enable_plane_l1}
export SME_PREFETCH_ENABLE_PLANE_L2=${enable_plane_l2}
export SME_PREFETCH_MASK_CURRENT_L1=${current_mask}
export SME_PREFETCH_MASK_ROW_L1=${row_mask}
export SME_PREFETCH_MASK_PLANE_L1=${plane_l1_mask}
export SME_PREFETCH_MASK_PLANE_L2=${plane_l2_mask}
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
# Inputs used by the compile-time analytical distance and policy model.
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
  printf '\n[final-profile]\n'
  cat "${profile_file}"
} >> "${hardware_file}"

printf '[profile-tuning] profile=%s\n' "${profile_file}"
printf '[profile-tuning] candidates=%s\n' "${results_csv}"
printf '[profile-tuning] selection=%s\n' "${selection_csv}"
printf '[profile-tuning] hardware=%s\n' "${hardware_file}"
cat "${selection_csv}"
