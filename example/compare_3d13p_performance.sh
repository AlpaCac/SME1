#!/usr/bin/env bash
# 在 AArch64 SME 服务器上比较原始 3D13P 与论文式 ZA 映射实现。
#
# 用法：
#   BISHENG_CXX=/path/to/bisheng/bin/clang++ \
#   SME_PERF_CPU=0 SME_PERF_REPETITIONS=3 \
#   ./example/compare_3d13p_performance.sh
# 若要定位双 ZA 或重叠加载复用是否造成负收益，再设置 SME_PERF_ABLATIONS=1。
#
# 每个可执行文件自身对 stride=1 和 stride=2 各执行 100 次 kernel sweep。
# 脚本只解析程序打印的 Time:，不把编译、初始化或进程墙钟时间计入结果。
# 默认使用毕昇 compiler-rt 的 SME ABI 运行时，解决 __arm_tpidr2_save 等链接符号。

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cxx="${BISHENG_CXX:-${CXX:-clang++}}"
repetitions="${SME_PERF_REPETITIONS:-1}"
cpu="${SME_PERF_CPU:-}"
timeout_seconds="${SME_PERF_TIMEOUT_SECONDS:-0}"
ablations="${SME_PERF_ABLATIONS:-0}"
build_dir="${SME_PERF_BUILD_DIR:-${TMPDIR:-/tmp}/sme1-3d13p-performance}"

baseline_source="${script_dir}/stencil_all_sme.cpp"
paper_source="${script_dir}/smestencil_paper_3d13.cpp"
baseline_bin="${build_dir}/stencil_all_sme"
paper_bin="${build_dir}/smestencil_paper_3d13"
single_za_bin="${build_dir}/smestencil_paper_3d13_single_za"
no_reuse_bin="${build_dir}/smestencil_paper_3d13_no_reuse"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ -x "${cxx}" || -n "$(command -v "${cxx}" 2>/dev/null || true)" ]] || \
  die "compiler not found: ${cxx}; set BISHENG_CXX to the server clang++ path"
[[ -f "${baseline_source}" ]] || die "missing source: ${baseline_source}"
[[ -f "${paper_source}" ]] || die "missing source: ${paper_source}"
[[ "${repetitions}" =~ ^[1-9][0-9]*$ ]] || die "SME_PERF_REPETITIONS must be a positive integer"
[[ "${timeout_seconds}" =~ ^[0-9]+$ ]] || die "SME_PERF_TIMEOUT_SECONDS must be a non-negative integer"
[[ "${ablations}" == "0" || "${ablations}" == "1" ]] || \
  die "SME_PERF_ABLATIONS must be 0 or 1"

compiler_version="$("${cxx}" --version | sed -n '1p')"
if [[ "${SME_PERF_ALLOW_NON_BISHENG_CXX:-0}" != "1" &&
      ! "${compiler_version}" =~ [Bb]i[Ss]heng ]]; then
  die "compiler is not BiSheng: ${compiler_version}; set BISHENG_CXX or SME_PERF_ALLOW_NON_BISHENG_CXX=1"
fi

if [[ -n "${cpu}" ]]; then
  command -v taskset >/dev/null 2>&1 || die "SME_PERF_CPU requires taskset"
fi
if (( timeout_seconds > 0 )); then
  command -v timeout >/dev/null 2>&1 || die "SME_PERF_TIMEOUT_SECONDS requires timeout"
fi

mkdir -p "${build_dir}"

common_flags=(
  -O3
  -std=c++17
  -march=armv9-a+sme+sme-f64f64
)
if [[ -n "${SME_PERF_CXXFLAGS:-}" ]]; then
  # 允许服务器补充例如 -mcpu=native；该变量只应包含空格分隔的编译选项。
  read -r -a extra_flags <<< "${SME_PERF_CXXFLAGS}"
  common_flags+=("${extra_flags[@]}")
fi

# __arm_tpidr2_save 由毕昇 compiler-rt 的 SME ABI 支持提供。若服务器还需要额外
# 库路径或库，可通过 SME_PERF_LINK_FLAGS 以空格分隔的形式追加。
link_flags=(--rtlib=compiler-rt -lgcc_s)
if [[ -n "${SME_PERF_LINK_FLAGS:-}" ]]; then
  read -r -a extra_link_flags <<< "${SME_PERF_LINK_FLAGS}"
  link_flags+=("${extra_link_flags[@]}")
