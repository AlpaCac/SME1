#!/usr/bin/env bash
set -euo pipefail

# Keep the regression baseline deterministic even when the caller previously
# exported an experiment profile.
unset SME_PREFETCH_MAX_STREAMS
unset SME_PREFETCH_MAX_INSTRUCTIONS
unset SME_PREFETCH_MAX_BYTES
unset SME_PREFETCH_USEFUL_CYCLES_2D
unset SME_PREFETCH_USEFUL_CYCLES_3D
unset SME_PREFETCH_ENABLE_ROW_L1
unset SME_PREFETCH_ENABLE_PLANE_L1
unset SME_PREFETCH_ENABLE_PLANE_L2

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
negative_ir="${script_dir}/tests/non_stencil.ll"
negative_after_ir="${build_dir}/non_stencil.after.ll"
negative_log="${output_dir}/negative_run.log"
malformed_ir="${build_dir}/malformed_2d.ll"
malformed_after_ir="${build_dir}/malformed_2d.after.ll"
malformed_log="${output_dir}/malformed_run.log"
recognition_report="${output_dir}/stencil_recognition_report.md"
decision_report="${output_dir}/stencil_prefetch_decision_report.md"
lowered_assembly="${output_dir}/stencil_sme_kernels.s"
ir_baseline="${build_dir}/stencil_sme_kernels.baseline.ll"
ir_baseline_assembly="${output_dir}/stencil_sme_kernels.ir-baseline.s"
direct_assembly="${output_dir}/stencil_sme_kernels.direct.s"
baseline_assembly="${output_dir}/stencil_sme_kernels.baseline.s"
direct_ir="${build_dir}/stencil_sme_kernels.direct.ll"
idempotent_ir="${build_dir}/stencil_sme_kernels.idempotent.ll"
direct_log="${output_dir}/direct_compile.log"
idempotency_log="${output_dir}/idempotency_run.log"
budget_reject_ir="${build_dir}/budget_reject.after.ll"
budget_reject_log="${output_dir}/budget_reject_run.log"

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
grep -q \
  'kind=2D5P logical-loads=5 physical-streams=3 vector-step=cntsw streams=current-row:3,north-row:1,south-row:1' \
  "${pass_log}"
grep -q \
  'kind=3D7P logical-loads=7 physical-streams=5 vector-step=cntsw streams=current-row:3,north-row:1,south-row:1,front-plane:1,back-plane:1' \
  "${pass_log}"
if [[ "$(grep -c '^StencilAnalysis:' "${pass_log}")" -ne 2 ]]; then
  printf 'expected exactly two recognized stencil loops\n' >&2
  exit 1
fi
if [[ "$(grep -c '^StencilDecision:' "${pass_log}")" -ne 8 ]]; then
  printf 'expected exactly eight step 4 prefetch decisions\n' >&2
  exit 1
fi
if grep '^StencilDecision:' "${pass_log}" | grep -q 'enable=no'; then
  printf 'generic-sme baseline unexpectedly rejected a prefetch decision\n' >&2
  exit 1
fi
grep -q \
  'kind=2D5P stream=north-row enable=yes distance=4 level=L1 policy=KEEP' \
  "${pass_log}"
grep -q \
  'kind=3D7P stream=front-plane enable=yes distance=4 level=L1 policy=STRM' \
  "${pass_log}"
grep -q \
  'kind=3D7P stream=front-plane enable=yes distance=10 level=L2 policy=KEEP' \
  "${pass_log}"
if grep '^StencilDecision:' "${pass_log}" | grep -q 'stream=current-row'; then
  printf 'continuous current-row software prefetch must be disabled by default\n' >&2
  exit 1
fi

if [[ "$(grep -c 'call void @llvm.aarch64.prefetch' "${after_ir}")" -ne 8 ]]; then
  printf 'expected exactly eight AArch64 prefetch intrinsics\n' >&2
  exit 1
fi
if [[ "$(grep -c 'call void @llvm.aarch64.prefetch.*i32 0, i32 0, i32 0, i32 1)' "${after_ir}")" -ne 4 ]]; then
  printf 'expected four L1 KEEP prefetches\n' >&2
  exit 1
fi
if [[ "$(grep -c 'call void @llvm.aarch64.prefetch.*i32 0, i32 0, i32 1, i32 1)' "${after_ir}")" -ne 2 ]]; then
  printf 'expected two L1 STRM prefetches\n' >&2
  exit 1
