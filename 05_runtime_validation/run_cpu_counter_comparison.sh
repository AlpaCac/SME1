#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${script_dir}/output"
template="${CPU_COUNTERS_TEMPLATE:-SME Stencil Cache Counters}"
kernel="${1:-3d}"
rounds="${PMU_ROUNDS:-3}"
reuse_captures="${PMU_REUSE_CAPTURES:-0}"

if [[ "${kernel}" != "2d" && "${kernel}" != "3d" ]]; then
  printf 'kernel must be 2d or 3d\n' >&2
  exit 2
fi
if [[ "${rounds}" -le 0 ]]; then
  printf 'PMU_ROUNDS must be positive\n' >&2
  exit 2
fi
if ! xcrun xctrace list templates 2>/dev/null |
    grep -Fxq "${template}"; then
  printf 'missing Instruments template: %s\n' "${template}" >&2
  exit 2
fi

SME_RUNTIME_PROFILE=apple-m5 \
FORCE_SME_RUN=1 \
STENCIL_BUILD_ONLY=1 \
  "${script_dir}/run_benchmark.sh" >/dev/null

events=(
  ARM_L1D_CACHE_RD
  ARM_L1D_CACHE_LMISS_RD
  PL2_CACHE_ACCESS
  PL2_CACHE_MISS_LD
)

value() {
  key="$1"
  file="$2"
  awk -F= -v key="${key}" '$1 == key { print $2; exit }' "${file}"
}

median() {
  printf '%s\n' "$@" | sort -n |
    awk '{ values[NR] = $1 } END { print values[int((NR + 1) / 2)] }'
}

range() {
  printf '%s\n' "$@" | sort -n |
    awk 'NR == 1 { minimum = $1 } { maximum = $1 }
         END { printf "%s-%s", minimum, maximum }'
}

ratio() {
  awk -v p="$1" -v b="$2" \
    'BEGIN { if (b == 0) print "n/a"; else printf "%.4f", p / b }'
}

sample_baseline_values=()
sample_prefetch_values=()
declare -a baseline_values
declare -a prefetch_values
for ((round = 1; round <= rounds; ++round)); do
  if ((round % 2 == 1)); then
    order=(baseline prefetch)
  else
    order=(prefetch baseline)
  fi
  for variant in "${order[@]}"; do
    capture_dir="${output_dir}/pmu_compare_${kernel}_round_${round}_${variant}"
    if [[ "${reuse_captures}" == "1" &&
          -f "${capture_dir}/counter_totals.txt" ]]; then
      continue
    fi
    PMU_CAPTURE_DIR="${capture_dir}" \
    CPU_COUNTERS_TEMPLATE="${template}" \
    FORCE_SME_RUN=1 \
      "${script_dir}/collect_cpu_counters.sh" \
      "${variant}" "${kernel}" >/dev/null
  done

  baseline_file="${output_dir}/pmu_compare_${kernel}_round_${round}_baseline/counter_totals.txt"
  prefetch_file="${output_dir}/pmu_compare_${kernel}_round_${round}_prefetch/counter_totals.txt"
  sample_baseline_values+=("$(value samples "${baseline_file}")")
  sample_prefetch_values+=("$(value samples "${prefetch_file}")")
  for index in "${!events[@]}"; do
    event="${events[index]}"
    baseline_values[index]+=" $(value "${event}" "${baseline_file}")"
    prefetch_values[index]+=" $(value "${event}" "${prefetch_file}")"
  done
done

report="${output_dir}/pmu_comparison_report.md"
{
  printf '# Apple M5 原始缓存事件对比\n\n'
  printf -- '- 算子：`%s`\n' "${kernel}"
  printf -- '- 编译 Profile：`apple-m5`\n'
  printf -- '- Instruments 模板：`%s`\n' "${template}"
  printf -- '- 外层轮数：`%s`，奇偶轮交换基线/预取采集顺序\n' "${rounds}"
  printf -- '- 采样：`counters-profile`，1 ms；下表为目标进程每轮累加值的中位数\n'
  printf -- '- 有效目标进程样本数中位数：基线 `%s`，预取 `%s`\n\n' \
    "$(median "${sample_baseline_values[@]}")" \
    "$(median "${sample_prefetch_values[@]}")"
  printf '| 事件 | 基线中位数 | 预取中位数 | 中位数比值 | 逐轮比值范围 |\n'
  printf '|---|---:|---:|---:|---:|\n'
  for index in "${!events[@]}"; do
    event="${events[index]}"
    read -r -a baseline_rounds <<< "${baseline_values[index]}"
    read -r -a prefetch_rounds <<< "${prefetch_values[index]}"
    baseline_median="$(median "${baseline_rounds[@]}")"
    prefetch_median="$(median "${prefetch_rounds[@]}")"
    median_ratio="$(ratio "${prefetch_median}" "${baseline_median}")"
    round_ratios=()
    for round_index in "${!baseline_rounds[@]}"; do
      round_ratios+=("$(
        ratio "${prefetch_rounds[round_index]}" \
          "${baseline_rounds[round_index]}"
      )")
    done
    printf '| `%s` | %s | %s | %s | %s |\n' \
      "${event}" "${baseline_median}" "${prefetch_median}" \
      "${median_ratio}" "$(range "${round_ratios[@]}")"
  done
  printf '\n当前结果中，PL2 请求增长方向在各轮一致；L1D 事件波动更大，'
  printf '不能仅凭三轮中位数断言 miss 已稳定下降。'
  printf '这些值是 Instruments 对目标线程的归因采样增量，受 1 ms 采样、'
  printf '线程迁核和 PMU 复用影响，适合做同模板相对归因，不应解释为精确的'
  printf '全程序事件总数。必须结合配对墙钟结果判断预取是否有效。\n'
} > "${report}"

cat "${report}"
