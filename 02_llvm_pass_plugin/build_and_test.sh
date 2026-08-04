#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${BUILD_DIR:-${script_dir}/build}"
output_dir="${script_dir}/output"

find_tool() {
  command -v "$1" 2>/dev/null || true
}

llvm_config="${LLVM_CONFIG:-$(find_tool llvm-config)}"
cmake_bin="${CMAKE:-$(find_tool cmake)}"
ninja_bin="${NINJA:-$(find_tool ninja)}"
cmake_generator="${CMAKE_GENERATOR:-}"
for tool in "${llvm_config}" "${cmake_bin}"; do
  if [[ -z "${tool}" || ! -x "${tool}" ]]; then
    printf 'missing required tool: %s\n' "${tool:-<unset>}" >&2
    exit 1
  fi
done
if [[ -z "${cmake_generator}" ]]; then
  if [[ -n "${ninja_bin}" && -x "${ninja_bin}" ]]; then
    cmake_generator="Ninja"
  else
    cmake_generator="Unix Makefiles"
  fi
fi
if [[ "${cmake_generator}" == "Ninja" && ( -z "${ninja_bin}" || ! -x "${ninja_bin}" ) ]]; then
  printf 'CMAKE_GENERATOR=Ninja requires ninja; install it or use Unix Makefiles.\n' >&2
  exit 1
fi
if [[ "${cmake_generator}" == "Unix Makefiles" && -z "$(find_tool make)" ]]; then
  printf 'Unix Makefiles requires make; install make or ninja.\n' >&2
  exit 1
fi

llvm_dir="$("${llvm_config}" --cmakedir)"
llvm_bindir="$("${llvm_config}" --bindir)"
llvm_includedir="$("${llvm_config}" --includedir)"
if [[ ! -f "${llvm_dir}/LLVMConfig.cmake" ]]; then
  printf 'missing LLVM CMake package configuration: %s/LLVMConfig.cmake\n' \
    "${llvm_dir}" >&2
  printf 'llvm-config=%s\n' "${llvm_config}" >&2
  printf 'install a complete standalone LLVM toolchain or set LLVM_CONFIG correctly.\n' >&2
  exit 1
fi
if [[ ! -f "${llvm_includedir}/llvm/ADT/SmallVector.h" ]]; then
  printf 'missing LLVM development header: %s/llvm/ADT/SmallVector.h\n' \
    "${llvm_includedir}" >&2
  printf 'the LLVM installation selected by llvm-config is not a complete development package.\n' >&2
  printf 'install matching LLVM headers or set LLVM_CONFIG to the full LLVM installation.\n' >&2
  exit 1
fi
plugin_cc="${PLUGIN_CC:-${llvm_bindir}/clang}"
plugin_cxx="${PLUGIN_CXX:-${llvm_bindir}/clang++}"
llvm_clang="${LLVM_CLANG:-${llvm_bindir}/clang}"
llvm_opt="${LLVM_OPT:-${llvm_bindir}/opt}"
kernel_ir="${STENCIL_KERNEL_IR:-${repo_root}/01_llvm_ir_analysis/output/stencil_all_sme.kernels.ll}"
require_recognized="${STENCIL_REQUIRE_RECOGNIZED:-1}"

for tool in "${plugin_cc}" "${plugin_cxx}" "${llvm_clang}"; do
  if [[ ! -x "${tool}" ]]; then
    printf 'missing LLVM compiler: %s\n' "${tool}" >&2
    exit 1
  fi
done
if [[ ! -f "${kernel_ir}" ]]; then
  printf 'missing kernel-only IR: %s\n' "${kernel_ir}" >&2
  printf 'run 01_llvm_ir_analysis/generate_and_check.sh first.\n' >&2
  exit 1
fi

mkdir -p "${build_dir}" "${output_dir}"
cmake_args=(
  -S "${script_dir}" \
  -B "${build_dir}" \
  -G "${cmake_generator}" \
  -DLLVM_DIR:PATH="${llvm_dir}" \
  -DCMAKE_C_COMPILER="${plugin_cc}" \
  -DCMAKE_CXX_COMPILER="${plugin_cxx}" \
  -DCMAKE_BUILD_TYPE=Release
)
if [[ "${cmake_generator}" == "Ninja" ]]; then
  cmake_args+=("-DCMAKE_MAKE_PROGRAM=${ninja_bin}")
fi
"${cmake_bin}" "${cmake_args[@]}"
# Force this small plugin to rebuild without cleaning LLVM or unrelated targets.
"${cmake_bin}" -E touch \
  "${script_dir}/src/StencilAnalysis.cpp" \
  "${script_dir}/src/StencilPrefetchDecision.cpp" \
  "${script_dir}/src/StencilPrefetchPass.cpp"
"${cmake_bin}" --build "${build_dir}"

plugin="${build_dir}/StencilPrefetchPass.so"
if [[ ! -f "${plugin}" ]]; then
  plugin="${build_dir}/StencilPrefetchPass.dylib"
