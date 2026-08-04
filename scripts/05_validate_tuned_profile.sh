#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
validation_script="${STENCIL_VALIDATION_SCRIPT:-${script_dir}/03_validate_server_runtime.sh}"
profile_file="${STENCIL_PROFILE_FILE:-${repo_root}/profiles/server-sme.env}"
manifest="${STENCIL_CASE_MANIFEST:-${repo_root}/profiles/tuning_cases.csv}"
build_dir="${STENCIL_FINAL_BUILD_DIR:-${repo_root}/05_runtime_validation/build/server-profile-final}"
output_dir="${STENCIL_FINAL_OUTPUT_DIR:-${repo_root}/05_runtime_validation/output/server-profile-final}"
validation_csv="${output_dir}/heldout_validation.csv"
minimum_speedup="${STENCIL_VALIDATE_MIN_SPEEDUP:-1.00}"
maximum_relative_mad="${STENCIL_VALIDATE_MAX_RELATIVE_MAD:-0.03}"

for value in "${minimum_speedup}" "${maximum_relative_mad}"; do
  if [[ ! "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf 'validation speedup and MAD thresholds must be non-negative numbers\n' >&2
    exit 1
  fi
done

if [[ ! -f "${profile_file}" ]]; then
  printf 'missing tuned profile: %s\n' "${profile_file}" >&2
  printf 'run ./scripts/04_tune_server_profile.sh first.\n' >&2
  exit 1
fi
if [[ ! -x "${validation_script}" ]]; then
  printf 'missing runtime validation script: %s\n' "${validation_script}" >&2
  exit 1
fi
if [[ ! -f "${manifest}" ]]; then
  printf 'missing tuning case manifest: %s\n' "${manifest}" >&2
  exit 1
fi
if grep -Ev '^(#.*|[[:space:]]*|export SME_PREFETCH_[A-Z0-9_]+=[A-Za-z0-9._-]+)$' \
    "${profile_file}" | grep -q .; then
  printf 'tuned profile contains an unsupported line: %s\n' \
    "${profile_file}" >&2
  exit 1
fi

all_cases="$(awk -F, 'NR > 1 {
  printf "%s%s", separator, $1
  separator = " "
}' "${manifest}")"
validate_count="$(awk -F, 'NR > 1 && $4 == "validate" { count++ }
  END { print count + 0 }' "${manifest}")"
if [[ -z "${all_cases}" || "${validate_count}" -eq 0 ]]; then
  printf 'manifest requires cases and at least one validate row\n' >&2
  exit 1
fi

# The generated file contains only export assignments for SME_PREFETCH_*.
# shellcheck disable=SC1090
source "${profile_file}"

EXPECTED_PREFETCH_COUNT= \
STENCIL_ALLOW_ZERO_PREFETCH=1 \
STENCIL_RUNTIME_BUILD_DIR="${build_dir}" \
STENCIL_RUNTIME_OUTPUT_DIR="${output_dir}" \
STENCIL_CASES="${all_cases}" \
STENCIL_SINGLE_RUN=0 \
STENCIL_WARMUPS="${STENCIL_FINAL_WARMUPS:-2}" \
STENCIL_SAMPLES="${STENCIL_FINAL_SAMPLES:-7}" \
  "${validation_script}"

timing_file="${output_dir}/program_time_seconds.tsv"
if [[ ! -f "${timing_file}" ]]; then
  printf 'missing final program timing data: %s\n' "${timing_file}" >&2
  exit 1
fi

median_for() {
  local test_case="$1"
  local variant="$2"
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
  local test_case="$1"
  local variant="$2"
  local median="$3"
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

mkdir -p "${output_dir}"
printf 'argument,kind,size_class,baseline_median_s,prefetch_median_s,speedup,relative_mad,status\n' \
  > "${validation_csv}"
validation_failed=0
while IFS=, read -r test_case kind size_class role weight row_bytes \
    plane_bytes working_set_bytes; do
  if [[ "${test_case}" == "argument" || "${role}" != "validate" ]]; then
    continue
  fi
  baseline="$(median_for "${test_case}" baseline)"
  prefetch="$(median_for "${test_case}" prefetch)"
  baseline_mad="$(mad_for "${test_case}" baseline "${baseline}")"
  prefetch_mad="$(mad_for "${test_case}" prefetch "${prefetch}")"
  read -r speedup relative_mad status < <(awk \
    -v baseline="${baseline}" -v prefetch="${prefetch}" \
    -v baseline_mad="${baseline_mad}" -v prefetch_mad="${prefetch_mad}" \
    -v minimum="${minimum_speedup}" -v maximum_mad="${maximum_relative_mad}" \
    'BEGIN {
      speedup = baseline / prefetch
      baseline_relative = 1
      prefetch_relative = 1
      if (baseline > 0)
        baseline_relative = baseline_mad / baseline
      if (prefetch > 0)
        prefetch_relative = prefetch_mad / prefetch
      relative_mad = prefetch_relative
      if (baseline_relative > prefetch_relative)
        relative_mad = baseline_relative
      status = "FAIL"
      if (speedup >= minimum && relative_mad <= maximum_mad)
        status = "PASS"
      printf "%.9f %.9f %s\n", speedup, relative_mad, status
    }')
  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "${test_case}" "${kind}" "${size_class}" "${baseline}" "${prefetch}" \
    "${speedup}" "${relative_mad}" "${status}" >> "${validation_csv}"
  if [[ "${status}" != "PASS" ]]; then
    validation_failed=1
  fi
done < "${manifest}"

cat "${validation_csv}"
if [[ "${validation_failed}" -ne 0 ]]; then
  printf 'tuned profile failed held-out validation: %s\n' \
    "${validation_csv}" >&2
  exit 1
fi
printf 'tuned profile passed held-out validation: %s\n' "${validation_csv}"
