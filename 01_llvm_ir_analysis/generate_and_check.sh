#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
output_dir="${script_dir}/output"

clang_bin="${CLANG:-clang}"
source_file="${STENCIL_SOURCE:-${repo_root}/stencil_all_sme.cpp}"
kernel_pattern="${STENCIL_KERNEL_PATTERN:-^stencil(_|[0-9])}"
kernel_functions="${STENCIL_KERNEL_FUNCTIONS:-}"
target="${TARGET:-aarch64-unknown-linux-gnu}"
march="${MARCH:-armv9.2-a+sme+sve2+sme-f64f64}"

if [[ ! -f "${source_file}" ]]; then
  printf 'missing stencil source: %s\n' "${source_file}" >&2
  printf 'copy the server-local source into this path or set STENCIL_SOURCE.\n' >&2
  exit 1
fi

clang_path="$(command -v "${clang_bin}" || true)"
if [[ -z "${clang_path}" ]]; then
  printf 'missing clang: %s\n' "${clang_bin}" >&2
  exit 1
fi
llvm_extract="${LLVM_EXTRACT:-$(dirname "${clang_path}")/llvm-extract}"
if [[ ! -x "${llvm_extract}" ]]; then
  printf 'missing llvm-extract: %s\n' "${llvm_extract}" >&2
  exit 1
fi
if [[ -n "${LLVM_CXXFILT:-}" ]]; then
  llvm_cxxfilt="${LLVM_CXXFILT}"
elif [[ -x "$(dirname "${clang_path}")/llvm-cxxfilt" ]]; then
  llvm_cxxfilt="$(dirname "${clang_path}")/llvm-cxxfilt"
else
  llvm_cxxfilt="$(command -v c++filt || true)"
fi
if [[ -z "${llvm_cxxfilt}" || ! -x "${llvm_cxxfilt}" ]]; then
  printf 'missing C++ demangler; install llvm-cxxfilt or c++filt.\n' >&2
  exit 1
fi

source_name="$(basename "${source_file}")"
source_stem="${source_name%.*}"
full_ir="${output_dir}/${source_stem}.full.ll"
kernel_ir="${output_dir}/${source_stem}.kernels.ll"
report_file="${output_dir}/analysis_report.md"

mkdir -p "${output_dir}"

"${clang_path}" \
  -target "${target}" \
  -march="${march}" \
  -O1 -S -emit-llvm \
  "${source_file}" \
  -o "${full_ir}"

# The input translation unit also contains test helpers and main. Match the
# original IR symbol and its C++-demangled spelling so C++ kernels such as
# stencil1D_3point_sme() are discovered as well as C ABI stencil_* functions.
# A comma-separated STENCIL_KERNEL_FUNCTIONS list overrides automatic discovery.
if [[ -n "${kernel_functions}" ]]; then
  IFS=',' read -r -a selected_functions <<< "${kernel_functions}"
else
  selected_functions=()
  while IFS= read -r function; do
    demangled="$(printf '%s\n' "${function}" | "${llvm_cxxfilt}")"
    if [[ "${function}" =~ ${kernel_pattern} || "${demangled}" =~ ${kernel_pattern} ]]; then
      selected_functions+=("${function}")
    fi
  done < <(sed -n 's/^define .* @\\([^ (]*\\)(.*/\\1/p' "${full_ir}")
fi
if [[ "${#selected_functions[@]}" -eq 0 ]]; then
  printf 'no kernel functions found; set STENCIL_KERNEL_FUNCTIONS explicitly.\n' >&2
  exit 1
fi

extract_args=()
for function in "${selected_functions[@]}"; do
  if [[ -z "${function}" ]]; then
    continue
  fi
  extract_args+=("--func=${function}")
done
if [[ "${#extract_args[@]}" -eq 0 ]]; then
  printf 'STENCIL_KERNEL_FUNCTIONS did not contain a function name.\n' >&2
  exit 1
fi
"${llvm_extract}" "${extract_args[@]}" -S "${full_ir}" -o "${kernel_ir}"

clang_version="$("${clang_path}" --version | head -n 1)"

python3 "${script_dir}/check_ir.py" \
  --ir "${kernel_ir}" \
  --full-ir "${full_ir}" \
  --source "${source_file}" \
  --report "${report_file}" \
  --clang-version "${clang_version}" \
  --target "${target}" \
  --march "${march}" \
  --functions "${selected_functions[@]}"

printf 'Full LLVM IR:   %s\n' "${full_ir}"
printf 'Kernel-only IR: %s\n' "${kernel_ir}"
printf 'Report:         %s\n' "${report_file}"