fi
if [[ ! -f "${plugin}" ]]; then
  printf 'pass plugin was not produced in %s\n' "${build_dir}" >&2
  exit 1
fi

after_ir="${output_dir}/stencil_kernels.after.ll"
baseline_ir="${build_dir}/stencil_kernels.baseline.ll"
baseline_assembly="${output_dir}/stencil_kernels.baseline.s"
prefetch_assembly="${output_dir}/stencil_kernels.s"
pass_log="${output_dir}/pass_run.log"
idempotent_ir="${build_dir}/stencil_kernels.idempotent.ll"
idempotency_log="${output_dir}/idempotency_run.log"
budget_ir="${build_dir}/stencil_kernels.no-prefetch.ll"
budget_log="${output_dir}/budget_reject_run.log"
override_ir="${build_dir}/stencil_kernels.profile-override.ll"
override_log="${output_dir}/profile_override_run.log"
negative_ir="${script_dir}/tests/non_stencil.ll"
negative_after_ir="${build_dir}/non_stencil.after.ll"
negative_log="${output_dir}/negative_run.log"
report="${output_dir}/plugin_test_report.md"
recognition_report="${output_dir}/stencil_recognition_report.md"
decision_report="${output_dir}/stencil_prefetch_decision_report.md"

run_pass() {
  local input_ir="$1"
  local output_ir="$2"
  local log_file="$3"

  if [[ -x "${llvm_opt}" ]]; then
    "${llvm_opt}" \
      -load-pass-plugin="${plugin}" \
      -passes='function(stencil-prefetch),verify' \
      -S "${input_ir}" \
      -o "${output_ir}" \
      2> "${log_file}"
    return
  fi

  # Development fallback for partial LLVM builds that do not contain opt.
  # Server validation should use the standalone opt path above.
  "${llvm_clang}" \
    -x ir -O1 -S -emit-llvm -Wno-override-module \
    -fpass-plugin="${plugin}" \
    "${input_ir}" \
    -o "${output_ir}" \
    2> "${log_file}"
}

# Step 1 already emits -O1 kernel IR. Run this pass explicitly after that
# pipeline so later Clang optimization cannot erase calls before validation.
run_pass "${kernel_ir}" "${after_ir}" "${pass_log}"

recognized_count="$(grep -c '^StencilAnalysis:' "${pass_log}" || true)"
decision_count="$(grep -c '^StencilDecision:' "${pass_log}" || true)"
enabled_count="$(grep '^StencilDecision:' "${pass_log}" | grep -c 'enable=yes' || true)"
inserted_count="$(grep -c '^StencilPrefetchInsert:' "${pass_log}" || true)"
prefetch_count="$(grep -c 'call void @llvm.aarch64.prefetch' "${after_ir}" || true)"
if [[ "${require_recognized}" == "1" && "${recognized_count}" -eq 0 ]]; then
  printf 'no extracted function matches the current stencil pass model\n' >&2
  printf 'analysis rejection reasons:\n' >&2
  grep '^StencilAnalysisReject:' "${pass_log}" >&2 || true
  printf 'full pass log: %s\n' "${pass_log}" >&2
  printf 'set STENCIL_REQUIRE_RECOGNIZED=0 to inspect extraction only.\n' >&2
  exit 1
fi
if [[ "${inserted_count}" -ne "${enabled_count}" || \
      "${prefetch_count}" -ne "${inserted_count}" ]]; then
  printf 'prefetch counts disagree: decisions=%s inserted=%s IR=%s\n' \
    "${enabled_count}" "${inserted_count}" "${prefetch_count}" >&2
  grep '^StencilPrefetchInsertReject:' "${pass_log}" >&2 || true
  printf 'insertion log: %s\n' "${pass_log}" >&2
  exit 1
fi

"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm -Wno-override-module \
  "${kernel_ir}" \
  -o "${baseline_ir}"
"${llvm_clang}" \
  -x ir -O1 -S -Wno-override-module \
  "${baseline_ir}" \
  -o "${baseline_assembly}"
"${llvm_clang}" \
  -x ir -O1 -S -Wno-override-module \
  "${after_ir}" \
  -o "${prefetch_assembly}"

if grep -Eq '^[[:space:]]*prf(m|um)[[:space:]]' "${baseline_assembly}"; then
  printf 'kernel-only baseline unexpectedly contains software prefetch\n' >&2
  exit 1
fi
assembly_prefetch_count="$(grep -Ec '^[[:space:]]*prf(m|um)[[:space:]]' "${prefetch_assembly}" || true)"
if [[ "${assembly_prefetch_count}" -ne "${prefetch_count}" ]]; then
  printf 'assembly PRFM count (%s) does not match IR prefetch count (%s)\n' \
    "${assembly_prefetch_count}" "${prefetch_count}" >&2
  exit 1
fi

