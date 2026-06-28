#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SERVER_BIN="/tmp/ignite_sample_h2wire"
SERVER_LOG="/tmp/ignite_sample_h2wire.log"
TLS_GUARD_BIN="/tmp/ignite_sample_h2wire_tls_guard"
TLS_GUARD_LOG_ROOT="/tmp/ignite_sample_h2wire_tls_guard"
VERIFY_SCRIPT="${ROOT}/manual/samples/h2wire/verify_http2.mjs"
GUARD_STAGES_RAW="${IGNITE_H2_TLS_GUARD_STAGES:-precheck,cert_decode,mainline_build}"
GUARD_ONLY="${IGNITE_H2_TLS_GUARD_ONLY:-0}"
READY_MARKER="[sample/h2wire] listening on https://127.0.0.1:18444"

ensure_cangjie_env() {
  if ! command -v cjpm >/dev/null 2>&1 || ! command -v cjc >/dev/null 2>&1; then
    local envsetup=""
    if [[ -n "${IGNITE_CANGJIE_HOME:-}" && -f "${IGNITE_CANGJIE_HOME}/envsetup.sh" ]]; then
      envsetup="${IGNITE_CANGJIE_HOME}/envsetup.sh"
    elif [[ -n "${CANGJIE_HOME:-}" && -f "${CANGJIE_HOME}/envsetup.sh" ]]; then
      envsetup="${CANGJIE_HOME}/envsetup.sh"
    elif [[ -f "/Library/Frameworks/Cangjie/1.1.0-nightly/envsetup.sh" ]]; then
      envsetup="/Library/Frameworks/Cangjie/1.1.0-nightly/envsetup.sh"
    fi

    if [[ -n "${envsetup}" ]]; then
      export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-}"
      # shellcheck disable=SC1090
      source "${envsetup}"
    fi
  fi

  if [[ -z "${SDKROOT:-}" ]] && command -v xcrun >/dev/null 2>&1; then
    export SDKROOT
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  fi

  if [[ -z "${CANGJIE_STDX_PATH:-}" && -d "/Library/Frameworks/Cangjie/stdx_Build" ]]; then
    export CANGJIE_STDX_PATH="/Library/Frameworks/Cangjie/stdx_Build"
  fi
}

detect_stdx_static() {
  if [[ -n "${IGNITE_STDX_STATIC:-}" && -d "${IGNITE_STDX_STATIC}" ]]; then
    printf '%s\n' "${IGNITE_STDX_STATIC}"
    return 0
  fi

  if [[ -n "${CANGJIE_STDX_PATH:-}" && -d "${CANGJIE_STDX_PATH}" ]]; then
    local hit
    hit="$(find "${CANGJIE_STDX_PATH}" -maxdepth 4 -type d -path "*/cj_stdx_*_llvm/static" | head -n 1)"
    if [[ -n "${hit}" ]]; then
      printf '%s\n' "${hit}"
      return 0
    fi
  fi

  return 1
}

detect_runtime_lib_dir() {
  if [[ -n "${IGNITE_CJ_RUNTIME_LIB_DIR:-}" && -d "${IGNITE_CJ_RUNTIME_LIB_DIR}" ]]; then
    printf '%s\n' "${IGNITE_CJ_RUNTIME_LIB_DIR}"
    return 0
  fi

  if [[ -n "${CANGJIE_HOME:-}" && -d "${CANGJIE_HOME}/runtime/lib" ]]; then
    local hit
    hit="$(find "${CANGJIE_HOME}/runtime/lib" -maxdepth 3 -type f -name "libcangjie-runtime.*" | head -n 1)"
    if [[ -n "${hit}" ]]; then
      dirname "${hit}"
      return 0
    fi
  fi

  return 1
}

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

print_server_log_excerpt() {
  echo "[sample/h2wire] inspect ${SERVER_LOG}" >&2
  sed -n '1,200p' "${SERVER_LOG}" >&2
}

startup_failure_kind() {
  if [[ -f "${SERVER_LOG}" ]] && grep -Fq "LISTEN_PERMISSION_DENIED" "${SERVER_LOG}"; then
    printf '%s\n' "listen_permission_denied"
    return 0
  fi
  printf '%s\n' "generic_startup_failure"
}

if ! command -v node >/dev/null 2>&1; then
  echo "[sample/h2wire] node is required for the built-in HTTP/2 probe." >&2
  exit 1
fi

if [[ -z "${IGNITE_SAMPLE_TLS_CERT:-}" && -f "${ROOT}/../_helper/testdata/tls/server-cert-a.pem" ]]; then
  export IGNITE_SAMPLE_TLS_CERT="${ROOT}/../_helper/testdata/tls/server-cert-a.pem"
