#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
runtime_script="${STENCIL_RUNTIME_SCRIPT:-${repo_root}/05_runtime_validation/run_server_module.sh}"
tuning_root="${STENCIL_TUNING_ROOT:-${repo_root}/05_runtime_validation/output/server-profile-tuning}"
profile_file="${STENCIL_PROFILE_FILE:-${repo_root}/profiles/server-sme.env}"
results_csv="${tuning_root}/candidate_results.csv"
selection_csv="${tuning_root}/profile_selection.csv"

warmups="${STENCIL_TUNE_WARMUPS:-1}"
samples="${STENCIL_TUNE_SAMPLES:-3}"
minimum_speedup="${STENCIL_TUNE_MIN_CASE_SPEEDUP:-0.98}"
minimum_geomean="${STENCIL_TUNE_MIN_GEOMEAN:-1.01}"
timeout_seconds="${STENCIL_TIMEOUT_SECONDS:-1800}"
resume="${STENCIL_TUNE_RESUME:-1}"

current_cases='--1d3p-s1 --1d3p-s2'
row_cases='--2d5p-s1 --2d5p-s2 --2d9p-s1 --2d9p-s2 --3d13p-s1 --3d13p-s2 --3d25p-s1 --3d25p-s2 --3d27p-s1 --3d27p-s2'
plane_cases='--3d13p-s1 --3d13p-s2 --3d25p-s1 --3d25p-s2 --3d27p-s1 --3d27p-s2'

for value in "${warmups}" "${samples}" "${timeout_seconds}"; do
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    printf 'warmups, samples, and timeout must be non-negative integers\n' >&2
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

mkdir -p "${tuning_root}" "$(dirname "${profile_file}")"
printf 'candidate,case,baseline_median_s,prefetch_median_s,speedup\n' \
  > "${results_csv}"
printf 'stencil,selected_candidate,geomean_speedup\n' > "${selection_csv}"

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

append_results() {
  local candidate="$1"
  local cases="$2"
  local timing_file="${tuning_root}/${candidate}/program_time_seconds.tsv"
  local test_case
  local baseline
  local prefetch
  local speedup

  for test_case in ${cases}; do
    baseline="$(median_for "${timing_file}" "${test_case}" baseline)"
    prefetch="$(median_for "${timing_file}" "${test_case}" prefetch)"
    speedup="$(awk -v baseline="${baseline}" -v prefetch="${prefetch}" \
      'BEGIN { printf "%.9f", baseline / prefetch }')"
    printf '%s,%s,%s,%s,%s\n' \
      "${candidate}" "${test_case}" "${baseline}" "${prefetch}" \
      "${speedup}" >> "${results_csv}"
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

  signature="current=${current};row=${row};plane_l1=${plane_l1};plane_l2=${plane_l2};cases=${cases};warmups=${warmups};samples=${samples};streams=${SME_PREFETCH_MAX_STREAMS:-5};instructions=${SME_PREFETCH_MAX_INSTRUCTIONS:-8};bytes=${SME_PREFETCH_MAX_BYTES:-512}"
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
  SME_PREFETCH_MAX_STREAMS="${SME_PREFETCH_MAX_STREAMS:-5}" \
  SME_PREFETCH_MAX_INSTRUCTIONS="${SME_PREFETCH_MAX_INSTRUCTIONS:-8}" \
  SME_PREFETCH_MAX_BYTES="${SME_PREFETCH_MAX_BYTES:-512}" \
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

speedup_for() {
  local candidate="$1"
  local test_case="$2"
  awk -F, -v candidate="${candidate}" -v test_case="${test_case}" \
    '$1 == candidate && $2 == test_case { print $5; exit }' "${results_csv}"
}

choose_candidate() {
  local stencil="$1"
  local first_case="$2"
  local second_case="$3"
  shift 3
  local best_candidate=baseline
  local best_score=1.0
  local candidate
  local first_speedup
  local second_speedup
  local score
  local eligible

  for candidate in "$@"; do
    first_speedup="$(speedup_for "${candidate}" "${first_case}")"
    second_speedup="$(speedup_for "${candidate}" "${second_case}")"
    if [[ -z "${first_speedup}" || -z "${second_speedup}" ]]; then
      continue
    fi
    read -r score eligible < <(awk \
      -v first="${first_speedup}" -v second="${second_speedup}" \
      -v minimum="${minimum_speedup}" -v gain="${minimum_geomean}" \
      'BEGIN {
        score = sqrt(first * second)
        eligible = first >= minimum && second >= minimum && score >= gain
        printf "%.9f %d", score, eligible
      }')
    if [[ "${eligible}" == "1" ]] && awk \
        -v score="${score}" -v best="${best_score}" \
        'BEGIN { exit !(score > best) }'; then
      best_candidate="${candidate}"
      best_score="${score}"
    fi
  done
  printf '%s,%s,%s\n' "${stencil}" "${best_candidate}" "${best_score}" \
    >> "${selection_csv}"
  printf '%s' "${best_candidate}"
}

run_candidate current 1 0 0 0 "${current_cases}"
run_candidate row 0 1 0 0 "${row_cases}"
run_candidate plane-l1 0 0 1 0 "${plane_cases}"
run_candidate plane-l2 0 0 0 1 "${plane_cases}"
run_candidate plane-l1-l2 0 0 1 1 "${plane_cases}"
run_candidate all 1 1 1 1 "${plane_cases}"

current_mask=0
row_mask=0
plane_l1_mask=0
plane_l2_mask=0

selected="$(choose_candidate 1D3P --1d3p-s1 --1d3p-s2 current)"
if [[ "${selected}" != "baseline" ]]; then
  current_mask=$((current_mask | 1))
fi

for specification in \
    '2D5P 2 --2d5p-s1 --2d5p-s2' \
    '2D9P 4 --2d9p-s1 --2d9p-s2'; do
  read -r stencil bit first_case second_case <<< "${specification}"
  selected="$(choose_candidate "${stencil}" "${first_case}" \
    "${second_case}" row)"
  if [[ "${selected}" != "baseline" ]]; then
    row_mask=$((row_mask | bit))
  fi
done

for specification in \
    '3D13P 16 --3d13p-s1 --3d13p-s2' \
    '3D25P 32 --3d25p-s1 --3d25p-s2' \
    '3D27P 64 --3d27p-s1 --3d27p-s2'; do
  read -r stencil bit first_case second_case <<< "${specification}"
  selected="$(choose_candidate "${stencil}" "${first_case}" \
    "${second_case}" row plane-l1 plane-l2 plane-l1-l2 all)"
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

cat > "${profile_file}" <<EOF
# Generated by scripts/04_tune_server_profile.sh.
# Selection thresholds: per-case >= ${minimum_speedup}, pair geomean >= ${minimum_geomean}.
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
export SME_PREFETCH_MAX_STREAMS=${SME_PREFETCH_MAX_STREAMS:-5}
export SME_PREFETCH_MAX_INSTRUCTIONS=${SME_PREFETCH_MAX_INSTRUCTIONS:-8}
export SME_PREFETCH_MAX_BYTES=${SME_PREFETCH_MAX_BYTES:-512}
EOF

printf '[profile-tuning] profile=%s\n' "${profile_file}"
printf '[profile-tuning] candidates=%s\n' "${results_csv}"
printf '[profile-tuning] selection=%s\n' "${selection_csv}"
cat "${selection_csv}"
