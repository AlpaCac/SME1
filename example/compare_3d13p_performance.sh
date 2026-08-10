#!/usr/bin/env bash
# 在 AArch64 SME 服务器上逐项比较原始实现与论文式 ZA 映射实现。
#
# 用法：
#   BISHENG_CXX=/path/to/bisheng/bin/clang++ \
#   SME_PERF_CPU=0 SME_PERF_REPETITIONS=3 \
#   ./example/compare_3d13p_performance.sh
#
# 默认测试六类算子的 stride-1/stride-2，共 12 个用例。可用空格或逗号筛选：
#   SME_PERF_CASES="2d5p-s1,3d13p-s2" ./example/compare_3d13p_performance.sh
# 若要比较纯 ZA、单 ZA、加载复用、直接写回和预取候选，设置 SME_PERF_ABLATIONS=1。
#
# 每条 Time: 是程序内部 100 次 kernel sweep 的总时间，不包括初始化和自检。
# 默认使用毕昇 compiler-rt 的 SME ABI 运行时，解决 __arm_tpidr2_save 等链接符号。

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cxx="${BISHENG_CXX:-${CXX:-clang++}}"
repetitions="${SME_PERF_REPETITIONS:-3}"
cpu="${SME_PERF_CPU:-}"
timeout_seconds="${SME_PERF_TIMEOUT_SECONDS:-0}"
ablations="${SME_PERF_ABLATIONS:-0}"
build_dir="${SME_PERF_BUILD_DIR:-${TMPDIR:-/tmp}/sme1-all-stencil-performance}"
results_csv="${SME_PERF_RESULTS_CSV:-${build_dir}/performance_results.csv}"

baseline_source="${script_dir}/stencil_all_sme.cpp"
paper_source="${script_dir}/smestencil_paper_3d13.cpp"
baseline_bin="${build_dir}/stencil_all_sme"
paper_bin="${build_dir}/smestencil_paper"
single_za_bin="${build_dir}/smestencil_paper_single_za"
no_reuse_bin="${build_dir}/smestencil_paper_no_reuse"
force_za_bin="${build_dir}/smestencil_paper_force_za"
indirect_store_bin="${build_dir}/smestencil_paper_indirect_store"
prefetch_bin="${build_dir}/smestencil_paper_prefetch"

all_cases=(
  1d3p-s1 1d3p-s2
  2d5p-s1 2d5p-s2
  2d9p-s1 2d9p-s2
  3d13p-s1 3d13p-s2
  3d25p-s1 3d25p-s2
  3d27p-s1 3d27p-s2
)

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

case_exists() {
  local wanted="$1"
  local candidate
  for candidate in "${all_cases[@]}"; do
    [[ "${candidate}" == "${wanted}" ]] && return 0
  done
  return 1
}

