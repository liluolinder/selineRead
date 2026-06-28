#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
H2SPEC_BIN="${IGNITE_H2SPEC_BIN:-$(command -v h2spec || true)}"
H2SPEC_DISPLAY_BIN="${H2SPEC_BIN:-h2spec}"
HOST="${IGNITE_H2SPEC_HOST:-127.0.0.1}"
PORT="${IGNITE_H2SPEC_PORT:-18444}"
TARGET_PATH="${IGNITE_H2SPEC_PATH:-/}"
SPECS_RAW="${IGNITE_H2SPEC_SPECS:-generic}"
PREPARE_ONLY="${IGNITE_H2SPEC_PREPARE_ONLY:-0}"
SKIP_GUARD="${IGNITE_H2SPEC_SKIP_GUARD:-0}"
STRICT_MODE="${IGNITE_H2SPEC_STRICT:-0}"
DRYRUN_MODE="${IGNITE_H2SPEC_DRYRUN:-0}"
SERVER_LOG="/tmp/ignite_sample_h2wire_h2spec.log"
H2SPEC_CMD=()

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

assemble_h2spec_cmd() {
  H2SPEC_CMD=("${H2SPEC_DISPLAY_BIN}" -h "${HOST}" -p "${PORT}" -t -k -P "${TARGET_PATH}")
  if [[ "${STRICT_MODE}" == "1" ]]; then
    H2SPEC_CMD+=(--strict)
  fi
  if [[ "${DRYRUN_MODE}" == "1" ]]; then
    H2SPEC_CMD+=(--dryrun)
  fi

  IFS=' ' read -r -a specs <<<"${SPECS_RAW}"
  for spec in "${specs[@]}"; do
    if [[ -n "${spec}" ]]; then
      H2SPEC_CMD+=("${spec}")
    fi
  done
}

print_prepare_summary() {
  assemble_h2spec_cmd
  printf '[sample/h2wire] prepare-only summary\n'
  printf '[sample/h2wire] guard-first=%s host=%s port=%s path=%s specs=%s\n' \
    "$([[ "${SKIP_GUARD}" == "1" ]] && printf 'no' || printf 'yes')" \
    "${HOST}" "${PORT}" "${TARGET_PATH}" "${SPECS_RAW}"
  printf '[sample/h2wire] h2spec command:'
  printf ' %q' "${H2SPEC_CMD[@]}"
  printf '\n'
}

if [[ "${PREPARE_ONLY}" == "1" ]]; then
  print_prepare_summary
  exit 0
fi

if [[ -z "${H2SPEC_BIN}" ]]; then
  echo "[sample/h2wire] h2spec is required for this smoke path." >&2
  echo "[sample/h2wire] install h2spec and re-run, or set IGNITE_H2SPEC_PREPARE_ONLY=1 to inspect the staged command." >&2
  exit 1
fi

if [[ "${SKIP_GUARD}" != "1" ]]; then
  IGNITE_H2_TLS_GUARD_ONLY=1 "${ROOT}/manual/samples/h2wire/probe.sh"
fi

IGNITE_SAMPLE_SKIP_BUILD=1 "${ROOT}/manual/samples/h2wire/run.sh" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"

ready=0
for _ in $(seq 1 50); do
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "[sample/h2wire] server exited before h2spec could connect." >&2
    echo "[sample/h2wire] inspect ${SERVER_LOG}" >&2
    sed -n '1,160p' "${SERVER_LOG}" >&2
    exit 1
  fi
  if curl -k --http2 --silent --fail "https://${HOST}:${PORT}${TARGET_PATH}" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.1
done

if [[ "${ready}" != "1" ]]; then
  echo "[sample/h2wire] target path never became ready for h2spec." >&2
  echo "[sample/h2wire] inspect ${SERVER_LOG}" >&2
  sed -n '1,160p' "${SERVER_LOG}" >&2
  exit 1
fi

assemble_h2spec_cmd
"${H2SPEC_CMD[@]}"

echo "[sample/h2wire] h2spec smoke passed. server log: ${SERVER_LOG}"
