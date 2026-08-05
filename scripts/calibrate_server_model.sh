#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source_file="${script_dir}/calibration/server_model_calibration.cpp"
output_file="${SME_PREFETCH_MODEL_INPUT_FILE:-${repo_root}/profiles/server-model.env}"
output_dir="${SME_CALIBRATION_OUTPUT_DIR:-${repo_root}/05_runtime_validation/output/server-model-calibration}"
binary="${output_dir}/server_model_calibration"
raw_results="${output_dir}/calibration_results.txt"
march="${MARCH:-armv9.2-a+sme+sve2+sme-f64f64}"
samples="${SME_CALIBRATION_SAMPLES:-5}"
accesses="${SME_CALIBRATION_ACCESSES:-10000000}"
stream_accesses="${SME_CALIBRATION_STREAM_ACCESSES:-1000000}"
cpu="${STENCIL_CPU:-0}"

: "${BISHENG_CXX:?set BISHENG_CXX to the BiSheng clang++ executable}"

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

detect_last_cache_capacity() {
  local cache_dir type value largest=0
  for cache_dir in /sys/devices/system/cpu/cpu0/cache/index*; do
    [[ -r "${cache_dir}/type" && -r "${cache_dir}/size" ]] || continue
    type="$(<"${cache_dir}/type")"
    [[ "${type}" == Data || "${type}" == Unified ]] || continue
    value="$(size_to_bytes "$(<"${cache_dir}/size")")"
    (( value <= largest )) || largest="${value}"
  done
  printf '%s' "${largest}"
}

round_up() {
  awk -v value="$1" 'BEGIN { rounded = int(value); if (value > rounded) rounded++; print rounded }'
}

for value in "${samples}" "${accesses}" "${stream_accesses}" "${cpu}"; do
  [[ "${value}" =~ ^[0-9]+$ ]] || { printf 'calibration controls must be unsigned integers\n' >&2; exit 1; }
done
if [[ "${samples}" == 0 || "${accesses}" == 0 ||
      "${stream_accesses}" == 0 ]]; then
  printf 'calibration samples and access counts must be positive\n' >&2
  exit 1
fi
[[ -x "${BISHENG_CXX}" ]] || { printf 'missing BiSheng clang++: %s\n' "${BISHENG_CXX}" >&2; exit 1; }
[[ -f "${source_file}" ]] || { printf 'missing calibration source: %s\n' "${source_file}" >&2; exit 1; }
command -v taskset >/dev/null 2>&1 || { printf 'calibration requires taskset\n' >&2; exit 1; }

l1_capacity="${SME_PREFETCH_L1_CAPACITY_BYTES:-$(detect_cache_value 1 size)}"
l2_capacity="${SME_PREFETCH_L2_CAPACITY_BYTES:-$(detect_cache_value 2 size)}"
cache_line="${SME_PREFETCH_CACHE_LINE_BYTES:-$(detect_cache_value 1 coherency_line_size)}"
l1_ways="${SME_CALIBRATION_L1_WAYS:-$(detect_cache_value 1 ways_of_associativity)}"
l2_ways="${SME_CALIBRATION_L2_WAYS:-$(detect_cache_value 2 ways_of_associativity)}"
streaming_vl="${SME_PREFETCH_STREAMING_VL_BYTES:-}"
if [[ -z "${streaming_vl}" && -r /proc/sys/abi/sme_default_vector_length ]]; then
  streaming_vl="$(</proc/sys/abi/sme_default_vector_length)"
fi
last_capacity="${SME_CALIBRATION_LAST_CACHE_BYTES:-$(detect_last_cache_capacity)}"

for specification in \
    "L1 capacity:${l1_capacity}" "L2 capacity:${l2_capacity}" \
    "cache line:${cache_line}" "L1 associativity:${l1_ways}" \
    "L2 associativity:${l2_ways}" "streaming VL:${streaming_vl}" \
    "last cache capacity:${last_capacity}"; do
  key="${specification%%:*}"
  value="${specification#*:}"
  if [[ -z "${value}" || ! "${value}" =~ ^[0-9]+$ || "${value}" == 0 ]]; then
    printf 'unable to detect %s; provide its calibration override\n' "${key}" >&2
    exit 1
  fi
done
if (( l1_ways < 2 || l2_ways < 2 )); then
  printf 'cache associativity must be at least two to reserve one way\n' >&2
  exit 1
fi

l1_test_bytes=$((l1_capacity / 2))
l2_test_bytes=$((l1_capacity + (l2_capacity - l1_capacity) / 2))
memory_test_bytes=$((last_capacity * 4))
minimum_memory_bytes=$((64 * 1024 * 1024))
(( memory_test_bytes >= minimum_memory_bytes )) || memory_test_bytes="${minimum_memory_bytes}"
maximum_memory_bytes="${SME_CALIBRATION_MAX_MEMORY_BYTES:-536870912}"
if [[ ! "${maximum_memory_bytes}" =~ ^[0-9]+$ ||
      "${maximum_memory_bytes}" == 0 ]]; then
  printf 'SME_CALIBRATION_MAX_MEMORY_BYTES must be a positive integer\n' >&2
  exit 1
