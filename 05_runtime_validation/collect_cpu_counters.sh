#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"
custom_template="SME Stencil Cache Counters"
if [[ -n "${CPU_COUNTERS_TEMPLATE:-}" ]]; then
  counter_template="${CPU_COUNTERS_TEMPLATE}"
elif xcrun xctrace list templates 2>/dev/null |
    grep -Fxq "${custom_template}"; then
  counter_template="${custom_template}"
else
  counter_template="CPU Counters"
fi

variant="${1:-baseline}"
kernel="${2:-3d}"
if [[ "${variant}" != "baseline" && "${variant}" != "prefetch" ]]; then
  printf 'variant must be baseline or prefetch\n' >&2
  exit 2
fi
if [[ "${kernel}" != "2d" && "${kernel}" != "3d" ]]; then
  printf 'kernel must be 2d or 3d\n' >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcrun >/dev/null; then
  printf 'CPU Counters collection requires macOS and Xcode xctrace\n' >&2
  exit 2
fi
if [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" != "1" &&
      "${FORCE_SME_RUN:-0}" != "1" ]]; then
  printf 'CPU Counters target does not report SME support\n' >&2
  exit 2
fi

binary="${build_dir}/stencil_benchmark.${variant}"
if [[ ! -x "${binary}" ]]; then
  printf 'missing benchmark binary; run run_benchmark.sh first\n' >&2
  exit 2
fi

stamp="$(date +%Y%m%d-%H%M%S)"
capture_dir="${PMU_CAPTURE_DIR:-${output_dir}/pmu_${variant}_${kernel}_${stamp}}"
trace="${capture_dir}/cpu_counters.trace"
mkdir -p "${capture_dir}"

if [[ "${kernel}" == "2d" ]]; then
  arguments=(
    2d
    "${STENCIL_2D_HEIGHT:-16384}"
    "${STENCIL_2D_WIDTH:-1024}"
    "${STENCIL_REPETITIONS:-32}"
    "${STENCIL_SAMPLES:-7}"
  )
else
  arguments=(
    3d
    "${STENCIL_3D_DEPTH:-512}"
    "${STENCIL_3D_HEIGHT:-32}"
    "${STENCIL_3D_WIDTH:-1024}"
    "${STENCIL_REPETITIONS:-32}"
    "${STENCIL_SAMPLES:-7}"
  )
fi

xcrun xctrace record \
  --template "${counter_template}" \
  --output "${trace}" \
  --no-prompt \
  --target-stdout "${capture_dir}/benchmark.log" \
  --launch -- "${binary}" "${arguments[@]}"

xcrun xctrace export \
  --input "${trace}" \
  --toc \
  --output "${capture_dir}/toc.xml"

raw_counter_table=0
if grep -q 'schema="counters-profile"' "${capture_dir}/toc.xml"; then
  raw_counter_table=1
  xcrun xctrace export \
    --input "${trace}" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="counters-profile"]' \
    --output "${capture_dir}/counters_profile.xml"

  target_name="$(basename "${binary}")"
  target_ref="$(
    awk -v target="${target_name}" '
      index($0, "fmt=\"" target " (") {
        value = $0
        sub(/^.*<process id="/, "", value)
        sub(/".*/, "", value)
        print value
        exit
      }
    ' "${capture_dir}/counters_profile.xml"
  )"
  if [[ -z "${target_ref}" ]]; then
    printf 'failed to find target process in counters-profile XML\n' >&2
    exit 1
  fi

  awk -v target="${target_name}" -v target_ref="${target_ref}" '
    function counter_values(line, value, id) {
      if (line ~ /<pmc-events id="/) {
        id = line
        sub(/^.*<pmc-events id="/, "", id)
        sub(/".*/, "", id)
        value = line
        sub(/^.*<pmc-events[^>]*>/, "", value)
        sub(/<\/pmc-events>.*/, "", value)
        pmc[id] = value
        return value
      }
      if (line ~ /<pmc-events ref="/) {
        id = line
        sub(/^.*<pmc-events ref="/, "", id)
        sub(/".*/, "", id)
        return pmc[id]
      }
      return ""
    }

    /<row>/ {
      is_target = index($0, "fmt=\"" target " (") ||
        index($0, "<process ref=\"" target_ref "\"/>")
      value = counter_values($0)
      if (!is_target || value == "")
        next
      count = split(value, counters, / +/)
      if (count != 4)
        next
      for (i = 1; i <= 4; ++i)
        totals[i] += counters[i]
      samples++
    }

    END {
      print "samples=" samples
      printf "ARM_L1D_CACHE_RD=%.0f\n", totals[1]
      printf "ARM_L1D_CACHE_LMISS_RD=%.0f\n", totals[2]
      printf "PL2_CACHE_ACCESS=%.0f\n", totals[3]
      printf "PL2_CACHE_MISS_LD=%.0f\n", totals[4]
    }
  ' "${capture_dir}/counters_profile.xml" \
    > "${capture_dir}/counter_totals.txt"
else
  xcrun xctrace export \
    --input "${trace}" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="CountingModeSamples"]' \
    --output "${capture_dir}/counting_mode_samples.xml"
fi

{
  printf '# Apple M5 CPU Counters 采集\n\n'
  printf -- '- 变体：`%s`\n' "${variant}"
  printf -- '- 算子：`%s`\n' "${kernel}"
  printf -- '- 模板：`%s`\n' "${counter_template}"
  printf -- '- Trace：`cpu_counters.trace`\n'
  printf -- '- 表目录：`toc.xml`\n'
  if [[ "${raw_counter_table}" == "1" ]]; then
    printf -- '- 原始采样表：`counters_profile.xml`\n'
    printf -- '- 目标进程累加值：`counter_totals.txt`\n\n'
    printf '累加值来自 1 ms `counters-profile` 归因样本，不是无采样误差的'
    printf '全程序架构计数。比较时必须保持模板、规模和采样参数一致。\n'
  else
    printf -- '- 模型化采样：`counting_mode_samples.xml`\n\n'
    printf '默认模板主要输出瓶颈分类。若要比较 L1D/PL2，请在 Instruments'
    printf ' 中安装 `%s` 自定义模板。\n' "${custom_template}"
  fi
} > "${capture_dir}/README.md"

printf 'CPU Counters capture: %s\n' "${capture_dir}"
