#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"

runtime_clang="${RUNTIME_CLANG:-/usr/bin/clang}"
runtime_profile="${SME_RUNTIME_PROFILE:-generic-sme}"

mkdir -p "${build_dir}" "${output_dir}"
"${repo_root}/02_llvm_pass_plugin/build_and_test.sh" >/dev/null

kernel_assembly_flags=(
  -O3
  -march=armv9.2-a+nosve+sme
)
host_flags=(-O3)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  kernel_assembly_flags+=(-isysroot "${macos_sdk}")
  host_flags+=(-isysroot "${macos_sdk}")
fi

"${runtime_clang}" "${kernel_assembly_flags[@]}" \
  -c "${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.baseline.s" \
  -o "${build_dir}/stencil_kernels.baseline.o"

prefetch_assembly="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.s"

"${runtime_clang}" "${kernel_assembly_flags[@]}" \
  -c "${prefetch_assembly}" \
  -o "${build_dir}/stencil_kernels.prefetch.o"

"${runtime_clang}" "${host_flags[@]}" \
  -c "${script_dir}/stencil_correctness.c" \
  -o "${build_dir}/stencil_correctness.o"

"${runtime_clang}" "${kernel_assembly_flags[@]}" \
  "${script_dir}/sme_runtime_info.c" \
  -o "${build_dir}/sme_runtime_info"

"${runtime_clang}" "${host_flags[@]}" \
  "${build_dir}/stencil_kernels.baseline.o" \
  "${build_dir}/stencil_correctness.o" \
  -o "${build_dir}/stencil_correctness.baseline"

"${runtime_clang}" "${host_flags[@]}" \
  "${build_dir}/stencil_kernels.prefetch.o" \
  "${build_dir}/stencil_correctness.o" \
  -o "${build_dir}/stencil_correctness.prefetch"

run_enabled=0
if [[ "${FORCE_SME_RUN:-0}" == "1" ]]; then
  run_enabled=1
elif [[ -r /proc/cpuinfo ]] && grep -qiw sme /proc/cpuinfo; then
  run_enabled=1
elif [[ "$(sysctl -n hw.optional.arm.FEAT_SME 2>/dev/null || true)" == "1" ]]; then
  run_enabled=1
fi

if [[ "${run_enabled}" == "1" ]]; then
  "${build_dir}/sme_runtime_info" \
    > "${output_dir}/runtime_info.log"
  actual_streaming_vl="$(sed -n \
    's/^streaming_vl_bytes=//p' "${output_dir}/runtime_info.log")"
  if [[ -z "${actual_streaming_vl}" ]]; then
    printf 'failed to read streaming VL\n' >&2
    exit 1
  fi
  "${build_dir}/stencil_correctness.baseline" \
    > "${output_dir}/baseline_run.log"
  "${build_dir}/stencil_correctness.prefetch" \
    > "${output_dir}/prefetch_run.log"
  result="PASS"
  detail="baseline and prefetch binaries passed all 2D/3D cases"
else
  result="BUILD_ONLY"
  detail="host has no detected SME execution support; run on SME hardware"
  actual_streaming_vl="not-executed"
fi

{
  runtime_clang_version="$("${runtime_clang}" --version | sed -n '1p')"
  printf '# 步骤 5 数值正确性状态\n\n'
  printf -- '- 状态：**%s**\n' "${result}"
  printf -- '- 说明：%s\n' "${detail}"
  printf -- '- 运行平台：`%s %s`\n' \
    "$(uname -s)" "$(uname -m)"
  printf -- '- 运行编译器：`%s`\n' "${runtime_clang_version}"
  printf -- '- 实际 streaming VL：`%s` B\n' "${actual_streaming_vl}"
  printf -- '- 预取 Profile：`%s`\n' "${runtime_profile}"
  printf -- '- 基线 kernel：步骤 4 同输入/同优化管线生成的无插件汇编\n'
  printf -- '- 预取 kernel：`%s`\n' "$(basename "${prefetch_assembly}")"
  printf -- '- 基线二进制：`../build/stencil_correctness.baseline`\n'
  printf -- '- 预取二进制：`../build/stencil_correctness.prefetch`\n\n'
  printf '测试覆盖 2D/3D 空内部区域、最小合法尺寸、非规则宽度、尾部和'
  printf '首尾 guard page。'
  printf '在 SME 机器上运行时，两个二进制都必须与标量参考逐元素一致。\n'
} > "${output_dir}/correctness_report.md"

printf 'Report: %s\n' "${output_dir}/correctness_report.md"
