#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"
counter_template="${CPU_COUNTERS_TEMPLATE:-CPU Counters}"

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
capture_dir="${output_dir}/pmu_${variant}_${kernel}_${stamp}"
trace="${capture_dir}/cpu_counters.trace"
mkdir -p "${capture_dir}"

if [[ "${kernel}" == "2d" ]]; then
  arguments=(2d 16384 1024 32 7)
else
  arguments=(3d 512 32 1024 32 7)
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

xcrun xctrace export \
  --input "${trace}" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="CountingModeSamples"]' \
  --output "${capture_dir}/counting_mode_samples.xml"

{
  printf '# Apple M5 CPU Counters 采集\n\n'
  printf -- '- 变体：`%s`\n' "${variant}"
  printf -- '- 算子：`%s`\n' "${kernel}"
  printf -- '- 模板：`%s`\n' "${counter_template}"
  printf -- '- Trace：`cpu_counters.trace`\n'
  printf -- '- 表目录：`toc.xml`\n'
  printf -- '- 模型化采样：`counting_mode_samples.xml`\n\n'
  printf 'Xcode 默认 CPU Counters 模板主要输出瓶颈分类采样。若需要 L1D/L2'
  printf ' miss 原始事件数，应在 Instruments 中配置事件并保存自定义模板，'
  printf '再通过 `CPU_COUNTERS_TEMPLATE=/path/to/template.tracetemplate` 使用。\n'
} > "${capture_dir}/README.md"

printf 'CPU Counters capture: %s\n' "${capture_dir}"
