#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

EXPECTED_PREFETCH_COUNT="${EXPECTED_PREFETCH_COUNT-29}" \
  "${repo_root}/05_runtime_validation/run_server_module.sh"
