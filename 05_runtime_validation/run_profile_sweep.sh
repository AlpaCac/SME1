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
  printf 'Profile sweep requires detected SME support.\n'
  exit 0
fi

assembly_flags=(-O3 -march=armv9.2-a+nosve+sme+sme-f64f64)
host_flags=(-O3)
if [[ "$(uname -s)" == "Darwin" ]]; then
  macos_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  assembly_flags+=(-isysroot "${macos_sdk}")
  host_flags+=(-isysroot "${macos_sdk}")
fi

rename_baseline() {
  source="${repo_root}/02_llvm_pass_plugin/output/stencil_kernels.baseline.s"
  renamed="${build_dir}/profile_sweep.baseline.s"
  sed \
    -e 's/stencil_2d5p_sme_f32/baseline_stencil_2d5p_sme_f32/g' \
    -e 's/stencil_3d7p_sme_f32/baseline_stencil_3d7p_sme_f32/g' \
    "${source}" > "${renamed}"
  "${runtime_clang}" "${assembly_flags[@]}" \
    -c "${renamed}" \
    -o "${build_dir}/profile_sweep.baseline.o"
}

generate_variant() {
  name="$1"
  shift
  variant_ir="${build_dir}/profile_sweep.${name}.ll"
  variant_assembly="${build_dir}/profile_sweep.${name}.s"
  renamed_assembly="${build_dir}/profile_sweep.${name}-renamed.s"

  env "$@" "${llvm_clang}" \
    -x ir -O1 -S -emit-llvm -Wno-override-module \
    -fpass-plugin="${plugin}" \
    "${kernel_ir}" \
    -o "${variant_ir}" \
    2> "${output_dir}/profile_sweep_${name}_decision.log"
  "${llvm_clang}" \
    -x ir -O1 -S -Wno-override-module \
    "${variant_ir}" \
    -o "${variant_assembly}"
  sed \
    -e 's/stencil_2d5p_sme_f32/prefetch_stencil_2d5p_sme_f32/g' \
    -e 's/stencil_3d7p_sme_f32/prefetch_stencil_3d7p_sme_f32/g' \
    "${variant_assembly}" > "${renamed_assembly}"
  "${runtime_clang}" "${assembly_flags[@]}" \
    -c "${renamed_assembly}" \
    -o "${build_dir}/profile_sweep.${name}.o"
  "${runtime_clang}" "${host_flags[@]}" \
    "${build_dir}/profile_sweep.baseline.o" \
    "${build_dir}/profile_sweep.${name}.o" \
    "${build_dir}/profile_sweep.driver.o" \
    -o "${build_dir}/profile_sweep.${name}"
}

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
  printf '%s\n' "$@" | sort -n | \
    awk '{ values[NR] = $1 } END { print values[int((NR + 1) / 2)] }'
}

range() {
  printf '%s\n' "$@" | sort -n | \
    awk 'NR == 1 { minimum = $1 } { maximum = $1 }
         END { printf "%s-%s", minimum, maximum }'
}

run_variant() {
  name="$1"
  kernel="$2"
  tag="${3:-default}"
  values=()
  for ((round = 1; round <= rounds; ++round)); do
    log="${output_dir}/profile_sweep_${name}_${tag}_round_${round}.log"
    if [[ "${kernel}" == "2d" ]]; then
      "${build_dir}/profile_sweep.${name}" \
        2d "${height_2d}" "${width_2d}" "${repetitions}" "${samples}" \
        > "${log}"
    else
      "${build_dir}/profile_sweep.${name}" \
        3d "${depth_3d}" "${height_3d}" "${width_3d}" \
        "${repetitions}" "${samples}" \
        > "${log}"
    fi
    baseline_checksum="$(field baseline_checksum "${log}")"
    prefetch_checksum="$(field prefetch_checksum "${log}")"
    if [[ "${baseline_checksum}" != "${prefetch_checksum}" ]]; then
      printf 'profile sweep checksum mismatch: %s round %s\n' \
        "${name}" "${round}" >&2
      exit 1
    fi
    values+=("$(field paired_speedup "${log}")")
  done
  profile_median="$(median "${values[@]}")"
  profile_range="$(range "${values[@]}")"
  printf '%s %s\n' "${profile_median}" "${profile_range}"
}

rename_baseline
"${runtime_clang}" "${host_flags[@]}" \
  -c "${script_dir}/stencil_paired_benchmark.c" \
  -o "${build_dir}/profile_sweep.driver.o"

height_2d="${STENCIL_2D_HEIGHT:-16384}"
width_2d="${STENCIL_2D_WIDTH:-1024}"
depth_3d="${STENCIL_3D_DEPTH:-512}"
height_3d="${STENCIL_3D_HEIGHT:-32}"
width_3d="${STENCIL_3D_WIDTH:-1024}"
repetitions="${STENCIL_REPETITIONS:-6}"
samples="${STENCIL_SAMPLES:-7}"
rounds="${STENCIL_ROUNDS:-3}"

