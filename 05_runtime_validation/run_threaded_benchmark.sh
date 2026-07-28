#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"
runtime_clang="${RUNTIME_CLANG:-/usr/bin/clang}"

"${repo_root}/02_llvm_pass_plugin/build_and_test.sh" >/dev/null

run_enabled=0
if [[ "${FORCE_SME_RUN:-0}" == "1" ]]; then
  run_enabled=1
elif [[ -r /proc/cpuinfo ]] && grep -qiw sme /proc/cpuinfo; then
  run_enabled=1
elif [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" == "1" ]]; then
  run_enabled=1
fi
if [[ "${run_enabled}" != "1" ]]; then
  printf 'Threaded benchmark requires detected SME support.\n'
  exit 0
fi

baseline_source="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.baseline.s"
prefetch_source="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.s"
baseline_renamed="${build_dir}/stencil_kernels.threaded-baseline.s"
prefetch_renamed="${build_dir}/stencil_kernels.threaded-prefetch.s"

sed \
  -e 's/stencil_2d5p_sme_f32/baseline_stencil_2d5p_sme_f32/g' \
  -e 's/stencil_3d7p_sme_f32/baseline_stencil_3d7p_sme_f32/g' \
  "${baseline_source}" > "${baseline_renamed}"
sed \
  -e 's/stencil_2d5p_sme_f32/prefetch_stencil_2d5p_sme_f32/g' \
  -e 's/stencil_3d7p_sme_f32/prefetch_stencil_3d7p_sme_f32/g' \
  "${prefetch_source}" > "${prefetch_renamed}"

assembly_flags=(-O3 -march=armv9.2-a+nosve+sme+sme-f64f64)
host_flags=(-O3 -pthread)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  assembly_flags+=(-isysroot "${macos_sdk}")
  host_flags+=(-isysroot "${macos_sdk}")
fi

"${runtime_clang}" "${assembly_flags[@]}" -c "${baseline_renamed}" \
  -o "${build_dir}/stencil_kernels.threaded-baseline.o"
"${runtime_clang}" "${assembly_flags[@]}" -c "${prefetch_renamed}" \
  -o "${build_dir}/stencil_kernels.threaded-prefetch.o"
"${runtime_clang}" "${host_flags[@]}" \
  -c "${script_dir}/stencil_threaded_benchmark.c" \
  -o "${build_dir}/stencil_threaded_benchmark.o"
"${runtime_clang}" "${host_flags[@]}" \
  "${build_dir}/stencil_kernels.threaded-baseline.o" \
  "${build_dir}/stencil_kernels.threaded-prefetch.o" \
  "${build_dir}/stencil_threaded_benchmark.o" \
  -o "${build_dir}/stencil_threaded_benchmark"

depth="${STENCIL_3D_DEPTH:-256}"
height="${STENCIL_3D_HEIGHT:-32}"
width="${STENCIL_3D_WIDTH:-1024}"
repetitions="${STENCIL_REPETITIONS:-8}"
samples="${STENCIL_SAMPLES:-9}"
rounds="${STENCIL_ROUNDS:-3}"
thread_counts="${STENCIL_THREAD_COUNTS:-1 2 4 8}"

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

median() {
  printf '%s\n' "$@" | sort -n |
    awk '{ values[NR] = $1 } END { print values[int((NR + 1) / 2)] }'
}

range() {
  printf '%s\n' "$@" | sort -n |
    awk 'NR == 1 { minimum = $1 } { maximum = $1 }
         END { printf "%s-%s", minimum, maximum }'
}

report="${output_dir}/threaded_benchmark_report.md"
{
  printf '# 3D7P 多线程配对结果\n\n'
  printf -- '- Profile：`%s`\n' "${SME_RUNTIME_PROFILE:-generic-sme}"
  printf -- '- 每线程独立网格：`%sx%sx%s`\n' \
    "${depth}" "${height}" "${width}"
  printf -- '- 每轮重复/样本/外层轮数：`%s / %s / %s`\n' \
    "${repetitions}" "${samples}" "${rounds}"
  printf -- '- 方法：每个线程处理独立输入输出域；同一进程交替执行基线/预取\n\n'
  printf '| 线程数 | 基线 GUP/s | 预取 GUP/s | 配对加速比 | 轮间范围 |\n'
  printf '|---:|---:|---:|---:|---:|\n'
} > "${report}"

for threads in ${thread_counts}; do
  baseline_gups=()
  prefetch_gups=()
  speedups=()
  for ((round = 1; round <= rounds; ++round)); do
    log="${output_dir}/threaded_3d_t${threads}_round_${round}.log"
    "${build_dir}/stencil_threaded_benchmark" \
      "${threads}" "${depth}" "${height}" "${width}" \
      "${repetitions}" "${samples}" > "${log}"
    baseline_checksum="$(field baseline_checksum "${log}")"
    prefetch_checksum="$(field prefetch_checksum "${log}")"
    if [[ "${baseline_checksum}" != "${prefetch_checksum}" ]]; then
      printf 'threaded checksum mismatch: threads=%s round=%s\n' \
        "${threads}" "${round}" >&2
      exit 1
    fi
    baseline_gups+=("$(field baseline_gups "${log}")")
    prefetch_gups+=("$(field prefetch_gups "${log}")")
    speedups+=("$(field paired_speedup "${log}")")
  done
  printf '| %s | %s | %s | %s | %s |\n' \
    "${threads}" "$(median "${baseline_gups[@]}")" \
    "$(median "${prefetch_gups[@]}")" "$(median "${speedups[@]}")" \
    "$(range "${speedups[@]}")" >> "${report}"
done

{
  printf '\n该测试用独立网格制造共享缓存和内存带宽竞争，不包含域分解通信。'
  printf '它回答的是额外 PRFM 流量的并发扩展性，不代表完整并行 stencil'
  printf ' 应用的最终性能。\n'
} >> "${report}"

cat "${report}"