selected_cases=()
if [[ -n "${SME_PERF_CASES:-}" ]]; then
  requested_cases="${SME_PERF_CASES//,/ }"
  read -r -a selected_cases <<< "${requested_cases}"
  ((${#selected_cases[@]} > 0)) || die "SME_PERF_CASES did not select any case"
  for test_case in "${selected_cases[@]}"; do
    case_exists "${test_case}" || \
      die "unknown case '${test_case}'; expected one of: ${all_cases[*]}"
  done
else
  selected_cases=("${all_cases[@]}")
fi

[[ -x "${cxx}" || -n "$(command -v "${cxx}" 2>/dev/null || true)" ]] || \
  die "compiler not found: ${cxx}; set BISHENG_CXX to the server clang++ path"
[[ -f "${baseline_source}" ]] || die "missing source: ${baseline_source}"
[[ -f "${paper_source}" ]] || die "missing source: ${paper_source}"
[[ "${repetitions}" =~ ^[1-9][0-9]*$ ]] || \
  die "SME_PERF_REPETITIONS must be a positive integer"
[[ "${timeout_seconds}" =~ ^[0-9]+$ ]] || \
  die "SME_PERF_TIMEOUT_SECONDS must be a non-negative integer"
[[ "${ablations}" == "0" || "${ablations}" == "1" ]] || \
  die "SME_PERF_ABLATIONS must be 0 or 1"

compiler_version="$("${cxx}" --version | sed -n '1p')"
if [[ "${SME_PERF_ALLOW_NON_BISHENG_CXX:-0}" != "1" &&
      ! "${compiler_version}" =~ [Bb]i[Ss]heng ]]; then
  die "compiler is not BiSheng: ${compiler_version}; set BISHENG_CXX or SME_PERF_ALLOW_NON_BISHENG_CXX=1"
fi

if [[ -n "${cpu}" ]]; then
  command -v taskset >/dev/null 2>&1 || die "SME_PERF_CPU requires taskset"
fi
if ((timeout_seconds > 0)); then
  command -v timeout >/dev/null 2>&1 || \
    die "SME_PERF_TIMEOUT_SECONDS requires timeout"
fi

mkdir -p "${build_dir}"
mkdir -p "$(dirname "${results_csv}")"

common_flags=(-O3 -std=c++17 -march=armv9-a+sme+sme-f64f64)
if [[ -n "${SME_PERF_CXXFLAGS:-}" ]]; then
  read -r -a extra_flags <<< "${SME_PERF_CXXFLAGS}"
  common_flags+=("${extra_flags[@]}")
fi

link_flags=(--rtlib=compiler-rt -lgcc_s)
if [[ -n "${SME_PERF_LINK_FLAGS:-}" ]]; then
  read -r -a extra_link_flags <<< "${SME_PERF_LINK_FLAGS}"
  link_flags+=("${extra_link_flags[@]}")
fi

printf '== 编译 ==\n'
printf 'compiler: %s\n' "${cxx}"
printf 'compiler version: %s\n' "${compiler_version}"
printf 'cases: %s\n' "${selected_cases[*]}"
printf 'SME ABI link flags: %s\n' "${link_flags[*]}"
"${cxx}" "${common_flags[@]}" "${baseline_source}" \
  "${link_flags[@]}" -o "${baseline_bin}"
"${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO "${paper_source}" \
  "${link_flags[@]}" -o "${paper_bin}"
if [[ "${ablations}" == "1" ]]; then
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_FORCE_ZA "${paper_source}" \
    "${link_flags[@]}" -o "${force_za_bin}"
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_FORCE_ZA -DSMESTENCIL_PAPER_SINGLE_ZA "${paper_source}" \
    "${link_flags[@]}" -o "${single_za_bin}"
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_FORCE_ZA -DSMESTENCIL_PAPER_DISABLE_LOAD_REUSE \
    "${paper_source}" \
    "${link_flags[@]}" -o "${no_reuse_bin}"
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_FORCE_ZA -DSMESTENCIL_PAPER_INDIRECT_ZA_STORE \
    "${paper_source}" "${link_flags[@]}" -o "${indirect_store_bin}"
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_ENABLE_PREFETCH "${paper_source}" \
    "${link_flags[@]}" -o "${prefetch_bin}"
fi

run_binary() {
  local binary="$1"
  local log_file="$2"
  shift 2

  if ((timeout_seconds > 0)); then
    if [[ -n "${cpu}" ]]; then
      timeout "${timeout_seconds}" taskset -c "${cpu}" \
        "${binary}" "$@" >"${log_file}" 2>&1
    else
      timeout "${timeout_seconds}" "${binary}" "$@" >"${log_file}" 2>&1
    fi
  elif [[ -n "${cpu}" ]]; then
    taskset -c "${cpu}" "${binary}" "$@" >"${log_file}" 2>&1
  else
    "${binary}" "$@" >"${log_file}" 2>&1
  fi
}

run_binary_checked() {
  local label="$1"
  local binary="$2"
  local log_file="$3"
  local status
  shift 3

  if run_binary "${binary}" "${log_file}" "$@"; then
    return 0
  else
    status=$?
  fi

  printf 'error: %s failed with exit code %d\n' "${label}" "${status}" >&2
  printf 'log: %s\n' "${log_file}" >&2
  printf '%s\n' '----- program output (first 160 lines) -----' >&2
  sed -n '1,160p' "${log_file}" >&2
  exit "${status}"
}

read_single_time() {
  local log_file="$1"
  local parsed
  parsed="$(awk -F ':' '
    /^Time:/ {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      value = $2
      count++
    }
    END {
      if (count == 1) print value
    }' "${log_file}")"
  if [[ ! "${parsed}" =~ ^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
    printf 'expected exactly one numeric Time: line in %s\n' "${log_file}" >&2
    sed -n '1,160p' "${log_file}" >&2
    exit 1
  fi
  REPLY="${parsed}"
}

sample_file() {
  printf '%s/samples_%s_%s.txt' "${build_dir}" "$1" "$2"
}

append_sample() {
  local variant="$1"
  local test_case="$2"
  local value="$3"
  printf '%s\n' "${value}" >>"$(sample_file "${variant}" "${test_case}")"
}

median_file() {
  LC_ALL=C sort -n "$1" | awk '
    { value[NR] = $1 }
    END {
      if (NR == 0) exit 1
      if (NR % 2) print value[(NR + 1) / 2]
      else print (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

relative_mad_file() {
  local input_file="$1"
  local sample_median="$2"
  awk -v median="${sample_median}" '{
    difference = $1 - median
    if (difference < 0) difference = -difference
    print difference
  }' "${input_file}" | LC_ALL=C sort -n | awk -v median="${sample_median}" '
    { value[NR] = $1 }
    END {
      if (NR == 0 || median <= 0) exit 1
      if (NR % 2) mad = value[(NR + 1) / 2]
      else mad = (value[NR / 2] + value[NR / 2 + 1]) / 2
      printf "%.4f", mad / median
    }'
}

speedup() {
  awk -v baseline="$1" -v paper="$2" 'BEGIN {
    if (paper <= 0) exit 1
    printf "%.4f", baseline / paper
  }'
}

measure_variant() {
  local variant="$1"
  local binary="$2"
  local test_case="$3"
  local run="$4"
  local log_file="${build_dir}/${variant}_${test_case}_run_${run}.log"
  printf 'sample %d/%d: %-9s --%s\n' \
    "${run}" "${repetitions}" "${variant}" "${test_case}"
  run_binary_checked \
    "${variant} ${test_case} sample ${run}" \
    "${binary}" "${log_file}" "--${test_case}"
  read_single_time "${log_file}"
}

for test_case in "${selected_cases[@]}"; do
  : >"$(sample_file baseline "${test_case}")"
  : >"$(sample_file optimized "${test_case}")"
  if [[ "${ablations}" == "1" ]]; then
    : >"$(sample_file pure-za "${test_case}")"
    : >"$(sample_file single-za "${test_case}")"
    : >"$(sample_file no-reuse "${test_case}")"
    : >"$(sample_file indirect-store "${test_case}")"
    : >"$(sample_file prefetch "${test_case}")"
  fi
done

printf '\n== 运行 ==\n'
case_number=0
for test_case in "${selected_cases[@]}"; do
  case_number=$((case_number + 1))
  for ((run = 1; run <= repetitions; ++run)); do
    # 按用例和轮次交替顺序，单轮测试也不会始终固定为“基线先运行”。
    if (((run + case_number) % 2 == 0)); then
      measure_variant baseline "${baseline_bin}" "${test_case}" "${run}"
      append_sample baseline "${test_case}" "${REPLY}"
      measure_variant optimized "${paper_bin}" "${test_case}" "${run}"
      append_sample optimized "${test_case}" "${REPLY}"
    else
      measure_variant optimized "${paper_bin}" "${test_case}" "${run}"
      append_sample optimized "${test_case}" "${REPLY}"
      measure_variant baseline "${baseline_bin}" "${test_case}" "${run}"
      append_sample baseline "${test_case}" "${REPLY}"
    fi

    if [[ "${ablations}" == "1" ]]; then
      measure_variant pure-za "${force_za_bin}" "${test_case}" "${run}"
      append_sample pure-za "${test_case}" "${REPLY}"
      measure_variant single-za "${single_za_bin}" "${test_case}" "${run}"
      append_sample single-za "${test_case}" "${REPLY}"
      measure_variant no-reuse "${no_reuse_bin}" "${test_case}" "${run}"
      append_sample no-reuse "${test_case}" "${REPLY}"
      measure_variant indirect-store "${indirect_store_bin}" "${test_case}" "${run}"
      append_sample indirect-store "${test_case}" "${REPLY}"
      measure_variant prefetch "${prefetch_bin}" "${test_case}" "${run}"
      append_sample prefetch "${test_case}" "${REPLY}"
    fi
  done
done

printf 'case,baseline_median_s,optimized_median_s,speedup,baseline_relative_mad,optimized_relative_mad\n' \
  >"${results_csv}"
printf '\n== 全算子性能结果 ==\n'
printf '每个时间为 100 次 kernel sweep 的中位总时间；加速比 = 原始/优化版。\n'
printf '| 用例 | 原始中位时间/s | 优化版中位时间/s | 加速比 | 原始相对MAD | 优化相对MAD |\n'
printf '|---|---:|---:|---:|---:|---:|\n'
for test_case in "${selected_cases[@]}"; do
  baseline_median="$(median_file "$(sample_file baseline "${test_case}")")"
  optimized_median="$(median_file "$(sample_file optimized "${test_case}")")"
  case_speedup="$(speedup "${baseline_median}" "${optimized_median}")"
  baseline_rmad="$(relative_mad_file \
    "$(sample_file baseline "${test_case}")" "${baseline_median}")"
  optimized_rmad="$(relative_mad_file \
    "$(sample_file optimized "${test_case}")" "${optimized_median}")"
  printf '| %s | %s | %s | %sx | %s | %s |\n' \
    "${test_case}" "${baseline_median}" "${optimized_median}" "${case_speedup}" \
    "${baseline_rmad}" "${optimized_rmad}"
  printf '%s,%s,%s,%s,%s,%s\n' \
    "${test_case}" "${baseline_median}" "${optimized_median}" "${case_speedup}" \
    "${baseline_rmad}" "${optimized_rmad}" \
    >>"${results_csv}"
done

if [[ "${ablations}" == "1" ]]; then
  printf '\n== 消融诊断 ==\n'
  printf '| 用例 | 纯ZA | 单ZA | 无复用 | 间接写回 | 预取候选 |\n'
  printf '|---|---:|---:|---:|---:|---:|\n'
  for test_case in "${selected_cases[@]}"; do
    pure_za_median="$(median_file "$(sample_file pure-za "${test_case}")")"
    single_za_median="$(median_file "$(sample_file single-za "${test_case}")")"
    no_reuse_median="$(median_file "$(sample_file no-reuse "${test_case}")")"
    indirect_median="$(median_file "$(sample_file indirect-store "${test_case}")")"
    prefetch_median="$(median_file "$(sample_file prefetch "${test_case}")")"
    printf '| %s | %s | %s | %s | %s | %s |\n' \
      "${test_case}" "${pure_za_median}" "${single_za_median}" \
      "${no_reuse_median}" "${indirect_median}" "${prefetch_median}"
  done
fi

printf '\nCSV：%s\n' "${results_csv}"
printf '日志与二进制目录：%s\n' "${build_dir}"
printf '提示：论文式程序会先执行小尺寸标量自检；该时间不包含在 Time: 中。\n'
