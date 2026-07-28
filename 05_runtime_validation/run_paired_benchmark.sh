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

run_enabled=0
if [[ "${FORCE_SME_RUN:-0}" == "1" ]]; then
  run_enabled=1
elif [[ -r /proc/cpuinfo ]] && grep -qiw sme /proc/cpuinfo; then
  run_enabled=1
elif [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" == "1" ]]; then
  run_enabled=1
fi
if [[ "${run_enabled}" != "1" ]]; then
  printf 'Paired benchmark requires detected SME support.\n'
  exit 0
fi

baseline_source="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.baseline.s"
prefetch_source="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.s"
baseline_renamed="${build_dir}/stencil_kernels.baseline-renamed.s"
prefetch_renamed="${build_dir}/stencil_kernels.prefetch-renamed.s"

sed \
  -e 's/stencil_2d5p_sme_f32/baseline_stencil_2d5p_sme_f32/g' \
  -e 's/stencil_3d7p_sme_f32/baseline_stencil_3d7p_sme_f32/g' \
  "${baseline_source}" > "${baseline_renamed}"
sed \
  -e 's/stencil_2d5p_sme_f32/prefetch_stencil_2d5p_sme_f32/g' \
  -e 's/stencil_3d7p_sme_f32/prefetch_stencil_3d7p_sme_f32/g' \
  "${prefetch_source}" > "${prefetch_renamed}"

assembly_flags=(-O3 -march=armv9.2-a+nosve+sme+sme-f64f64)
host_flags=(-O3)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  assembly_flags+=(-isysroot "${macos_sdk}")
  host_flags+=(-isysroot "${macos_sdk}")
fi

"${runtime_clang}" "${assembly_flags[@]}" \
  -c "${baseline_renamed}" \
  -o "${build_dir}/stencil_kernels.baseline-renamed.o"
"${runtime_clang}" "${assembly_flags[@]}" \
  -c "${prefetch_renamed}" \
  -o "${build_dir}/stencil_kernels.prefetch-renamed.o"
"${runtime_clang}" "${host_flags[@]}" \
  -c "${script_dir}/stencil_paired_benchmark.c" \
  -o "${build_dir}/stencil_paired_benchmark.o"
"${runtime_clang}" "${host_flags[@]}" \
  "${build_dir}/stencil_kernels.baseline-renamed.o" \
  "${build_dir}/stencil_kernels.prefetch-renamed.o" \
  "${build_dir}/stencil_paired_benchmark.o" \
  -o "${build_dir}/stencil_paired_benchmark"

height_2d="${STENCIL_2D_HEIGHT:-16384}"
width_2d="${STENCIL_2D_WIDTH:-1024}"
depth_3d="${STENCIL_3D_DEPTH:-512}"
height_3d="${STENCIL_3D_HEIGHT:-32}"
width_3d="${STENCIL_3D_WIDTH:-1024}"
repetitions="${STENCIL_REPETITIONS:-8}"
samples="${STENCIL_SAMPLES:-9}"
rounds="${STENCIL_ROUNDS:-3}"

if [[ "${rounds}" -eq 0 ]]; then
  printf 'STENCIL_ROUNDS must be positive\n' >&2
  exit 2
fi

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

speedups_2d=()
speedups_3d=()
for ((round = 1; round <= rounds; ++round)); do
  log_2d="${output_dir}/paired_2d_round_${round}.log"
  log_3d="${output_dir}/paired_3d_round_${round}.log"
  "${build_dir}/stencil_paired_benchmark" \
    2d "${height_2d}" "${width_2d}" "${repetitions}" "${samples}" \
    > "${log_2d}"
  "${build_dir}/stencil_paired_benchmark" \
    3d "${depth_3d}" "${height_3d}" "${width_3d}" \
    "${repetitions}" "${samples}" \
    > "${log_3d}"

  baseline_checksum_2d="$(field baseline_checksum "${log_2d}")"
  prefetch_checksum_2d="$(field prefetch_checksum "${log_2d}")"
  baseline_checksum_3d="$(field baseline_checksum "${log_3d}")"
  prefetch_checksum_3d="$(field prefetch_checksum "${log_3d}")"
  if [[ "${baseline_checksum_2d}" != "${prefetch_checksum_2d}" ||
        "${baseline_checksum_3d}" != "${prefetch_checksum_3d}" ]]; then
    printf 'paired benchmark checksum mismatch in round %s\n' "${round}" >&2
    exit 1
  fi
  speedups_2d+=("$(field paired_speedup "${log_2d}")")
  speedups_3d+=("$(field paired_speedup "${log_3d}")")
done

median() {
  printf '%s\n' "$@" | sort -n | \
    awk '{ values[NR] = $1 } END { print values[int((NR + 1) / 2)] }'
}

range() {
  printf '%s\n' "$@" | sort -n | \
    awk 'NR == 1 { minimum = $1 } { maximum = $1 }
         END { printf "%s-%s", minimum, maximum }'
}

median_2d="$(median "${speedups_2d[@]}")"
median_3d="$(median "${speedups_3d[@]}")"
range_2d="$(range "${speedups_2d[@]}")"
range_3d="$(range "${speedups_3d[@]}")"

{
  printf '# 步骤 5 同进程配对性能结果\n\n'
  printf -- '- 平台：`%s %s`\n' \
    "$(uname -s)" "$(uname -m)"
  printf -- '- 方法：同一进程链接基线/预取函数，奇偶样本交换执行顺序\n'
  printf -- '- 预取 Profile：`%s`\n' "${runtime_profile}"
  printf -- '- 重复次数/样本数/外层轮数：`%s / %s / %s`\n' \
    "${repetitions}" "${samples}" "${rounds}"
  printf -- '- 2D 配对加速比：中位数 `%sx`，轮间范围 `%sx`\n' \
    "${median_2d}" "${range_2d}"
  printf -- '- 3D 配对加速比：中位数 `%sx`，轮间范围 `%sx`\n' \
    "${median_3d}" "${range_3d}"
  printf -- '- 正确性：两组 checksum 均一致\n\n'
  printf '配对加速比是每对样本 `baseline_time / prefetch_time` 的中位数，'
  printf '比独立进程中位数更能抑制启动、温度和调度漂移。\n'
} > "${output_dir}/paired_benchmark_report.md"

cat "${output_dir}/paired_benchmark_report.md"