# The pass must be idempotent for every already-prefetched recognized kernel.
run_pass "${after_ir}" "${idempotent_ir}" "${idempotency_log}"
idempotent_count="$(grep -c 'call void @llvm.aarch64.prefetch' "${idempotent_ir}" || true)"
if [[ "${idempotent_count}" -ne "${prefetch_count}" ]]; then
  printf 'idempotency changed the prefetch count\n' >&2
  exit 1
fi

# A zero stream budget preserves recognition but forbids all insertions.
SME_PREFETCH_MAX_STREAMS=0 \
  run_pass "${kernel_ir}" "${budget_ir}" "${budget_log}"
if grep -q 'call void @llvm.aarch64.prefetch' "${budget_ir}"; then
  printf 'zero stream budget unexpectedly inserted a prefetch\n' >&2
  exit 1
fi

# Verify that tuning can select one stencil kind and override the model.
SME_PREFETCH_ENABLE_CURRENT_L1=0 \
SME_PREFETCH_ENABLE_ROW_L1=1 \
SME_PREFETCH_ENABLE_PLANE_L1=0 \
SME_PREFETCH_ENABLE_PLANE_L2=0 \
SME_PREFETCH_MASK_ROW_L1=4 \
SME_PREFETCH_DISTANCE_ROW_L1=6 \
SME_PREFETCH_POLICY_ROW_L1=STRM \
SME_PREFETCH_STREAMING_VL_BYTES=128 \
SME_PREFETCH_EXPECTED_ROW_BYTES=8192 \
  run_pass "${kernel_ir}" "${override_ir}" "${override_log}"
if ! grep -q '^StencilDecision:.*kind=2D9P.*enable=yes.*distance=6.*policy=STRM' \
    "${override_log}"; then
  printf 'profile override did not enable the requested 2D9P row strategy\n' >&2
  exit 1
fi
if ! grep -q '^StencilDecisionProfile:.*assumed-vl=128.*row-bytes=8192' \
    "${override_log}"; then
  printf 'profile hardware override was not applied\n' >&2
  exit 1
fi
if grep '^StencilDecision:.*enable=yes' "${override_log}" |
    grep -qv 'kind=2D9P'; then
  printf 'profile stencil mask enabled an unexpected stencil kind\n' >&2
  exit 1
fi

# Non-stencil IR is a separate fixture. It must remain untouched even though
# the pass no longer relies on a function-name prefix.
run_pass "${negative_ir}" "${negative_after_ir}" "${negative_log}"
if grep -q 'call void @llvm.aarch64.prefetch' "${negative_after_ir}" || \
   grep -q '^StencilDecision:' "${negative_log}"; then
  printf 'non-stencil fixture received a prefetch decision\n' >&2
  exit 1
fi

{
  printf '# 步骤 2-4 插件验证报告\n\n'
  printf -- '- 输入 kernel IR：`%s`\n' "${kernel_ir}"
  printf -- '- 插件：`%s`\n' "${plugin}"
  if [[ -x "${llvm_opt}" ]]; then
    printf -- '- Pass runner：`%s`\n' "${llvm_opt}"
  else
    printf -- '- Pass runner：Clang fallback `%s`\n' "${llvm_clang}"
  fi
  printf -- '- LLVM：`%s`\n' "$("${llvm_config}" --version)"
  printf -- '- 提取函数数：`%s`\n' "$(grep -c '^define ' "${kernel_ir}")"
  printf -- '- 已识别 stencil 函数数：`%s`\n' "${recognized_count}"
  printf -- '- 预取决策数：`%s`，启用/实际插入：`%s / %s`\n' \
    "${decision_count}" "${enabled_count}" "${inserted_count}"
  printf -- '- 插入 intrinsic/汇编 PRFM 数：`%s / %s`\n' \
    "${prefetch_count}" "${assembly_prefetch_count}"
  printf -- '- test/main：不在 kernel IR 中，不参与 pass 或 kernel 汇编链接\n\n'
  printf '支持 1D3P、2D5P/9P、3D7P/13P/25P/27P；未能证明地址拓扑的'
  printf '提取函数会被安全跳过。逐函数结果见 stencil_recognition_report.md。\n'
} > "${report}"

{
  printf '# 步骤 3 Stencil 识别报告\n\n## 已识别\n\n```text\n'
  grep '^StencilAnalysis:' "${pass_log}" || true
  printf '```\n\n## 安全跳过\n\n```text\n'
  grep '^StencilAnalysisReject:' "${pass_log}" || true
  printf '```\n'
} > "${recognition_report}"

{
  printf '# 步骤 4 预取决策报告\n\n```text\n'
  grep '^StencilDecision:' "${pass_log}" || true
  printf '```\n'
} > "${decision_report}"

printf 'Plugin: %s\n' "${plugin}"
printf 'Report: %s\n' "${report}"
printf 'Assembly: %s\n' "${prefetch_assembly}"
