#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SERVER_BIN="/tmp/ignite_client_demo_server"
CLIENT_BIN="/tmp/ignite_client_demo_client"
SERVER_LOG="/tmp/ignite_client_demo_server.log"

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

ensure_cangjie_env

STDX_STATIC="$(detect_stdx_static || true)"
if [[ -z "${STDX_STATIC}" ]]; then
  echo "[client-demo] cannot locate stdx static path." >&2
  echo "[client-demo] set IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static or CANGJIE_STDX_PATH." >&2
  exit 1
fi

RUNTIME_LIB_DIR="$(detect_runtime_lib_dir || true)"
if [[ -z "${RUNTIME_LIB_DIR}" ]]; then
  echo "[client-demo] cannot locate Cangjie runtime lib dir." >&2
  echo "[client-demo] set IGNITE_CJ_RUNTIME_LIB_DIR or CANGJIE_HOME." >&2
  exit 1
fi

echo "[client-demo] compiling demo server..."
IGNITE_SAMPLE_COMPILE_ONLY=1 \
  "${ROOT}/manual/samples/_shared/run_server_sample.sh" \
  "manual/samples/client/demo_server.cj" \
  "${SERVER_BIN}"

echo "[client-demo] compiling demo client..."
IGNITE_SAMPLE_SKIP_BUILD=1 IGNITE_SAMPLE_COMPILE_ONLY=1 \
  "${ROOT}/manual/samples/_shared/run_server_sample.sh" \
  "manual/samples/client/demo_client.cj" \
  "${CLIENT_BIN}"

case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${DYLD_LIBRARY_PATH:-}"
    ;;
  Linux)
    export LD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${LD_LIBRARY_PATH:-}"
    ;;
esac

echo "[client-demo] starting server..."
"${SERVER_BIN}" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"
sleep 1

echo "[client-demo] running client..."
"${CLIENT_BIN}"

echo "[client-demo] done. server log: ${SERVER_LOG}"
