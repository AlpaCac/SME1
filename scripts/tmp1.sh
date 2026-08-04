#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "${repo_root}"

: "${BISHENG_CXX:?set BISHENG_CXX to the BiSheng clang++ executable}"

# One sample checks the pipeline and correctness, not performance stability.
BISHENG_CXX="${BISHENG_CXX}" \
STENCIL_CPU=0 \
STENCIL_TIMEOUT_SECONDS=1800 \
STENCIL_FINAL_WARMUPS=0 \
STENCIL_FINAL_SAMPLES=1 \
STENCIL_VALIDATE_MIN_SPEEDUP=0 \
STENCIL_VALIDATE_MAX_RELATIVE_MAD=1 \
  ./scripts/05_validate_tuned_profile.sh
