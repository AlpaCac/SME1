#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"
llvm_clang="${LLVM_CLANG:-$(command -v clang)}"
runtime_clang="${RUNTIME_CLANG:-${llvm_clang}}"
plugin="${repo_root}/02_llvm_pass_plugin/build/StencilPrefetchPass.so"
if [[ ! -f "${plugin}" ]]; then plugin="${repo_root}/02_llvm_pass_plugin/build/StencilPrefetchPass.dylib"; fi
kernel_ir="${STENCIL_KERNEL_IR:-${repo_root}/01_llvm_ir_analysis/output/stencil_all_sme.kernels.ll}"

FORCE_SME_RUN="${FORCE_SME_RUN:-0}" \
  "${script_dir}/run_benchmark.sh" >/dev/null

run_enabled=0
if [[ "${FORCE_SME_RUN:-0}" == "1" ]]; then
  run_enabled=1
elif [[ -r /proc/cpuinfo ]] && grep -qiw sme /proc/cpuinfo; then
  run_enabled=1
elif [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" == "1" ]]; then
  run_enabled=1
fi
if [[ "${run_enabled}" != "1" ]]; then
  printf 'Ablation benchmark requires detected SME support.\n'
  exit 0
fi

assembly_flags=(-O3 -march=armv9.2-a+nosve+sme)
host_flags=(-O3)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  assembly_flags+=(-isysroot "${macos_sdk}")
  host_flags+=(-isysroot "${macos_sdk}")
fi

generate_variant() {
  name="$1"
  shift
  variant_ir="${build_dir}/stencil_kernels.${name}.ll"
  variant_assembly="${build_dir}/stencil_kernels.${name}.s"
  variant_object="${build_dir}/stencil_kernels.${name}.o"

  env "$@" "${llvm_clang}" \
    -x ir -O1 -S -emit-llvm -Wno-override-module \
    -fpass-plugin="${plugin}" \
    "${kernel_ir}" \
    -o "${variant_ir}" \
    2> "${output_dir}/ablation_${name}_profile.log"
  "${llvm_clang}" \
    -x ir -O1 -S -Wno-override-module \
    "${variant_ir}" \
    -o "${variant_assembly}"
  "${runtime_clang}" "${assembly_flags[@]}" \
    -c "${variant_assembly}" \
    -o "${variant_object}"
  "${runtime_clang}" "${host_flags[@]}" \
    "${variant_object}" "${build_dir}/stencil_benchmark.o" \
    -o "${build_dir}/stencil_benchmark.${name}"
}

generate_variant no_row SME_PREFETCH_ENABLE_ROW_L1=0
generate_variant no_plane_l1 SME_PREFETCH_ENABLE_PLANE_L1=0
generate_variant no_plane_l2 SME_PREFETCH_ENABLE_PLANE_L2=0
generate_variant row_only \
  SME_PREFETCH_ENABLE_PLANE_L1=0 \
  SME_PREFETCH_ENABLE_PLANE_L2=0
generate_variant plane_l1_only \
  SME_PREFETCH_ENABLE_ROW_L1=0 \
  SME_PREFETCH_ENABLE_PLANE_L2=0
generate_variant plane_l2_only \
  SME_PREFETCH_ENABLE_ROW_L1=0 \
  SME_PREFETCH_ENABLE_PLANE_L1=0

height_2d="${STENCIL_2D_HEIGHT:-16384}"
width_2d="${STENCIL_2D_WIDTH:-1024}"
depth_3d="${STENCIL_3D_DEPTH:-512}"
height_3d="${STENCIL_3D_HEIGHT:-32}"
width_3d="${STENCIL_3D_WIDTH:-1024}"
repetitions="${STENCIL_REPETITIONS:-8}"
samples="${STENCIL_SAMPLES:-7}"

"${build_dir}/stencil_benchmark.no_row" \
  2d "${height_2d}" "${width_2d}" "${repetitions}" "${samples}" \
  > "${output_dir}/ablation_2d_no_row.log"

variants=(no_row no_plane_l1 no_plane_l2 row_only plane_l1_only plane_l2_only)
for variant in "${variants[@]}"; do
  "${build_dir}/stencil_benchmark.${variant}" \
    3d "${depth_3d}" "${height_3d}" "${width_3d}" \
    "${repetitions}" "${samples}" \
    > "${output_dir}/ablation_3d_${variant}.log"
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

baseline_2d="$(field gupdates_per_second \
  "${output_dir}/benchmark_2d_baseline.log")"
default_2d="$(field gupdates_per_second \
  "${output_dir}/benchmark_2d_prefetch.log")"
no_row_2d="$(field gupdates_per_second \
  "${output_dir}/ablation_2d_no_row.log")"
baseline_3d="$(field gupdates_per_second \
  "${output_dir}/benchmark_3d_baseline.log")"
default_3d="$(field gupdates_per_second \
  "${output_dir}/benchmark_3d_prefetch.log")"
checksum_2d="$(field checksum "${output_dir}/benchmark_2d_baseline.log")"
checksum_3d="$(field checksum "${output_dir}/benchmark_3d_baseline.log")"
checksum_2d_no_row="$(field checksum \
  "${output_dir}/ablation_2d_no_row.log")"

if [[ "${checksum_2d_no_row}" != "${checksum_2d}" ]]; then
  printf '2D ablation checksum mismatch\n' >&2
  exit 1
fi
for variant in "${variants[@]}"; do
  variant_checksum="$(field checksum \
    "${output_dir}/ablation_3d_${variant}.log")"
  if [[ "${variant_checksum}" != "${checksum_3d}" ]]; then
    printf '3D ablation checksum mismatch: %s\n' "${variant}" >&2
    exit 1
  fi
done

speedup() {
  awk -v value="$1" -v baseline="$2" \
    'BEGIN { printf "%.4f", value / baseline }'
}

{
  printf '# 步骤 5 预取类别消融\n\n'
  printf -- '- 平台：`%s %s`\n' \
    "$(uname -s)" "$(uname -m)"
  printf -- '- 可比性：同一 kernel-only LLVM IR、`-O1` 管线、问题规模和样本数\n'
  printf -- '- 2D 规模：`%sx%s`\n' "${height_2d}" "${width_2d}"
  printf -- '- 3D 规模：`%sx%sx%s`\n\n' \
    "${depth_3d}" "${height_3d}" "${width_3d}"
  printf -- '- 正确性：所有变体 checksum 与无预取基线一致\n\n'
  printf '## 2D5P\n\n'
  printf '| 配置 | GUP/s | 相对基线 |\n'
  printf '|---|---:|---:|\n'
  printf '| 无预取 | %s | 1.0000x |\n' "${baseline_2d}"
  printf '| row L1 KEEP（默认） | %s | %sx |\n' \
    "${default_2d}" "$(speedup "${default_2d}" "${baseline_2d}")"
  printf '| 关闭 row | %s | %sx |\n\n' \
    "${no_row_2d}" "$(speedup "${no_row_2d}" "${baseline_2d}")"
  printf '## 3D7P\n\n'
  printf '| 配置 | GUP/s | 相对基线 |\n'
  printf '|---|---:|---:|\n'
  printf '| 无预取 | %s | 1.0000x |\n' "${baseline_3d}"
  printf '| 全部默认类别 | %s | %sx |\n' \
    "${default_3d}" "$(speedup "${default_3d}" "${baseline_3d}")"
  for variant in "${variants[@]}"; do
    value="$(field gupdates_per_second \
      "${output_dir}/ablation_3d_${variant}.log")"
    printf '| `%s` | %s | %sx |\n' \
      "${variant}" "${value}" "$(speedup "${value}" "${baseline_3d}")"
  done
  printf '\n`no_row` 的 2D 代码不插入预取，其相对基线偏差可用于估计'
  printf '跨进程测量噪声。消融结果仍需跨规模复测并结合 PMU，不能直接'
  printf '固化为最终 Profile。\n'
} > "${output_dir}/ablation_report.md"

cat "${output_dir}/ablation_report.md"
