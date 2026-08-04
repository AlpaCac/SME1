#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STENCIL_SKIP_CORRECTNESS=1 \
STENCIL_WARMUPS=0 \
STENCIL_SAMPLES=3 \
STENCIL_CPU=0 \
STENCIL_TIMEOUT_SECONDS=1800 \
  "${script_dir}/03_validate_server_runtime.sh"
