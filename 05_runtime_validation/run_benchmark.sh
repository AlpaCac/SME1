#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"
runtime_clang="${RUNTIME_CLANG:-/usr/bin/clang}"
runtime_profile="${SME_RUNTIME_PROFILE:-generic-sme}"

FORCE_SME_RUN="${FORCE_SME_RUN:-0}" \
  "${script_dir}/build_and_run.sh" >/dev/null

host_flags=(-O3)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  host_flags+=(-isysroot "${macos_sdk}")
fi

"${runtime_clang}" "${host_flags[@]}" \
  -c "${script_dir}/stencil_benchmark.c" \
  -o "${build_dir}/stencil_benchmark.o"

for variant in baseline prefetch; do
  "${runtime_clang}" "${host_flags[@]}" \
    "${build_dir}/stencil_kernels.${variant}.o" \
    "${build_dir}/stencil_benchmark.o" \
    -o "${build_dir}/stencil_benchmark.${variant}"
done

run_enabled=0
if [[ "${FORCE_SME_RUN:-0}" == "1" ]]; then
  run_enabled=1
elif [[ -r /proc/cpuinfo ]] && grep -qiw sme /proc/cpuinfo; then
  run_enabled=1
elif [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" == "1" ]]; then
  run_enabled=1
fi

if [[ "${run_enabled}" != "1" ]]; then
  printf 'Benchmark binaries built; SME execution was not enabled.\n'
  exit 0
fi
if [[ "${STENCIL_BUILD_ONLY:-0}" == "1" ]]; then
  printf 'Benchmark binaries built.\n'
  exit 0
fi

height_2d="${STENCIL_2D_HEIGHT:-16384}"
width_2d="${STENCIL_2D_WIDTH:-1024}"
depth_3d="${STENCIL_3D_DEPTH:-512}"
height_3d="${STENCIL_3D_HEIGHT:-32}"
width_3d="${STENCIL_3D_WIDTH:-1024}"
repetitions="${STENCIL_REPETITIONS:-8}"
samples="${STENCIL_SAMPLES:-7}"

for variant in baseline prefetch; do
  "${build_dir}/stencil_benchmark.${variant}" \
    2d "${height_2d}" "${width_2d}" "${repetitions}" "${samples}" \
    > "${output_dir}/benchmark_2d_${variant}.log"
  "${build_dir}/stencil_benchmark.${variant}" \
    3d "${depth_3d}" "${height_3d}" "${width_3d}" \
    "${repetitions}" "${samples}" \
    > "${output_dir}/benchmark_3d_${variant}.log"
done

field() {
  key="$1"
  file="$2"
  awk '{
    for (i = 1; i <= NF; ++i) {
      split($i, pair, "=")
      if (pair[1] == key) {
        print pair[2]
        exit
      }
    }
  }' key="${key}" "${file}"
}

gups_2d_baseline="$(field gupdates_per_second \
  "${output_dir}/benchmark_2d_baseline.log")"
gups_2d_prefetch="$(field gupdates_per_second \
  "${output_dir}/benchmark_2d_prefetch.log")"
gups_3d_baseline="$(field gupdates_per_second \
  "${output_dir}/benchmark_3d_baseline.log")"
gups_3d_prefetch="$(field gupdates_per_second \
  "${output_dir}/benchmark_3d_prefetch.log")"
checksum_2d_baseline="$(field checksum \
  "${output_dir}/benchmark_2d_baseline.log")"
checksum_2d_prefetch="$(field checksum \
  "${output_dir}/benchmark_2d_prefetch.log")"
checksum_3d_baseline="$(field checksum \
  "${output_dir}/benchmark_3d_baseline.log")"
checksum_3d_prefetch="$(field checksum \
  "${output_dir}/benchmark_3d_prefetch.log")"

if [[ "${checksum_2d_baseline}" != "${checksum_2d_prefetch}" ||
      "${checksum_3d_baseline}" != "${checksum_3d_prefetch}" ]]; then
  printf 'benchmark checksum mismatch between baseline and prefetch\n' >&2
  exit 1
fi

speedup_2d="$(awk -v p="${gups_2d_prefetch}" -v b="${gups_2d_baseline}" \
  'BEGIN { printf "%.4f", p / b }')"
speedup_3d="$(awk -v p="${gups_3d_prefetch}" -v b="${gups_3d_baseline}" \
  'BEGIN { printf "%.4f", p / b }')"

{
  printf '# 步骤 5 初始性能结果\n\n'
  printf -- '- 平台：`%s %s`\n' \
    "$(uname -s)" "$(uname -m)"
  printf -- '- 预取 Profile：`%s`\n' "${runtime_profile}"
  printf -- '- 重复次数/样本数：`%s / %s`，报告样本中位数\n' \
    "${repetitions}" "${samples}"
  printf -- '- 可比性：基线/预取来自同一 kernel-only LLVM IR 与 `-O1` 管线，'
  printf '仅 pass 开关不同\n'
  printf -- '- 正确性：基线与预取 checksum 一致\n'
  printf -- '- 2D 规模：`%sx%s`，基线 `%s` GUP/s，预取 `%s` GUP/s，加速比 `%sx`\n' \
    "${height_2d}" "${width_2d}" "${gups_2d_baseline}" \
    "${gups_2d_prefetch}" "${speedup_2d}"
  printf -- '- 3D 规模：`%sx%sx%s`，基线 `%s` GUP/s，预取 `%s` GUP/s，加速比 `%sx`\n\n' \
    "${depth_3d}" "${height_3d}" "${width_3d}" "${gups_3d_baseline}" \
    "${gups_3d_prefetch}" "${speedup_3d}"
  printf '该结果用于建立基线，不足以单独确定最终 Profile。后续需增加冷热规模、'
  printf '距离/层级/策略消融和 PMU 计数。\n'
} > "${output_dir}/benchmark_report.md"

cat "${output_dir}/benchmark_report.md"