distances=(1 2 4 8)
useful_cycles=(32 16 8 4)

for index in "${!distances[@]}"; do
  distance="${distances[index]}"
  useful="${useful_cycles[index]}"
  generate_variant "2d_row_d${distance}" \
    "SME_PREFETCH_USEFUL_CYCLES_2D=${useful}"
  read -r result_2d_median[index] result_2d_range[index] < <(
    run_variant "2d_row_d${distance}" 2d primary)

  generate_variant "3d_plane_l1_d${distance}" \
    "SME_PREFETCH_ENABLE_ROW_L1=0" \
    "SME_PREFETCH_ENABLE_PLANE_L2=0" \
    "SME_PREFETCH_USEFUL_CYCLES_3D=${useful}"
  read -r result_3d_median[index] result_3d_range[index] < <(
    run_variant "3d_plane_l1_d${distance}" 3d primary)
done

cross_2d_widths=(256 1024 4096)
cross_2d_heights=(65536 16384 4096)
for index in "${!cross_2d_widths[@]}"; do
  width_2d="${cross_2d_widths[index]}"
  height_2d="${cross_2d_heights[index]}"
  read -r cross_2d_d4_median[index] cross_2d_d4_range[index] < <(
    run_variant 2d_row_d4 2d "width_${width_2d}")
  read -r cross_2d_d8_median[index] cross_2d_d8_range[index] < <(
    run_variant 2d_row_d8 2d "width_${width_2d}")
done
height_2d="${STENCIL_2D_HEIGHT:-16384}"
width_2d="${STENCIL_2D_WIDTH:-1024}"

cross_3d_depths=(1024 512 256)
cross_3d_heights=(16 32 64)
cross_3d_plane_kib=(64 128 256)
for index in "${!cross_3d_depths[@]}"; do
  depth_3d="${cross_3d_depths[index]}"
  height_3d="${cross_3d_heights[index]}"
  read -r cross_3d_d1_median[index] cross_3d_d1_range[index] < <(
    run_variant 3d_plane_l1_d1 3d "plane_${cross_3d_plane_kib[index]}k")
  read -r cross_3d_d2_median[index] cross_3d_d2_range[index] < <(
    run_variant 3d_plane_l1_d2 3d "plane_${cross_3d_plane_kib[index]}k")
done
depth_3d="${STENCIL_3D_DEPTH:-512}"
height_3d="${STENCIL_3D_HEIGHT:-32}"

{
  printf '# 预取距离扫描\n\n'
  printf -- '- 可比性：同一 kernel-only LLVM IR、`-O1` 管线和同进程配对执行\n'
  printf -- '- 重复次数/样本数/外层轮数：`%s / %s / %s`\n' \
    "${repetitions}" "${samples}" "${rounds}"
  printf -- '- 2D 规模：`%sx%s`\n' "${height_2d}" "${width_2d}"
  printf -- '- 3D 规模：`%sx%sx%s`\n\n' \
    "${depth_3d}" "${height_3d}" "${width_3d}"
  printf '## 2D row-L1 KEEP\n\n'
  printf '| 距离 | 配对加速比中位数 | 轮间范围 |\n'
  printf '|---:|---:|---:|\n'
  for index in "${!distances[@]}"; do
    printf '| %s | %sx | %sx |\n' \
      "${distances[index]}" "${result_2d_median[index]}" \
      "${result_2d_range[index]}"
  done
  printf '\n## 3D plane-L1 STRM only\n\n'
  printf '| 距离 | 配对加速比中位数 | 轮间范围 |\n'
  printf '|---:|---:|---:|\n'
  for index in "${!distances[@]}"; do
    printf '| %s | %sx | %sx |\n' \
      "${distances[index]}" "${result_3d_median[index]}" \
      "${result_3d_range[index]}"
  done
  printf '\n## 跨尺寸复测：2D\n\n'
  printf '| row 字节数 | 距离 4 | 距离 8 |\n'
  printf '|---:|---:|---:|\n'
  for index in "${!cross_2d_widths[@]}"; do
    row_bytes="$((cross_2d_widths[index] * 4))"
    printf '| %s | %sx | %sx |\n' \
      "${row_bytes}" "${cross_2d_d4_median[index]}" \
      "${cross_2d_d8_median[index]}"
  done
  printf '\n## 跨尺寸复测：3D plane-L1 STRM only\n\n'
  printf '| plane 大小 | 距离 1 | 距离 2 |\n'
  printf '|---:|---:|---:|\n'
  for index in "${!cross_3d_plane_kib[@]}"; do
    printf '| %s KiB | %sx | %sx |\n' \
      "${cross_3d_plane_kib[index]}" "${cross_3d_d1_median[index]}" \
      "${cross_3d_d2_median[index]}"
  done
  printf '\n扫描只用于筛选候选。最终 Profile 还必须结合 PMU 结果，'
  printf '排除 cache 污染和过晚预取。\n'
} > "${output_dir}/profile_sweep_report.md"

cat "${output_dir}/profile_sweep_report.md"
