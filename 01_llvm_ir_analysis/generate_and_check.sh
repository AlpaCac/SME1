#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
output_dir="${script_dir}/output"
ir_file="${output_dir}/stencil_sme_kernels.ll"
report_file="${output_dir}/analysis_report.md"

clang_bin="${CLANG:-clang}"
target="${TARGET:-arm64-apple-macos15}"
march="${MARCH:-armv9.2-a+sme+sve2}"

mkdir -p "${output_dir}"

(
  cd "${repo_root}"
  "${clang_bin}" \
    -target "${target}" \
    -march="${march}" \
    -O1 -S -emit-llvm \
    stencil_sme_kernels.c \
    -o "${ir_file}"
)

clang_version="$("${clang_bin}" --version | head -n 1)"

python3 "${script_dir}/check_ir.py" \
  --ir "${ir_file}" \
  --report "${report_file}" \
  --clang-version "${clang_version}" \
  --target "${target}" \
  --march "${march}"

printf 'LLVM IR: %s\n' "${ir_file}"
printf 'Report:  %s\n' "${report_file}"
