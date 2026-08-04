#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
profile_file="${STENCIL_PROFILE_FILE:-${repo_root}/profiles/server-sme.env}"

if [[ ! -f "${profile_file}" ]]; then
  printf 'missing tuned profile: %s\n' "${profile_file}" >&2
  printf 'run ./scripts/04_tune_server_profile.sh first.\n' >&2
  exit 1
fi
if grep -Ev '^(#.*|[[:space:]]*|export SME_PREFETCH_[A-Z0-9_]+=[A-Za-z0-9._-]+)$' \
    "${profile_file}" | grep -q .; then
  printf 'tuned profile contains an unsupported line: %s\n' \
    "${profile_file}" >&2
  exit 1
fi

# The generated file contains only export assignments for SME_PREFETCH_*.
# shellcheck disable=SC1090
source "${profile_file}"

EXPECTED_PREFETCH_COUNT= \
STENCIL_ALLOW_ZERO_PREFETCH=1 \
STENCIL_RUNTIME_BUILD_DIR="${STENCIL_FINAL_BUILD_DIR:-${repo_root}/05_runtime_validation/build/server-profile-final}" \
STENCIL_RUNTIME_OUTPUT_DIR="${STENCIL_FINAL_OUTPUT_DIR:-${repo_root}/05_runtime_validation/output/server-profile-final}" \
STENCIL_SINGLE_RUN=0 \
STENCIL_WARMUPS="${STENCIL_FINAL_WARMUPS:-2}" \
STENCIL_SAMPLES="${STENCIL_FINAL_SAMPLES:-7}" \
  "${script_dir}/03_validate_server_runtime.sh"
