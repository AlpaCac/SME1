#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${script_dir}/build/server-module"
output_dir="${script_dir}/output/server-module"

standalone_llvm="${STANDALONE_LLVM:-${repo_root}/tools/llvm-19.1.7}"
opt_bin="${LLVM_OPT:-${standalone_llvm}/bin/opt}"
full_ir="${STENCIL_FULL_IR:-${repo_root}/01_llvm_ir_analysis/output/stencil_all_sme.full.ll}"
plugin="${STENCIL_PASS_PLUGIN:-${repo_root}/02_llvm_pass_plugin/build-standalone-llvm19/StencilPrefetchPass.so}"
march="${MARCH:-armv9.2-a+sme+sve2+sme-f64f64}"

if [[ -n "${BISHENG_CXX:-}" ]]; then
  runtime_cxx="${BISHENG_CXX}"
elif [[ -n "${BISHENG_HOME:-}" &&
        -x "${BISHENG_HOME}/bin/clang++" ]]; then
  runtime_cxx="${BISHENG_HOME}/bin/clang++"
else
  runtime_cxx=""
fi

for executable in "${opt_bin}" "${runtime_cxx}"; do
  if [[ -z "${executable}" || ! -x "${executable}" ]]; then
    printf 'missing executable: %s\n' "${executable:-<unset>}" >&2
    printf 'set STANDALONE_LLVM and BISHENG_CXX explicitly.\n' >&2
    exit 1
  fi
done

runtime_cxx_version="$("${runtime_cxx}" --version | sed -n '1p')"
if [[ "${STENCIL_ALLOW_NON_BISHENG_CXX:-0}" != "1" &&
      ! "${runtime_cxx_version}" =~ [Bb]i[Ss]heng ]]; then
  printf 'runtime compiler is not BiSheng: %s\n' \
    "${runtime_cxx_version}" >&2
  printf 'set BISHENG_CXX to the absolute BiSheng clang++ path.\n' >&2
  exit 1
fi
printf 'Runtime compiler: %s\n' "${runtime_cxx}"
printf 'Runtime compiler version: %s\n' "${runtime_cxx_version}"

for input in "${full_ir}" "${plugin}"; do
  if [[ ! -f "${input}" ]]; then
    printf 'missing input: %s\n' "${input}" >&2
    printf 'run scripts 01 and 02 before runtime validation.\n' >&2
    exit 1
  fi
done

mkdir -p "${build_dir}" "${output_dir}"

baseline_ir="${build_dir}/stencil_all_sme.baseline.ll"
prefetch_ir="${build_dir}/stencil_all_sme.prefetch.ll"
baseline_bin="${build_dir}/stencil_all_sme.baseline"
prefetch_bin="${build_dir}/stencil_all_sme.prefetch"

# Both variants retain the original test helpers and main. The only pipeline
# difference is whether StencilPrefetchPass runs on each function.
"${opt_bin}" -passes=verify -S "${full_ir}" -o "${baseline_ir}"
"${opt_bin}" \
  -load-pass-plugin="${plugin}" \
  -passes='function(stencil-prefetch),verify' \
  -S "${full_ir}" \
  -o "${prefetch_ir}" \
  2> "${output_dir}/pass_run.log"

baseline_prefetches="$(grep -c 'call void @llvm.aarch64.prefetch' \
  "${baseline_ir}" || true)"
prefetch_prefetches="$(grep -c 'call void @llvm.aarch64.prefetch' \
  "${prefetch_ir}" || true)"
if [[ "${baseline_prefetches}" -ne 0 ]]; then
  printf 'baseline IR unexpectedly contains %s prefetch calls\n' \
    "${baseline_prefetches}" >&2
  exit 1
fi
if [[ "${prefetch_prefetches}" -eq 0 ]]; then
  printf 'prefetch IR contains no prefetch calls\n' >&2
  exit 1
fi
if [[ -n "${EXPECTED_PREFETCH_COUNT:-}" &&
      "${prefetch_prefetches}" -ne "${EXPECTED_PREFETCH_COUNT}" ]]; then
  printf 'prefetch count %s does not match expected count %s\n' \
    "${prefetch_prefetches}" "${EXPECTED_PREFETCH_COUNT}" >&2
  exit 1
fi

