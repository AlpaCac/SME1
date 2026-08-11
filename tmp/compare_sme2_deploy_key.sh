#!/usr/bin/env bash

set -euo pipefail

key_file="${1:-${HOME}/.ssh/sme2_deploy_key.pub}"
expected_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClPaWegdT1ec0VZ5wfATBTjecGFCdhBhpTMs0EBsU3J server-pull-sme2'

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if [[ ! -f "${key_file}" ]]; then
  printf '找不到公钥文件：%s\n' "${key_file}" >&2
  printf '也可以将实际公钥路径作为第一个参数传入。\n' >&2
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

fingerprint() {
  local key_type="$1"
  local key_body="$2"
  local result
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    printf '<ssh-keygen 不可用>'
    return
  fi
  result="$(printf '%s %s\n' "${key_type}" "${key_body}" | \
    ssh-keygen -lf - -E sha256 2>/dev/null || true)"
  if [[ -z "${result}" ]]; then
    printf '<无法计算，公钥编码可能无效>'
  else
    printf '%s' "${result}"
  fi
}

first_difference() {
  local actual="$1"
  local expected="$2"
  local shorter_length index
  if ((${#actual} < ${#expected})); then
    shorter_length=${#actual}
  else
    shorter_length=${#expected}
  fi
  for ((index = 0; index < shorter_length; ++index)); do
    if [[ "${actual:index:1}" != "${expected:index:1}" ]]; then
      printf '%d' "$((index + 1))"
      return
    fi
  done
  printf '%d' "$((shorter_length + 1))"
}

printf '文件：%s\n' "${key_file}"
printf '密钥类型：%s\n' "$([[ ${type_same} == 1 ]] && printf '相同 (%s)' "${actual_type}" || printf '不同：文件=%s，期望=%s' "${actual_type}" "${expected_type}")"
printf '公钥主体：%s\n' "$([[ ${body_same} == 1 ]] && printf '相同' || printf '不同')"
printf '注释：%s\n' "$([[ ${comment_same} == 1 ]] && printf '相同 (%s)' "${actual_comment}" || printf '不同：文件=%s，期望=%s' "${actual_comment:-<空>}" "${expected_comment:-<空>}")"

if [[ ${body_same} != 1 ]]; then
  difference_position="$(first_difference "${actual_body}" "${expected_body}")"
  actual_character="${actual_body:difference_position-1:1}"
  expected_character="${expected_body:difference_position-1:1}"
  printf '主体长度：文件=%d，期望=%d\n' "${#actual_body}" "${#expected_body}"
  printf '首个差异：Base64 第 %d 个字符，文件=%s，期望=%s\n' \
    "${difference_position}" "${actual_character:-<结束>}" \
    "${expected_character:-<结束>}"
  printf '文件指纹：%s\n' "$(fingerprint "${actual_type}" "${actual_body}")"
  printf '期望指纹：%s\n' "$(fingerprint "${expected_type}" "${expected_body}")"
fi

if [[ ${type_same} == 1 && ${body_same} == 1 ]]; then
  printf '指纹：%s\n' "$(fingerprint "${actual_type}" "${actual_body}")"
  if [[ ${comment_same} == 1 ]]; then
    printf '结论：两行内容完全相同。\n'
    exit 0
  fi
  printf '结论：公钥本身相同，仅注释不同。\n'
  exit 0
fi

printf '结论：公钥不同，不应视为同一把部署密钥。\n'
exit 1
