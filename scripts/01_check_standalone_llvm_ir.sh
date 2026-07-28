#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
standalone_llvm="${STANDALONE_LLVM:-${repo_root}/tools/llvm-19.1.7}"
input_ir="${STENCIL_FULL_IR:-${repo_root}/01_llvm_ir_analysis/output/stencil_all_sme.full.ll}"
opt_bin="${standalone_llvm}/bin/opt"

if [[ ! -x "${opt_bin}" ]]; then
  printf 'missing standalone opt: %s\n' "${opt_bin}" >&2
  printf 'run ./tools/install_standalone_llvm.sh first.\n' >&2
  exit 1
fi
if [[ ! -f "${input_ir}" ]]; then
  printf 'missing full LLVM IR: %s\n' "${input_ir}" >&2
  printf 'run ./01_llvm_ir_analysis/generate_and_check.sh with BiSheng first.\n' >&2
  exit 1
fi

"${opt_bin}" -disable-output "${input_ir}"
printf 'Standalone opt accepted BiSheng IR: %s\n' "${input_ir}"
