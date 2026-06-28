#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CERT_PATH="${IGNITE_SAMPLE_TLS_CERT:-${ROOT}/../_helper/testdata/tls/server-cert-a.pem}"
KEY_A_PKCS8="${ROOT}/../_helper/testdata/tls/server-key-a.pem"
KEY_B_PKCS8="${ROOT}/../_helper/testdata/tls/server-key-b.pem"
KEY_A_PKCS1="/tmp/ignite_h2_key_a_pkcs1.pem"
KEY_B_PKCS1="/tmp/ignite_h2_key_b_pkcs1.pem"

prepare_pkcs1() {
  openssl rsa -in "${KEY_A_PKCS8}" -out "${KEY_A_PKCS1}" >/dev/null 2>&1
  openssl rsa -in "${KEY_B_PKCS8}" -out "${KEY_B_PKCS1}" >/dev/null 2>&1
}

run_case() {
  local case_id="$1"
  local key_path="$2"
  local output

  set +e
  output="$(
    IGNITE_SAMPLE_SKIP_BUILD=1 \
    IGNITE_H2_TLS_GUARD_STAGES=legacy_key_decode \
    IGNITE_H2_TLS_GUARD_ONLY=1 \
    IGNITE_SAMPLE_TLS_CERT="${CERT_PATH}" \
    IGNITE_SAMPLE_TLS_KEY="${key_path}" \
    "${ROOT}/manual/samples/h2wire/probe.sh" 2>&1
  )"
  local exit_code=$?
  set -e

  if [[ "${exit_code}" == "0" ]]; then
    printf '[sample/h2wire] case=%s result=pass\n' "${case_id}"
    return 0
  fi

  local diagnosis="failed"
  if printf '%s' "${output}" | rg -q 'GeneralPrivateKey\.decodeFromPem|stdx\.crypto\.keys|legacy key decode'; then
    diagnosis="legacy-abort:GeneralPrivateKey.decodeFromPem"
  fi
  printf '[sample/h2wire] case=%s result=fail diagnosis=%s\n' "${case_id}" "${diagnosis}"
  return 0
}

main() {
  prepare_pkcs1

  run_case "key-a:pkcs8" "${KEY_A_PKCS8}"
  run_case "key-b:pkcs8" "${KEY_B_PKCS8}"
  run_case "key-a:pkcs1" "${KEY_A_PKCS1}"
  run_case "key-b:pkcs1" "${KEY_B_PKCS1}"
}

main "$@"
