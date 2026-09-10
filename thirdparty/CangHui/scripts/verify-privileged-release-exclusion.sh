#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/canghui-privileged-gate.XXXXXX")}"
CUIC_RELEASE="${WORK_ROOT}/cuic-release"
CUIC_DEBUG="${WORK_ROOT}/cuic-debug"
APP_RELEASE="${WORK_ROOT}/app-release"
APP_DEBUG="${WORK_ROOT}/app-debug"
FIXTURE="${ROOT_DIR}/tools/release-fixtures/kmode-gate"
CJC_BIN="$(command -v cjc)"
CANGJIE_ROOT="${CANGJIE_HOME:-$(cd "$(dirname "${CJC_BIN}")/.." && pwd)}"
if [[ "$(uname -m)" == "arm64" ]]; then
  CANGJIE_RUNTIME_DIR="${CANGJIE_ROOT}/runtime/lib/darwin_aarch64_cjnative"
else
  CANGJIE_RUNTIME_DIR="${CANGJIE_ROOT}/runtime/lib/darwin_x86_64_cjnative"
fi
RUN_LIBRARY_PATH="${ROOT_DIR}/sdl/.sdl3:${CANGJIE_RUNTIME_DIR}:${DYLD_LIBRARY_PATH:-}"

mkdir -p "${WORK_ROOT}"

echo "==> build release/debug cuic"
(cd "${ROOT_DIR}/tools/cuic" && cjpm build --target-dir "${CUIC_RELEASE}")
(cd "${ROOT_DIR}/tools/cuic" && cjpm build -g --target-dir "${CUIC_DEBUG}")

echo "==> build release/debug kMode fixture"
(cd "${FIXTURE}" && cjpm build --target-dir "${APP_RELEASE}")
(cd "${FIXTURE}" && cjpm build -g --target-dir "${APP_DEBUG}")

CUIC_RELEASE_BIN="${CUIC_RELEASE}/release/bin/main"
CUIC_DEBUG_BIN="${CUIC_DEBUG}/debug/bin/main"
APP_RELEASE_BIN="${APP_RELEASE}/release/bin/main"
APP_DEBUG_BIN="${APP_DEBUG}/debug/bin/main"

for binary in "${CUIC_RELEASE_BIN}" "${CUIC_DEBUG_BIN}" "${APP_RELEASE_BIN}" "${APP_DEBUG_BIN}"; do
  if [[ ! -x "${binary}" ]]; then
    echo "missing executable: ${binary}" >&2
    exit 1
  fi
done

echo "==> release cuic refuses privileged execution"
for command in \
  "debug" \
  "prnt --device unavailable-device" \
  "kmode list ." \
  "probe list ." \
  "pview" \
  "shell snapshot ." \
  "frame trace . --scenario release-gate" \
  "frame replay unavailable.json --executor null"; do
  set +e
  output="$("${CUIC_RELEASE_BIN}" ${command} 2>&1)"
  code=$?
  set -e
  if [[ ${code} -eq 0 ]] || ! grep -q "unavailable in release cuic" <<<"${output}"; then
    echo "release cuic did not refuse: ${command}" >&2
    echo "${output}" >&2
    exit 1
  fi
done

if strings "${CUIC_RELEASE_BIN}" | grep -F "CANGHUI_PRIVILEGED_DEBUG_BUILD=1" >/dev/null; then
  echo "release cuic contains the positive debug marker" >&2
  exit 1
fi
if ! strings "${CUIC_DEBUG_BIN}" | grep -F "CANGHUI_PRIVILEGED_DEBUG_BUILD=1" >/dev/null; then
  echo "debug cuic is missing the positive debug marker" >&2
  exit 1
fi

echo "==> release application ignores historical launcher opt-ins"
release_output="$({
  printf 'canghui.kmode.v0|1|health||\n'
  printf 'canghui.kmode.v0|2|shutdown||\n'
} | CANGHUI_KMODE=1 CANGHUI_KMODE_TRANSPORT=stdio \
  DYLD_LIBRARY_PATH="${RUN_LIBRARY_PATH}" \
  "${APP_RELEASE_BIN}" --kmode-stdio)"
if [[ "${release_output}" != "CANGHUI_KMODE_RELEASE_CLOSED=1" ]]; then
  echo "release application entered or misreported kMode" >&2
  echo "${release_output}" >&2
  exit 1
fi

for release_binary in "${CUIC_RELEASE_BIN}" "${APP_RELEASE_BIN}"; do
  while IFS= read -r pattern; do
    [[ -z "${pattern}" || "${pattern}" == \#* ]] && continue
    if strings "${release_binary}" | grep -F "${pattern}" >/dev/null; then
      echo "release executable contains denylisted debug artifact: ${pattern}" >&2
      echo "binary: ${release_binary}" >&2
      exit 1
    fi
  done < "${ROOT_DIR}/scripts/canghui-release-deny-list.txt"
done

echo "==> debug application retains explicit local stdio workflow"
debug_output="$({
  printf 'canghui.kmode.v0|1|health||\n'
  printf 'canghui.kmode.v0|2|shutdown||\n'
} | CANGHUI_KMODE_TRANSPORT=stdio \
  DYLD_LIBRARY_PATH="${RUN_LIBRARY_PATH}" \
  "${APP_DEBUG_BIN}" --kmode-stdio)"
if ! grep -q "canghui.kmode.v0|1|1|" <<<"${debug_output}" || \
   ! grep -q "canghui.kmode.v0|2|1|" <<<"${debug_output}"; then
  echo "debug application did not complete health/shutdown stdio replay" >&2
  echo "${debug_output}" >&2
  exit 1
fi

echo "CangHui privileged release exclusion passed."
echo "evidence root: ${WORK_ROOT}"