link_flags=(--rtlib=compiler-rt -lgcc_s)
if [[ -n "${STENCIL_LINK_FLAGS:-}" ]]; then
  read -r -a extra_link_flags <<< "${STENCIL_LINK_FLAGS}"
  link_flags+=("${extra_link_flags[@]}")
fi
"${runtime_cxx}" -### -x ir -O3 -march="${march}" \
  "${baseline_ir}" "${link_flags[@]}" -o "${baseline_bin}" \
  2> "${output_dir}/baseline_link_plan.log"
"${runtime_cxx}" -x ir -O3 -march="${march}" \
  "${baseline_ir}" "${link_flags[@]}" -o "${baseline_bin}"
"${runtime_cxx}" -x ir -O3 -march="${march}" \
  "${prefetch_ir}" "${link_flags[@]}" -o "${prefetch_bin}"

default_cases=(
  --1d3p-s1 --1d3p-s2
  --2d5p-s1 --2d5p-s2
  --2d9p-s1 --2d9p-s2
  --3d13p-s1 --3d13p-s2
  --3d25p-s1 --3d25p-s2
  --3d27p-s1 --3d27p-s2
)
if [[ -n "${STENCIL_CASES:-}" ]]; then
  read -r -a test_cases <<< "${STENCIL_CASES}"
else
  test_cases=("${default_cases[@]}")
fi
if [[ "${#test_cases[@]}" -eq 0 ]]; then
  printf 'no test cases configured\n' >&2
  exit 1
fi

runner=()
if [[ -n "${STENCIL_CPU:-}" ]]; then
  taskset_bin="$(command -v taskset || true)"
  if [[ -z "${taskset_bin}" ]]; then
    printf 'STENCIL_CPU requires taskset\n' >&2
    exit 1
  fi
  runner=("${taskset_bin}" -c "${STENCIL_CPU}")
fi

run_original_test() {
  local variant="$1"
  local binary="$2"
  local test_case="$3"
  local case_name="${test_case#--}"
  local status

  if [[ ! "${case_name}" =~ ^[a-z0-9-]+$ ]]; then
    printf 'invalid test case argument: %s\n' "${test_case}" >&2
    return 2
  fi
  set +e
  "${runner[@]}" "${binary}" "${test_case}" \
    > "${output_dir}/correctness_${case_name}_${variant}.out" \
    2> "${output_dir}/correctness_${case_name}_${variant}.err"
  status=$?
  set -e
  printf '%s' "${status}"
}

correctness_summary="${output_dir}/correctness_summary.tsv"
: > "${correctness_summary}"
for test_case in "${test_cases[@]}"; do
  case_name="${test_case#--}"
  baseline_status="$(
    run_original_test baseline "${baseline_bin}" "${test_case}"
  )"
  prefetch_status="$(
    run_original_test prefetch "${prefetch_bin}" "${test_case}"
  )"
  if [[ "${baseline_status}" -ne 0 || "${prefetch_status}" -ne 0 ]]; then
    printf 'original test %s failed: baseline=%s prefetch=%s\n' \
      "${test_case}" "${baseline_status}" "${prefetch_status}" >&2
    exit 1
  fi

  outputs_match="yes"
  if ! cmp -s "${output_dir}/correctness_${case_name}_baseline.out" \
      "${output_dir}/correctness_${case_name}_prefetch.out" ||
     ! cmp -s "${output_dir}/correctness_${case_name}_baseline.err" \
      "${output_dir}/correctness_${case_name}_prefetch.err"; then
    outputs_match="no"
  fi
  if [[ "${STENCIL_REQUIRE_IDENTICAL_OUTPUT:-0}" == "1" &&
        "${outputs_match}" != "yes" ]]; then
    printf 'baseline and prefetch output differ for %s\n' \
      "${test_case}" >&2
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\n' \
    "${test_case}" "${baseline_status}" "${prefetch_status}" \
    "${outputs_match}" >> "${correctness_summary}"
done

warmups="${STENCIL_WARMUPS:-2}"
samples="${STENCIL_SAMPLES:-7}"
timings="${output_dir}/wall_time_seconds.tsv"
: > "${timings}"

time_bin="${TIME_BIN:-/usr/bin/time}"
if [[ ! -x "${time_bin}" ]]; then
  printf 'missing GNU time: %s\n' "${time_bin}" >&2
  exit 1
