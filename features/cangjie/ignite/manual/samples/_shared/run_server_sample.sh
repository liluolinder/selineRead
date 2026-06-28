#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <sample-source> <output-bin>" >&2
  exit 1
fi

SAMPLE_SOURCE="$1"
OUTPUT_BIN="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if [[ ! -f "${ROOT}/${SAMPLE_SOURCE}" ]]; then
  echo "[sample-runner] sample source not found: ${SAMPLE_SOURCE}" >&2
  exit 1
fi

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

collect_package_archives() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi

  find "${dir}" -maxdepth 1 -type f -name "lib*.a" \
    ! -name "lib*.tests.a" \
    | sort
}

ensure_cangjie_env

STDX_STATIC="$(detect_stdx_static || true)"
if [[ -z "${STDX_STATIC}" ]]; then
  echo "[sample-runner] cannot locate stdx static path." >&2
  echo "[sample-runner] set IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static or CANGJIE_STDX_PATH." >&2
  exit 1
fi

RUNTIME_LIB_DIR="$(detect_runtime_lib_dir || true)"
if [[ -z "${RUNTIME_LIB_DIR}" ]]; then
  echo "[sample-runner] cannot locate Cangjie runtime lib dir." >&2
  echo "[sample-runner] set IGNITE_CJ_RUNTIME_LIB_DIR or CANGJIE_HOME." >&2
  exit 1
fi

COMMON_IMPORTS=(
  --import-path "${ROOT}/target/release"
  --import-path "${ROOT}/target/release/seajson"
  --import-path "${STDX_STATIC}"
)

declare -a IGNITE_ARCHIVES=()
while IFS= read -r path; do
  IGNITE_ARCHIVES+=("${path}")
done < <(collect_package_archives "${ROOT}/target/release/ignite")

declare -a JINGUISSL_CONTRACT_ARCHIVES=()
while IFS= read -r path; do
  JINGUISSL_CONTRACT_ARCHIVES+=("${path}")
done < <(collect_package_archives "${ROOT}/target/release/jinguissl_contract")

declare -a JINGUISSL_CORE_ARCHIVES=()
while IFS= read -r path; do
  JINGUISSL_CORE_ARCHIVES+=("${path}")
done < <(collect_package_archives "${ROOT}/target/release/jinguissl_core")

declare -a STDX_ARCHIVES=()
while IFS= read -r path; do
  STDX_ARCHIVES+=("${path}")
done < <(collect_package_archives "${STDX_STATIC}/stdx")

declare -a COMMON_LINKS=()
COMMON_LINKS+=(-L "${ROOT}/target/release/seajson" -lseajson)
if [[ "${#IGNITE_ARCHIVES[@]}" -gt 0 ]]; then
  COMMON_LINKS+=("${IGNITE_ARCHIVES[@]}")
fi
if [[ "${#JINGUISSL_CONTRACT_ARCHIVES[@]}" -gt 0 ]]; then
  COMMON_LINKS+=("${JINGUISSL_CONTRACT_ARCHIVES[@]}")
fi
if [[ "${#JINGUISSL_CORE_ARCHIVES[@]}" -gt 0 ]]; then
  COMMON_LINKS+=("${JINGUISSL_CORE_ARCHIVES[@]}")
fi
if [[ "${#STDX_ARCHIVES[@]}" -gt 0 ]]; then
  COMMON_LINKS+=("${STDX_ARCHIVES[@]}")
fi

if [[ "${IGNITE_SAMPLE_SKIP_BUILD:-0}" == "1" ]]; then
  echo "[sample-runner] skipping ignite package build (IGNITE_SAMPLE_SKIP_BUILD=1)"
else
  echo "[sample-runner] building ignite package..."
  (cd "${ROOT}" && cjpm build)
fi

echo "[sample-runner] compiling ${SAMPLE_SOURCE}..."
cjc "${ROOT}/${SAMPLE_SOURCE}" \
  "${COMMON_IMPORTS[@]}" \
  "${COMMON_LINKS[@]}" \
  -Woff unused \
  -o "${OUTPUT_BIN}"

if [[ "${IGNITE_SAMPLE_COMPILE_ONLY:-0}" == "1" ]]; then
  echo "[sample-runner] compile-only mode; skipping run"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${DYLD_LIBRARY_PATH:-}"
    ;;
  Linux)
    export LD_LIBRARY_PATH="${ROOT}/target/release/seajson:${ROOT}/target/release/ignite:${ROOT}/target/release/jinguissl_contract:${ROOT}/target/release/jinguissl_core:${STDX_STATIC}/stdx:${RUNTIME_LIB_DIR}:${LD_LIBRARY_PATH:-}"
    ;;
esac

echo "[sample-runner] running ${OUTPUT_BIN}"
"${OUTPUT_BIN}"
