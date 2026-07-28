#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
standalone_llvm="${STANDALONE_LLVM:-${repo_root}/tools/llvm-19.1.7}"

for tool in llvm-config clang clang++; do
  if [[ ! -x "${standalone_llvm}/bin/${tool}" ]]; then
    printf 'missing standalone LLVM tool: %s\n' \
      "${standalone_llvm}/bin/${tool}" >&2
    printf 'run ./tools/install_standalone_llvm.sh first.\n' >&2
    exit 1
  fi
done

LLVM_CONFIG="${standalone_llvm}/bin/llvm-config" \
LLVM_CLANG="${standalone_llvm}/bin/clang" \
PLUGIN_CC="${standalone_llvm}/bin/clang" \
PLUGIN_CXX="${standalone_llvm}/bin/clang++" \
CMAKE_GENERATOR="Unix Makefiles" \
  "${repo_root}/02_llvm_pass_plugin/build_and_test.sh"