fi

timed_run() {
  local test_case="$1"
  local variant="$2"
  local binary="$3"
  local sample="$4"
  local case_name="${test_case#--}"
  local time_file="${build_dir}/${case_name}.${variant}.time"

  "${time_bin}" -f '%e' -o "${time_file}" \
    "${runner[@]}" "${binary}" "${test_case}" >/dev/null 2>/dev/null
  printf '%s\t%s\t%s\t%s\n' \
    "${test_case}" "${variant}" "${sample}" \
    "$(sed -n '1p' "${time_file}")" >> "${timings}"
}

if [[ "${STENCIL_SKIP_PERFORMANCE:-0}" != "1" ]]; then
  for test_case in "${test_cases[@]}"; do
    for ((sample = 0; sample < warmups; ++sample)); do
      "${runner[@]}" "${baseline_bin}" "${test_case}" >/dev/null 2>/dev/null
      "${runner[@]}" "${prefetch_bin}" "${test_case}" >/dev/null 2>/dev/null
    done
    for ((sample = 1; sample <= samples; ++sample)); do
      if ((sample % 2)); then
        timed_run "${test_case}" baseline "${baseline_bin}" "${sample}"
        timed_run "${test_case}" prefetch "${prefetch_bin}" "${sample}"
      else
        timed_run "${test_case}" prefetch "${prefetch_bin}" "${sample}"
        timed_run "${test_case}" baseline "${baseline_bin}" "${sample}"
      fi
    done
  done
fi

median_for() {
  local test_case="$1"
  local variant="$2"
  awk -F '\t' -v test_case="${test_case}" -v variant="${variant}" \
    '$1 == test_case && $2 == variant { print $4 }' \
    "${timings}" |
    sort -n |
    awk '{ value[NR] = $1 } END {
      if (NR == 0)
        print "not-run"
      else if (NR % 2)
        printf "%.6f", value[(NR + 1) / 2]
      else
        printf "%.6f", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

report="${output_dir}/runtime_validation_report.md"
{
  printf '# 服务器原始 main/test 正确性与性能报告\n\n'
  printf -- '- 完整 IR：`%s`\n' "${full_ir}"
  printf -- '- 毕昇编译器：`%s`\n' \
    "${runtime_cxx_version}"
  printf -- '- SME ABI runtime：`--rtlib=compiler-rt -lgcc_s`\n'
  printf -- '- 预取 intrinsic：baseline `%s`，prefetch `%s`\n' \
    "${baseline_prefetches}" "${prefetch_prefetches}"
  printf -- '- 测试入口：原始 `main`，每次只传入一个算子 test 参数\n'
  printf -- '- CPU 绑定：`%s`\n' "${STENCIL_CPU:-未绑定}"
  printf -- '- 每个用例预热/样本数：`%s / %s`\n\n' \
    "${warmups}" "${samples}"
  printf '| 参数 | baseline 状态 | prefetch 状态 | 输出一致 | baseline 中位时间/s | prefetch 中位时间/s | 加速比 |\n'
  printf '|---|---:|---:|---|---:|---:|---:|\n'
  while IFS=$'\t' read -r test_case baseline_status \
      prefetch_status outputs_match; do
    baseline_median="$(median_for "${test_case}" baseline)"
    prefetch_median="$(median_for "${test_case}" prefetch)"
    speedup="not-run"
    if [[ "${baseline_median}" != "not-run" &&
          "${prefetch_median}" != "not-run" ]]; then
      speedup="$(awk -v baseline="${baseline_median}" \
        -v prefetch="${prefetch_median}" \
        'BEGIN { printf "%.4f", baseline / prefetch }')"
    fi
    printf '| `%s` | %s | %s | %s | %s | %s | %s |\n' \
      "${test_case}" "${baseline_status}" "${prefetch_status}" \
      "${outputs_match}" "${baseline_median}" "${prefetch_median}" \
      "${speedup}"
  done < "${correctness_summary}"
  printf '\n'
  printf '退出状态只有在原 test 失败时返回非零才是有效的正确性判据。若输出'
  printf '包含计时等非确定内容，应检查两份输出中的校验值或测试结论。\n'
} > "${report}"

cat "${report}"
