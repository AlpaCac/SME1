#!/usr/bin/env bash

set -euo pipefail

key_file="${1:-${HOME}/.ssh/sme2_deploy_key.puh}"
expected_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClPaWegdT1ec0VZ5wfATBTjecGFCdhBhpTMs0EBsU3J server-pull-sme2'

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if [[ ! -f "${key_file}" ]]; then
  printf '找不到公钥文件：%s\n' "${key_file}" >&2
  if [[ "${key_file}" == *.puh ]]; then
    candidate="${key_file%.puh}.pub"
    if [[ -f "${candidate}" ]]; then
      printf '发现可能的正确路径：%s\n' "${candidate}" >&2
      printf '请执行：%q %q\n' "$0" "${candidate}" >&2
    else
      printf '请确认后缀是否应为 .pub，或将实际路径作为第一个参数传入。\n' >&2
    fi
  fi
  exit 2
fi

first_line="$(awk 'NF { print; exit }' "${key_file}")"
[[ -n "${first_line}" ]] || die "公钥文件为空"

if [[ "${first_line}" == *"PRIVATE KEY"* ]]; then
  die "路径指向私钥；请改为对应的 .pub 公钥文件"
fi

read -r actual_type actual_body actual_comment_extra <<< "${first_line}"
read -r expected_type expected_body expected_comment_extra <<< "${expected_key}"
actual_comment="${first_line#"${actual_type} ${actual_body}"}"
expected_comment="${expected_key#"${expected_type} ${expected_body}"}"
actual_comment="${actual_comment# }"
expected_comment="${expected_comment# }"

type_same=0
body_same=0
comment_same=0
[[ "${actual_type}" == "${expected_type}" ]] && type_same=1
[[ "${actual_body}" == "${expected_body}" ]] && body_same=1
[[ "${actual_comment}" == "${expected_comment}" ]] && comment_same=1

printf '文件：%s\n' "${key_file}"
printf '密钥类型：%s\n' "$([[ ${type_same} == 1 ]] && printf '相同 (%s)' "${actual_type}" || printf '不同：文件=%s，期望=%s' "${actual_type}" "${expected_type}")"
printf '公钥主体：%s\n' "$([[ ${body_same} == 1 ]] && printf '相同' || printf '不同')"
printf '注释：%s\n' "$([[ ${comment_same} == 1 ]] && printf '相同 (%s)' "${actual_comment}" || printf '不同：文件=%s，期望=%s' "${actual_comment:-<空>}" "${expected_comment:-<空>}")"

if [[ ${type_same} == 1 && ${body_same} == 1 ]]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    fingerprint="$(printf '%s %s\n' "${actual_type}" "${actual_body}" | ssh-keygen -lf - 2>/dev/null || true)"
    [[ -z "${fingerprint}" ]] || printf '指纹：%s\n' "${fingerprint}"
  fi
  if [[ ${comment_same} == 1 ]]; then
    printf '结论：两行内容完全相同。\n'
    exit 0
  fi
  printf '结论：公钥本身相同，仅注释不同。\n'
  exit 0
fi

printf '结论：公钥不同，不应视为同一把部署密钥。\n'
exit 1