fi

printf '== 编译 ==\n'
printf 'compiler: %s\n' "${cxx}"
printf 'compiler version: %s\n' "${compiler_version}"
printf 'SME ABI link flags: %s\n' "${link_flags[*]}"
"${cxx}" "${common_flags[@]}" "${baseline_source}" "${link_flags[@]}" -o "${baseline_bin}"
"${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO "${paper_source}" \
  "${link_flags[@]}" -o "${paper_bin}"
if [[ "${ablations}" == "1" ]]; then
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_SINGLE_ZA "${paper_source}" \
    "${link_flags[@]}" -o "${single_za_bin}"
  "${cxx}" "${common_flags[@]}" -DSMESTENCIL_PAPER_DEMO \
    -DSMESTENCIL_PAPER_DISABLE_LOAD_REUSE "${paper_source}" \
    "${link_flags[@]}" -o "${no_reuse_bin}"
fi

run_binary() {
  local binary="$1"
  local log_file="$2"

  if (( timeout_seconds > 0 )); then
    if [[ -n "${cpu}" ]]; then
      timeout "${timeout_seconds}" taskset -c "${cpu}" "${binary}" >"${log_file}" 2>&1
    else
      timeout "${timeout_seconds}" "${binary}" >"${log_file}" 2>&1
    fi
  elif [[ -n "${cpu}" ]]; then
    taskset -c "${cpu}" "${binary}" >"${log_file}" 2>&1
  else
    "${binary}" >"${log_file}" 2>&1
  fi
}

run_binary_checked() {
  local label="$1"
  local binary="$2"
  local log_file="$3"
  local status

  if run_binary "${binary}" "${log_file}"; then
    return 0
  else
    status=$?
  fi

  printf 'error: %s failed with exit code %d\n' "${label}" "${status}" >&2
  printf 'log: %s\n' "${log_file}" >&2
  printf '%s\n' '----- program output (first 160 lines) -----' >&2
  sed -n '1,160p' "${log_file}" >&2
  exit "${status}"
}

