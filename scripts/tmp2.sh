#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "${repo_root}"

: "${BISHENG_CXX:?set BISHENG_CXX to the BiSheng clang++ executable}"

BISHENG_CXX="${BISHENG_CXX}" \
STENCIL_CPU=0 \
STENCIL_TIMEOUT_SECONDS=1800 \
STENCIL_TUNE_WARMUPS=1 \
STENCIL_TUNE_SAMPLES=3 \
STENCIL_TUNE_RESUME=0 \
  ./scripts/04_tune_server_profile.sh