fi
if [[ "$(grep -c 'call void @llvm.aarch64.prefetch.*i32 0, i32 1, i32 0, i32 1)' "${after_ir}")" -ne 2 ]]; then
  printf 'expected two L2 KEEP prefetches\n' >&2
  exit 1
fi
if [[ "$(grep -c '= icmp ult i64 %prefetch.future.x' "${after_ir}")" -ne 3 ]]; then
  printf 'expected one 2D and two 3D future-address guards\n' >&2
  exit 1
fi
if [[ "$(grep -c 'prefetch.addr.* = getelementptr float' "${after_ir}")" -ne 8 ]]; then
  printf 'expected eight non-inbounds future address GEPs\n' >&2
  exit 1
fi
if grep -q 'prefetch.addr.* = getelementptr inbounds' "${after_ir}"; then
  printf 'future prefetch addresses must not use inbounds GEP\n' >&2
  exit 1
fi

"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm \
  -Wno-override-module \
  -fpass-plugin="${plugin}" \
  "${negative_ir}" \
  -o "${negative_after_ir}" \
  2> "${negative_log}"

grep -q 'function=stencil_vector_copy' "${negative_log}"
if grep -q '^StencilAnalysis:' "${negative_log}"; then
  printf 'non-stencil negative test was incorrectly recognized\n' >&2
  exit 1
fi
if grep -q '^StencilDecision:' "${negative_log}" ||
   grep -q 'llvm\.aarch64\.prefetch' "${negative_after_ir}"; then
  printf 'non-stencil negative test received a prefetch decision\n' >&2
  exit 1
fi

# Keep five 2D loads but make south use the north base. Recognition must
# reject the broken +/-row-stride relation rather than trusting load count.
sed 's/ptr %29, i64 %32/ptr %28, i64 %32/' \
  "${compat_ir}" > "${malformed_ir}"
if cmp -s "${compat_ir}" "${malformed_ir}"; then
  printf 'failed to construct malformed 2D negative test\n' >&2
  exit 1
fi

"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm \
  -Wno-override-module \
  -fpass-plugin="${plugin}" \
  "${malformed_ir}" \
  -o "${malformed_after_ir}" \
  2> "${malformed_log}"

if grep -q 'StencilAnalysis: function=stencil_2d5p_sme_f32' \
  "${malformed_log}"; then
  printf 'malformed 2D stride relation was incorrectly recognized\n' >&2
  exit 1
fi
grep -q 'StencilAnalysis: function=stencil_3d7p_sme_f32 kind=3D7P' \
  "${malformed_log}"
if [[ "$(grep -c '^StencilDecision:' "${malformed_log}")" -ne 6 ]] ||
   [[ "$(grep -c 'call void @llvm.aarch64.prefetch' "${malformed_after_ir}")" -ne 6 ]]; then
  printf 'malformed input should retain only the six 3D decisions\n' >&2
  exit 1
fi

# Step 4 ends with backend and direct-Clang integration checks. First verify
# that the inserted intrinsic survives IR round-trip and lowers as expected.
"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm -Wno-override-module \
  "${compat_ir}" \
  -o "${ir_baseline}"

"${llvm_clang}" \
  -x ir -O1 -S -Wno-override-module \
  "${ir_baseline}" \
  -o "${ir_baseline_assembly}"

"${llvm_clang}" \
  -x ir -O1 -S -Wno-override-module \
  "${after_ir}" \
  -o "${lowered_assembly}"

if grep -Eq '^[[:space:]]*prf(m|um)[[:space:]]' "${ir_baseline_assembly}"; then
  printf 'IR baseline unexpectedly contains software prefetch\n' >&2
  exit 1
fi
[[ "$(grep -Ec '^[[:space:]]*prf(m|um)[[:space:]]' "${lowered_assembly}")" -eq 8 ]]
[[ "$(grep -c 'pldl1keep' "${lowered_assembly}")" -eq 4 ]]
[[ "$(grep -c 'pldl1strm' "${lowered_assembly}")" -eq 2 ]]
[[ "$(grep -c 'pldl2keep' "${lowered_assembly}")" -eq 2 ]]
if grep -Eq 'pldl2strm|pldl3(keep|strm)' "${lowered_assembly}"; then
  printf 'unexpected prefetch level or policy in lowered assembly\n' >&2
  exit 1
