#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
workspace_root="$(cd "${repo_root}/.." && pwd)"
build_dir="${script_dir}/build"
output_dir="${script_dir}/output"

default_llvm_config="${workspace_root}/external/Polygeist/build/bin/llvm-config"
default_cmake="${workspace_root}/toolchains/CMake.app/Contents/bin/cmake"
default_ninja="${workspace_root}/downloads/ninja"

llvm_config="${LLVM_CONFIG:-${default_llvm_config}}"
cmake_bin="${CMAKE:-${default_cmake}}"
ninja_bin="${NINJA:-${default_ninja}}"

for tool in "${llvm_config}" "${cmake_bin}" "${ninja_bin}"; do
  if [[ ! -x "${tool}" ]]; then
    printf 'missing required tool: %s\n' "${tool}" >&2
    exit 1
  fi
done

llvm_dir="$("${llvm_config}" --cmakedir)"
llvm_bindir="$("${llvm_config}" --bindir)"
plugin_cc="${PLUGIN_CC:-/usr/bin/clang}"
plugin_cxx="${PLUGIN_CXX:-/usr/bin/clang++}"
llvm_clang="${LLVM_CLANG:-${llvm_bindir}/clang}"

mkdir -p "${build_dir}" "${output_dir}"

"${cmake_bin}" \
  -S "${script_dir}" \
  -B "${build_dir}" \
  -G Ninja \
  -DLLVM_DIR="${llvm_dir}" \
  -DCMAKE_MAKE_PROGRAM="${ninja_bin}" \
  -DCMAKE_C_COMPILER="${plugin_cc}" \
  -DCMAKE_CXX_COMPILER="${plugin_cxx}" \
  -DCMAKE_BUILD_TYPE=Release

"${cmake_bin}" --build "${build_dir}"

plugin="${build_dir}/StencilPrefetchPass.dylib"
if [[ ! -f "${plugin}" ]]; then
  plugin="${build_dir}/StencilPrefetchPass.so"
fi
if [[ ! -f "${plugin}" ]]; then
  printf 'pass plugin was not produced in %s\n' "${build_dir}" >&2
  exit 1
fi

step1_ir="${repo_root}/01_llvm_ir_analysis/output/stencil_sme_kernels.ll"
compat_ir="${build_dir}/stencil_sme_kernels.llvm18.ll"
after_ir="${output_dir}/stencil_sme_kernels.after.ll"
pass_log="${output_dir}/pass_run.log"
report="${output_dir}/plugin_test_report.md"

# Apple Clang 21 emits two textual IR additions that LLVM 18 cannot parse.
# Removing them changes neither the pointer data flow nor the loop structure.
sed \
  -e 's/ captures(none)//g' \
  -e 's/getelementptr inbounds nuw/getelementptr inbounds/g' \
  "${step1_ir}" > "${compat_ir}"

"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm \
  -Wno-override-module \
  -fpass-plugin="${plugin}" \
  "${compat_ir}" \
  -o "${after_ir}" \
  2> "${pass_log}"

grep -q 'function=stencil_2d5p_sme_f32' "${pass_log}"
grep -q 'function=stencil_3d7p_sme_f32' "${pass_log}"
grep -q 'analyses=LoopInfo,ScalarEvolution,DominatorTree,TargetIR,AssumptionCache' \
  "${pass_log}"

plugin_name="$(basename "${plugin}")"
llvm_version="$("${llvm_config}" --version)"
clang_version="$("${llvm_clang}" --version | head -n 1)"

{
  printf '# 步骤 2 LLVM pass 插件测试报告\n\n'
  printf -- '- 总体结果：**PASS**\n'
  printf -- '- LLVM：`%s`\n' "${llvm_version}"
  printf -- '- Clang：`%s`\n' "${clang_version}"
  printf -- '- 插件：`build/%s`\n' "${plugin_name}"
  printf -- '- 输入：`../01_llvm_ir_analysis/output/stencil_sme_kernels.ll`\n'
  printf -- '- 输出：`output/stencil_sme_kernels.after.ll`\n\n'
  printf '## 验证内容\n\n'
  printf '1. CMake 成功发现 LLVM 开发包并构建动态插件。\n'
  printf '2. Clang 通过 `-fpass-plugin` 成功加载插件。\n'
  printf '3. optimizer-early callback 对两个 stencil 函数运行。\n'
  printf '4. pass 成功获取五项方案要求的 LLVM analysis。\n'
  printf '5. pass 返回 `PreservedAnalyses::all()`，本步骤不修改 IR。\n\n'
  printf '## Pass 输出\n\n```text\n'
  grep 'StencilPrefetchPass:' "${pass_log}"
  printf '```\n\n'
  printf '步骤 3 可以在该 function pass 中增加 stencil 循环和地址识别。\n'
} > "${report}"

printf 'Plugin: %s\n' "${plugin}"
printf 'Report: %s\n' "${report}"