fi
if [[ -z "${IGNITE_SAMPLE_TLS_KEY:-}" && -f "${ROOT}/../_helper/testdata/tls/server-key-a.pem" ]]; then
  export IGNITE_SAMPLE_TLS_KEY="${ROOT}/../_helper/testdata/tls/server-key-a.pem"
fi

ensure_cangjie_env

IGNITE_SAMPLE_COMPILE_ONLY=1 "${ROOT}/manual/samples/_shared/run_server_sample.sh" "manual/samples/h2wire/main.cj" "${SERVER_BIN}"
IGNITE_SAMPLE_SKIP_BUILD=1 IGNITE_SAMPLE_COMPILE_ONLY=1 \
  "${ROOT}/manual/samples/_shared/run_server_sample.sh" \
  "manual/samples/h2wire/tls_guard.cj" \
  "${TLS_GUARD_BIN}"

STDX_STATIC="$(detect_stdx_static || true)"
if [[ -z "${STDX_STATIC}" ]]; then
  echo "[sample/h2wire] cannot locate stdx static path." >&2
  exit 1
fi

RUNTIME_LIB_DIR="$(detect_runtime_lib_dir || true)"
if [[ -z "${RUNTIME_LIB_DIR}" ]]; then
  echo "[sample/h2wire] cannot locate Cangjie runtime lib dir." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${DYLD_LIBRARY_PATH:-}"
    ;;
  Linux)
    export LD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${LD_LIBRARY_PATH:-}"
    ;;
esac

run_guard_stage() {
  local stage="$1"
  local log_path="${TLS_GUARD_LOG_ROOT}_${stage}.log"
  if ! IGNITE_H2_TLS_GUARD_STAGE="${stage}" "${TLS_GUARD_BIN}" >"${log_path}" 2>&1; then
    echo "[sample/h2wire] isolated TLS guard failed at stage=${stage} before server launch." >&2
    echo "[sample/h2wire] inspect ${log_path}" >&2
    sed -n '1,160p' "${log_path}" >&2
    return 1
  fi
}

if [[ "${IGNITE_H2_SKIP_GUARD:-0}" != "1" ]]; then
  IFS=',' read -r -a guard_stages <<<"${GUARD_STAGES_RAW}"
  for stage in "${guard_stages[@]}"; do
    trimmed_stage="$(printf '%s' "${stage}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    if [[ -z "${trimmed_stage}" ]]; then
      continue
    fi
    run_guard_stage "${trimmed_stage}"
  done
fi

if [[ "${IGNITE_H2_SKIP_GUARD:-0}" == "1" ]]; then
  echo "[sample/h2wire] guard skipped (IGNITE_H2_SKIP_GUARD=1)"
elif [[ "${GUARD_ONLY}" == "1" ]]; then
  echo "[sample/h2wire] guard-only run passed stages=${GUARD_STAGES_RAW}"
  exit 0
fi

"${SERVER_BIN}" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"

listener_ready=0
for _ in $(seq 1 50); do
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    failure_kind="$(startup_failure_kind)"
    if [[ "${failure_kind}" == "listen_permission_denied" ]]; then
      echo "[sample/h2wire] server exited before listener-ready because bind permission was denied." >&2
      echo "[sample/h2wire] this is sandbox/host noise, not a TLS-handshake blocker." >&2
    else
      echo "[sample/h2wire] server exited before listener-ready banner." >&2
      echo "[sample/h2wire] this means startup failed before any client handshake could be attempted." >&2
    fi
    print_server_log_excerpt
    exit 1
  fi
  if [[ -f "${SERVER_LOG}" ]] && grep -Fq "${READY_MARKER}" "${SERVER_LOG}"; then
    listener_ready=1
    break
  fi
  sleep 0.1
done

if [[ "${listener_ready}" != "1" ]]; then
  failure_kind="$(startup_failure_kind)"
  if [[ "${failure_kind}" == "listen_permission_denied" ]]; then
    echo "[sample/h2wire] listener-ready banner never appeared because bind permission was denied." >&2
    echo "[sample/h2wire] this is sandbox/host noise, not a TLS-handshake blocker." >&2
  else
    echo "[sample/h2wire] listener-ready banner never appeared." >&2
  fi
  print_server_log_excerpt
  exit 1
fi

ready=0
for _ in $(seq 1 5); do
  if curl -k --http2 --silent --fail "https://127.0.0.1:18444/health" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

if [[ "${ready}" != "1" ]]; then
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "[sample/h2wire] listener-ready banner appeared, but the first TLS handshake crashed the server." >&2
    echo "[sample/h2wire] this is the deeper runtime blocker after the stale guard is removed from the default path." >&2
  else
    echo "[sample/h2wire] listener-ready banner appeared, but the health probe still failed while the server stayed alive." >&2
  fi
  print_server_log_excerpt
  exit 1
fi

node "${VERIFY_SCRIPT}"

echo "[sample/h2wire] probe passed. server log: ${SERVER_LOG}"
