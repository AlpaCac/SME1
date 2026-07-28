#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
archive="${LLVM_ARCHIVE:-${script_dir}/llvm-project-19.1.7.src.tar.xz}"
source_dir="${LLVM_SOURCE_DIR:-${script_dir}/llvm-project-19.1.7.src}"
build_dir="${LLVM_BUILD_DIR:-${script_dir}/llvm-project-19.1.7.build}"
install_dir="${STANDALONE_LLVM_PREFIX:-${script_dir}/llvm-19.1.7}"
cmake_bin="${CMAKE:-cmake}"

find_tool() {
  command -v "$1" 2>/dev/null || true
}

for tool in tar xz make cc c++; do
  if [[ -z "$(find_tool "${tool}")" ]]; then
    printf 'missing required tool: %s\n' "${tool}" >&2
    exit 1
  fi
done
if [[ -z "$(find_tool "${cmake_bin}")" ]]; then
  printf 'missing cmake: %s\n' "${cmake_bin}" >&2
  exit 1
fi
if [[ ! -f "${archive}" ]]; then
  printf 'missing LLVM source archive: %s\n' "${archive}" >&2
  exit 1
fi

if [[ -z "${JOBS:-}" ]]; then
  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
else
  jobs="${JOBS}"
fi

if [[ ! -d "${source_dir}/llvm" ]]; then
  printf 'Extracting %s\n' "${archive}"
  tar -C "${script_dir}" -xf "${archive}"
fi
if [[ ! -d "${source_dir}/llvm" ]]; then
  printf 'missing extracted LLVM source directory: %s/llvm\n' "${source_dir}" >&2
  exit 1
fi

printf 'Configuring standalone LLVM in %s\n' "${build_dir}"
"${cmake_bin}" \
  -S "${source_dir}/llvm" \
  -B "${build_dir}" \
  -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${install_dir}" \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF

printf 'Building standalone LLVM with %s parallel job(s)\n' "${jobs}"
"${cmake_bin}" --build "${build_dir}" --parallel "${jobs}"

printf 'Installing standalone LLVM in %s\n' "${install_dir}"
"${cmake_bin}" --install "${build_dir}"

for file in \
  "${install_dir}/bin/clang" \
  "${install_dir}/bin/opt" \
  "${install_dir}/bin/llvm-config" \
  "${install_dir}/include/llvm/ADT/SmallVector.h" \
  "${install_dir}/lib/cmake/llvm/LLVMConfig.cmake"; do
  if [[ ! -f "${file}" ]]; then
    printf 'installation verification failed; missing: %s\n' "${file}" >&2
    exit 1
  fi
done

printf '\nStandalone LLVM installation completed.\n'
printf 'Version: '
"${install_dir}/bin/llvm-config" --version
printf 'Next command:\n'
printf 'export STANDALONE_LLVM=%q\n' "${install_dir}"
printf 'See 独立LLVM预取Pass部署教程.md section 4.\n'