fi
[[ "$(grep -Ec '^[[:space:]]*smstart[[:space:]]+sm' "${lowered_assembly}")" -eq 2 ]]
[[ "$(grep -Ec '^[[:space:]]*smstop[[:space:]]+sm' "${lowered_assembly}")" -eq 2 ]]
grep -q 'whilelo' "${lowered_assembly}"
grep -q 'ld1w' "${lowered_assembly}"
grep -q 'st1w' "${lowered_assembly}"

# LLVM 18 still uses the draft SME resource-header name. The test-only include
# redirects <arm_sme.h> without changing the original C kernel.
direct_flags=(
  -O1
  -march=armv9.2-a+sme+sve2
  -I "${script_dir}/tests/include"
)

"${llvm_clang}" "${direct_flags[@]}" \
  -fpass-plugin="${plugin}" \
  -S -emit-llvm "${repo_root}/stencil_sme_kernels.c" \
  -o "${direct_ir}" \
  2> "${build_dir}/direct_ir.log"

"${llvm_clang}" "${direct_flags[@]}" \
  -fpass-plugin="${plugin}" \
  -S "${repo_root}/stencil_sme_kernels.c" \
  -o "${direct_assembly}" \
  2> "${direct_log}"

"${llvm_clang}" "${direct_flags[@]}" \
  -S "${repo_root}/stencil_sme_kernels.c" \
  -o "${baseline_assembly}"

[[ "$(grep -c 'call void @llvm.aarch64.prefetch' "${direct_ir}")" -eq 8 ]]
[[ "$(grep -Ec 'pldl[123](keep|strm)' "${direct_assembly}")" -eq 8 ]]
if grep -Eq 'pldl[123](keep|strm)' "${baseline_assembly}"; then
  printf 'plugin-off baseline unexpectedly contains software prefetch\n' >&2
  exit 1
fi
[[ "$(grep -c '^StencilDecision:' "${direct_log}")" -eq 8 ]]

# Re-running the plugin must leave the existing eight calls unchanged.
"${llvm_clang}" \
  -x ir -O1 -S -emit-llvm -Wno-override-module \
  -fpass-plugin="${plugin}" \
  "${direct_ir}" \
  -o "${idempotent_ir}" \
  2> "${idempotency_log}"

[[ "$(grep -c 'call void @llvm.aarch64.prefetch' "${idempotent_ir}")" -eq 8 ]]
[[ "$(grep -c 'status=AlreadyPrefetched' "${idempotency_log}")" -eq 2 ]]
if grep -q '^StencilDecision:' "${idempotency_log}"; then
  printf 'idempotency run made new prefetch decisions\n' >&2
  exit 1
fi

# A zero stream budget must reject every otherwise valid candidate and insert
# no intrinsic. This exercises a decision-model rejection, not recognition.
SME_PREFETCH_MAX_STREAMS=0 "${llvm_clang}" \
  -x ir -O1 -S -emit-llvm -Wno-override-module \
  -fpass-plugin="${plugin}" \
  "${compat_ir}" \
  -o "${budget_reject_ir}" \
  2> "${budget_reject_log}"

[[ "$(grep -c '^StencilDecision:' "${budget_reject_log}")" -eq 8 ]]
[[ "$(grep -c 'enable=no' "${budget_reject_log}")" -eq 8 ]]
[[ "$(grep -c 'reason=StreamBudgetReject' "${budget_reject_log}")" -eq 8 ]]
if grep -q 'call void @llvm.aarch64.prefetch' "${budget_reject_ir}"; then
  printf 'zero stream budget unexpectedly inserted prefetches\n' >&2
  exit 1
fi

plugin_name="$(basename "${plugin}")"
llvm_version="$("${llvm_config}" --version)"
clang_version="$("${llvm_clang}" --version | sed -n '1p')"

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
  printf '5. 步骤 4 插入预取后返回 `PreservedAnalyses::none()`。\n\n'
  printf '## Pass 输出\n\n```text\n'
  grep 'StencilPrefetchPass:' "${pass_log}"
  printf '```\n\n'
  printf '步骤 3 的 stencil 识别由同一个 function pass 实现。\n'
} > "${report}"

