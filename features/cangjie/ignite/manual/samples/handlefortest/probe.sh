#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKER_BIN="/tmp/ignite_sample_handlefortest"
LOG_DIR="/tmp/ignite_sample_handlefortest_probe_${$}"
WORKERS="${IGNITE_HANDLE_FOR_TEST_PROBE_WORKERS:-6}"
ITERATIONS="${IGNITE_HANDLE_FOR_TEST_PROBE_ITERATIONS:-24}"
LEASE_ROOT="${IGNITE_HANDLE_FOR_TEST_PROBE_LEASE_DIR:-/tmp/ignite_handle_for_test_probe_lease_${$}}"

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

mkdir -p "${LOG_DIR}"

cleanup() {
  rm -rf "${LEASE_ROOT}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

ensure_cangjie_env

IGNITE_SAMPLE_COMPILE_ONLY=1 \
  "${ROOT}/manual/samples/_shared/run_server_sample.sh" \
  "manual/samples/handlefortest/main.cj" \
  "${WORKER_BIN}"

STDX_STATIC="$(detect_stdx_static || true)"
if [[ -z "${STDX_STATIC}" ]]; then
  echo "[sample/handlefortest] cannot locate stdx static path." >&2
  exit 1
fi

RUNTIME_LIB_DIR="$(detect_runtime_lib_dir || true)"
if [[ -z "${RUNTIME_LIB_DIR}" ]]; then
  echo "[sample/handlefortest] cannot locate Cangjie runtime lib dir." >&2
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

declare -a pids=()
declare -a logs=()

for i in $(seq 1 "${WORKERS}"); do
  log_path="${LOG_DIR}/worker-${i}.log"
  logs+=("${log_path}")
  IGNITE_INPROC_TEST_PORT_LEASE_DIR="${LEASE_ROOT}" \
  IGNITE_HANDLE_FOR_TEST_STRESS_ID="worker-${i}" \
  IGNITE_HANDLE_FOR_TEST_STRESS_ITERATIONS="${ITERATIONS}" \
  "${WORKER_BIN}" >"${log_path}" 2>&1 &
  pids+=("$!")
done

failed=0
for idx in "${!pids[@]}"; do
  if ! wait "${pids[$idx]}"; then
    failed=1
    echo "[sample/handlefortest] worker $((idx + 1)) failed: ${logs[$idx]}" >&2
    sed -n '1,160p' "${logs[$idx]}" >&2
  fi
done

if [[ "${failed}" != "0" ]]; then
  echo "[sample/handlefortest] probe failed. logs: ${LOG_DIR}" >&2
  exit 1
fi

ok_count="$(grep -h "ok$" "${LOG_DIR}"/worker-*.log | wc -l | tr -d ' ')"
echo "[sample/handlefortest] probe passed workers=${WORKERS} iterations=${ITERATIONS} ok_logs=${ok_count}"
echo "[sample/handlefortest] worker logs: ${LOG_DIR}"