read_times() {
  local log_file="$1"
  local -n destination="$2"

  mapfile -t destination < <(
    awk -F ':' '/^Time:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2 }' "${log_file}"
  )
  if (( ${#destination[@]} != 2 )); then
    printf 'expected two Time: lines in %s, got %d\n' "${log_file}" "${#destination[@]}" >&2
    sed -n '1,160p' "${log_file}" >&2
    exit 1
  fi
}

median() {
  printf '%s\n' "$@" | LC_ALL=C sort -n | awk '
    { value[NR] = $1 }
    END {
      if (NR == 0) exit 1
      if (NR % 2) print value[(NR + 1) / 2]
      else print (value[NR / 2] + value[NR / 2 + 1]) / 2
    }'
}

speedup() {
  awk -v baseline="$1" -v paper="$2" 'BEGIN {
    if (paper <= 0) exit 1
    printf "%.4f", baseline / paper
  }'
}

baseline_s1=()
baseline_s2=()
paper_s1=()
paper_s2=()
single_za_s1=()
single_za_s2=()
no_reuse_s1=()
no_reuse_s2=()

printf '\n== 运行 ==\n'
for ((run = 1; run <= repetitions; ++run)); do
  baseline_log="${build_dir}/baseline_run_${run}.log"
  paper_log="${build_dir}/paper_run_${run}.log"
  single_za_log="${build_dir}/single_za_run_${run}.log"
  no_reuse_log="${build_dir}/no_reuse_run_${run}.log"
  printf 'sample %d/%d: baseline\n' "${run}" "${repetitions}"
  run_binary_checked "baseline sample ${run}" "${baseline_bin}" "${baseline_log}"
  printf 'sample %d/%d: paper-style\n' "${run}" "${repetitions}"
  run_binary_checked "paper-style sample ${run}" "${paper_bin}" "${paper_log}"
  if [[ "${ablations}" == "1" ]]; then
    printf 'sample %d/%d: paper-style single ZA\n' "${run}" "${repetitions}"
    run_binary_checked \
      "single-ZA sample ${run}" "${single_za_bin}" "${single_za_log}"
    printf 'sample %d/%d: paper-style no load reuse\n' "${run}" "${repetitions}"
    run_binary_checked \
      "no-reuse sample ${run}" "${no_reuse_bin}" "${no_reuse_log}"
  fi

  baseline_times=()
  paper_times=()
  single_za_times=()
  no_reuse_times=()
  read_times "${baseline_log}" baseline_times
  read_times "${paper_log}" paper_times
  if [[ "${ablations}" == "1" ]]; then
    read_times "${single_za_log}" single_za_times
    read_times "${no_reuse_log}" no_reuse_times
  fi
  baseline_s1+=("${baseline_times[0]}")
  baseline_s2+=("${baseline_times[1]}")
  paper_s1+=("${paper_times[0]}")
  paper_s2+=("${paper_times[1]}")
  if [[ "${ablations}" == "1" ]]; then
    single_za_s1+=("${single_za_times[0]}")
    single_za_s2+=("${single_za_times[1]}")
    no_reuse_s1+=("${no_reuse_times[0]}")
    no_reuse_s2+=("${no_reuse_times[1]}")
  fi
done

baseline_s1_median="$(median "${baseline_s1[@]}")"
baseline_s2_median="$(median "${baseline_s2[@]}")"
paper_s1_median="$(median "${paper_s1[@]}")"
paper_s2_median="$(median "${paper_s2[@]}")"

printf '\n== 3D13P 性能结果 ==\n'
printf '每个 Time: 均为 100 次 kernel sweep 的总时间；单次平均时间需再除以 100。\n'
printf '| stride | 原始算法中位时间/s | 修改后算法中位时间/s | 加速比（原始/修改后） |\n'
printf '|---|---:|---:|---:|\n'
printf '| 1 | %s | %s | %sx |\n' \
  "${baseline_s1_median}" "${paper_s1_median}" "$(speedup "${baseline_s1_median}" "${paper_s1_median}")"
printf '| 2 | %s | %s | %sx |\n' \
  "${baseline_s2_median}" "${paper_s2_median}" "$(speedup "${baseline_s2_median}" "${paper_s2_median}")"
if [[ "${ablations}" == "1" ]]; then
  single_za_s1_median="$(median "${single_za_s1[@]}")"
  single_za_s2_median="$(median "${single_za_s2[@]}")"
  no_reuse_s1_median="$(median "${no_reuse_s1[@]}")"
  no_reuse_s2_median="$(median "${no_reuse_s2[@]}")"

  printf '\n== 消融诊断 ==\n'
  printf '| 实现 | stride | 中位时间/s | 相对原始算法加速比 |\n'
  printf '|---|---:|---:|---:|\n'
  printf '| 双 ZA + 加载复用 | 1 | %s | %sx |\n' \
    "${paper_s1_median}" "$(speedup "${baseline_s1_median}" "${paper_s1_median}")"
  printf '| 双 ZA + 加载复用 | 2 | %s | %sx |\n' \
    "${paper_s2_median}" "$(speedup "${baseline_s2_median}" "${paper_s2_median}")"
  printf '| 单 ZA + 加载复用 | 1 | %s | %sx |\n' \
    "${single_za_s1_median}" "$(speedup "${baseline_s1_median}" "${single_za_s1_median}")"
  printf '| 单 ZA + 加载复用 | 2 | %s | %sx |\n' \
    "${single_za_s2_median}" "$(speedup "${baseline_s2_median}" "${single_za_s2_median}")"
  printf '| 双 ZA + 普通加载 | 1 | %s | %sx |\n' \
    "${no_reuse_s1_median}" "$(speedup "${baseline_s1_median}" "${no_reuse_s1_median}")"
  printf '| 双 ZA + 普通加载 | 2 | %s | %sx |\n' \
    "${no_reuse_s2_median}" "$(speedup "${baseline_s2_median}" "${no_reuse_s2_median}")"
fi
printf '\n日志与二进制目录：%s\n' "${build_dir}"
printf '提示：论文式程序会先执行一次小尺寸标量自检；该自检不包含在 Time: 中。\n'