{
  printf '# 步骤 3 Stencil 识别测试报告\n\n'
  printf -- '- 总体结果：**PASS**\n'
  printf -- '- 正例输入：`../01_llvm_ir_analysis/output/stencil_sme_kernels.ll`\n'
  printf -- '- 负例输入：`tests/non_stencil.ll`\n'
  printf -- '- 结构负例：保留 5 个 load，但破坏 2D 的 `±row` stride 配对\n'
  printf -- '- IR 修改：无\n\n'
  printf '## 识别条件\n\n'
  printf '1. 最内层循环包含共同谓词的 5 或 7 个 masked load。\n'
  printf '2. 循环包含一个使用同一谓词的 masked store。\n'
  printf '3. 谓词由 `llvm.aarch64.sve.whilelo` 生成。\n'
  printf '4. `x` PHI 的 SCEV step 来自 `llvm.aarch64.sme.cntsw`。\n'
  printf '5. left/center/right 通过 `0/±sizeof(float)` 合并为 current-row。\n'
  printf '6. 其余 GEP stride 通过 SCEV 相反数配对为 row/plane 流。\n'
  printf '7. 包含外部调用或普通 store 的候选循环被拒绝。\n\n'
  printf '## 正例结果\n\n```text\n'
  grep '^StencilAnalysis:' "${pass_log}"
  printf '```\n\n'
  printf '## 负例结果\n\n'
  printf '`stencil_vector_copy` 进入 pass，但没有产生 `StencilAnalysis` 结果，'
  printf '证明识别不只依赖函数名前缀。\n\n'
  printf '结构负例中的 2D 函数仍有原始 load 框架，但 south 与 north 使用'
  printf '同一基址，因此没有被识别；同模块的 3D7P 仍被正确识别。\n'
} > "${recognition_report}"

{
  printf '# 步骤 4 预取决策与安全地址测试报告\n\n'
  printf -- '- 总体结果：**PASS**\n'
  printf -- '- Profile：`generic-sme`\n'
  printf -- '- 修改后 IR：`output/stencil_sme_kernels.after.ll`\n'
  printf -- '- 正例决策数：8\n'
  printf -- '- 非 stencil 负例决策数：0\n'
  printf -- '- 结构负例决策数：6，仅保留 3D7P\n\n'
  printf '## 默认决策\n\n'
  printf '| 算子 | 物理流 | 距离 | 层级 | 策略 | 数量 |\n'
  printf '|---|---|---:|---|---|---:|\n'
  printf '| 2D5P | north/south row | 4 | L1 | KEEP | 2 |\n'
  printf '| 3D7P | north/south row | 4 | L1 | KEEP | 2 |\n'
  printf '| 3D7P | front/back plane near | 4 | L1 | STRM | 2 |\n'
  printf '| 3D7P | front/back plane far | 10 | L2 | KEEP | 2 |\n\n'
  printf '连续 current-row 默认关闭，避免与硬件连续流预取重复。\n\n'
  printf '## 安全性与预算\n\n'
  printf '1. 每个候选经过 cache 容量、独立流、指令数和字节预算检查。\n'
  printf '2. 未来位置使用 `x + distance * cntsw()` 构造。\n'
  printf '3. 按距离合并 guard，仅在 `future_x < interior_end` 时执行预取。\n'
  printf '4. 未来地址使用非 `inbounds` GEP。\n'
  printf '5. left/center/right 已合并，不生成重复 current-row 预取。\n\n'
  printf '6. `SME_PREFETCH_MAX_STREAMS=0` 时 8 个候选均以'
  printf ' `StreamBudgetReject` 拒绝，且不插入 intrinsic。\n\n'
  printf '## 端到端编译\n\n'
  printf '1. 修改后 IR 成功降为 8 条 `PRFM/PRFUM`：'
  printf '4 条 L1 KEEP、2 条 L1 STRM、2 条 L2 KEEP。\n'
  printf '2. 原始 C 通过 `-fpass-plugin` 直接生成带预取汇编。\n'
  printf '3. 不加载插件的基线汇编不含软件预取。\n'
  printf '4. 对已插入 IR 再次运行插件仍为 8 条，两个函数报告'
  printf ' `AlreadyPrefetched`。\n\n'
  printf '## 决策诊断\n\n```text\n'
  grep '^StencilDecision:' "${pass_log}"
  printf '```\n'
} > "${decision_report}"

printf 'Plugin: %s\n' "${plugin}"
printf 'Report: %s\n' "${report}"
printf 'Recognition report: %s\n' "${recognition_report}"
printf 'Decision report: %s\n' "${decision_report}"
printf 'Assembly: %s\n' "${lowered_assembly}"
printf 'Matched IR baseline assembly: %s\n' "${ir_baseline_assembly}"
printf 'Direct C assembly: %s\n' "${direct_assembly}"