fi
if (( l2_capacity <= l1_capacity )); then
  printf 'L2 capacity must be greater than L1 capacity\n' >&2
  exit 1
fi
(( memory_test_bytes <= maximum_memory_bytes )) || memory_test_bytes="${maximum_memory_bytes}"

mkdir -p "${output_dir}" "$(dirname "${output_file}")"
"${BISHENG_CXX}" -O3 -std=c++17 -march="${march}" "${source_file}" -o "${binary}"
taskset -c "${cpu}" "${binary}" "${l1_test_bytes}" "${l2_test_bytes}" \
  "${memory_test_bytes}" "${accesses}" "${samples}" "${streaming_vl}" \
  "${cache_line}" "${stream_accesses}" \
  > "${raw_results}"

result_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "${raw_results}"
}

l1_latency="$(round_up "$(result_value l1_dependent_load_cycles)")"
l2_latency="$(round_up "$(result_value l2_dependent_load_cycles)")"
memory_latency="$(round_up "$(result_value memory_dependent_load_cycles)")"
useful_cycles_2d="$(round_up "$(result_value useful_cycles_2d)")"
useful_cycles_3d="$(round_up "$(result_value useful_cycles_3d)")"
max_streams="$(result_value sustainable_prefetch_streams)"
l1_capacity_percent=$(((l1_ways - 1) * 100 / l1_ways))
l2_capacity_percent=$(((l2_ways - 1) * 100 / l2_ways))

minimum_useful_cycles="${useful_cycles_2d}"
(( useful_cycles_3d >= minimum_useful_cycles )) || minimum_useful_cycles="${useful_cycles_3d}"
max_distance=$(((memory_latency + minimum_useful_cycles - 1) / minimum_useful_cycles))

if [[ -z "${max_streams}" || ! "${max_streams}" =~ ^[0-9]+$ ||
      "${max_streams}" == 0 || "${max_streams}" -gt 17 ]]; then
  printf 'invalid measured sustainable prefetch stream count: %s\n' \
    "${max_streams:-<unset>}" >&2
  exit 1
fi
lines_per_vector=$(((streaming_vl + cache_line - 1) / cache_line))
max_instructions=$((max_streams * lines_per_vector))
max_bytes=$((max_instructions * cache_line))

temporary="${output_file}.tmp"
cat > "${temporary}" <<EOF
# Generated by scripts/calibrate_server_model.sh; do not share across machines.
export SME_PREFETCH_CACHE_LINE_BYTES=${cache_line}
export SME_PREFETCH_STREAMING_VL_BYTES=${streaming_vl}
export SME_PREFETCH_L1_CAPACITY_BYTES=${l1_capacity}
export SME_PREFETCH_L2_CAPACITY_BYTES=${l2_capacity}
export SME_PREFETCH_L1_CAPACITY_PERCENT=${l1_capacity_percent}
export SME_PREFETCH_L2_CAPACITY_PERCENT=${l2_capacity_percent}
export SME_PREFETCH_L1_LATENCY_CYCLES=${l1_latency}
export SME_PREFETCH_L2_LATENCY_CYCLES=${l2_latency}
export SME_PREFETCH_MEMORY_LATENCY_CYCLES=${memory_latency}
export SME_PREFETCH_USEFUL_CYCLES_2D=${useful_cycles_2d}
export SME_PREFETCH_USEFUL_CYCLES_3D=${useful_cycles_3d}
export SME_PREFETCH_MAX_DISTANCE=${max_distance}
export SME_PREFETCH_MAX_STREAMS=${max_streams}
export SME_PREFETCH_MAX_INSTRUCTIONS=${max_instructions}
export SME_PREFETCH_MAX_BYTES=${max_bytes}
EOF
mv "${temporary}" "${output_file}"

{
  printf '\ncalibration_l1_test_bytes=%s\n' "${l1_test_bytes}"
  printf 'calibration_l2_test_bytes=%s\n' "${l2_test_bytes}"
  printf 'calibration_memory_test_bytes=%s\n' "${memory_test_bytes}"
  printf 'calibration_l1_ways=%s\n' "${l1_ways}"
  printf 'calibration_l2_ways=%s\n' "${l2_ways}"
  printf 'calibration_sustainable_prefetch_streams=%s\n' "${max_streams}"
  printf 'calibration_stream_accesses=%s\n' "${stream_accesses}"
  printf 'model_file=%s\n' "${output_file}"
} >> "${raw_results}"

printf '[model-calibration] profile=%s\n' "${output_file}"
printf '[model-calibration] raw-results=%s\n' "${raw_results}"
cat "${output_file}"
