#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [--candidate|--publisher] /path/To.app" >&2
}

MODE="publisher"
if [[ "${1:-}" == "--candidate" || "${1:-}" == "--publisher" ]]; then
  MODE="${1#--}"
  shift
fi
APP="${1:-}"
if [[ -z "${APP}" || $# -ne 1 || ! -d "${APP}/Contents" ]]; then
  usage
  exit 2
fi

APP="$(cd "$(dirname "${APP}")" && pwd)/$(basename "${APP}")"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/canghui-macos-audit.XXXXXX")"
ENTITLEMENTS="${WORK_ROOT}/entitlements.plist"
DETAILS="${WORK_ROOT}/codesign-details.txt"
MAX_SYMBOLS="${CANGHUI_MAX_RELEASE_SYMBOLS:-2000}"
FAILURES=0
MACHO_COUNT=0

cleanup() {
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

echo "==> CangHui macOS ${MODE} audit: ${APP}"

if ! codesign --verify --deep --strict "${APP}"; then
  if [[ "${MODE}" == "publisher" ]]; then
    fail "code signature does not pass deep strict verification"
  else
    echo "candidate note: signature is absent or not yet final"
  fi
fi
if ! codesign -d --verbose=4 "${APP}" >"${DETAILS}" 2>&1; then
  if [[ "${MODE}" == "publisher" ]]; then
    fail "cannot read code signature metadata"
  else
    : >"${DETAILS}"
  fi
fi
codesign -d --entitlements :- "${APP}" >"${ENTITLEMENTS}" 2>/dev/null || true

for entitlement in \
  com.apple.security.get-task-allow \
  com.apple.security.cs.disable-library-validation \
  com.apple.security.cs.allow-dyld-environment-variables \
  com.apple.security.cs.disable-executable-page-protection \
  com.apple.security.cs.allow-unsigned-executable-memory; do
  if grep -F "<key>${entitlement}</key>" "${ENTITLEMENTS}" >/dev/null; then
    fail "dangerous release entitlement present: ${entitlement}"
  fi
done

while IFS= read -r -d '' candidate; do
  if ! file "${candidate}" | grep -F "Mach-O" >/dev/null; then
    continue
  fi
  MACHO_COUNT=$((MACHO_COUNT + 1))
  relative="${candidate#${APP}/}"
  echo "audit Mach-O: ${relative}"

  if strings "${candidate}" | grep -E '/Users/|/home/|/private/tmp/|/private/var/folders/|/Volumes/' >/dev/null; then
    fail "absolute developer/workspace path leaked by ${relative}"
  fi
  if strings "${candidate}" | grep -F "CANGHUI_PRIVILEGED_DEBUG_BUILD=1" >/dev/null; then
    fail "privileged debug build marker leaked by ${relative}"
  fi
  if strings "${candidate}" | grep -F "CANGHUI_KMODE_TRANSPORT" >/dev/null; then
    fail "release kMode transport opt-in leaked by ${relative}"
  fi

  if [[ "${relative}" == Contents/MacOS/* ]]; then
    symbol_count="$( (nm "${candidate}" 2>/dev/null || true) | wc -l | tr -d ' ')"
    if [[ "${symbol_count}" -gt "${MAX_SYMBOLS}" ]]; then
      fail "${relative} exposes ${symbol_count} symbols (limit ${MAX_SYMBOLS}); build with --strip-all"
    fi
    shasum -a 256 "${candidate}"
  fi

  while IFS= read -r dependency; do
    [[ -z "${dependency}" ]] && continue
    case "${dependency}" in
      @*|/System/*|/usr/lib/*) ;;
      *) fail "unsafe absolute dependency in ${relative}: ${dependency}" ;;
    esac
  done < <(otool -L "${candidate}" | tail -n +2 | awk '{print $1}')

  while IFS= read -r rpath; do
    [[ -z "${rpath}" ]] && continue
    case "${rpath}" in
      @*) ;;
      *) fail "unsafe absolute LC_RPATH in ${relative}: ${rpath}" ;;
    esac
  done < <(otool -l "${candidate}" | awk '
    $1 == "cmd" { current = $2 }
    current == "LC_RPATH" && $1 == "path" { print $2; current = "" }
  ')
done < <(find "${APP}/Contents" -type f -print0)

if [[ ${MACHO_COUNT} -eq 0 ]]; then
  fail "application contains no Mach-O executable"
fi

if [[ "${MODE}" == "publisher" ]]; then
  if grep -F "Signature=adhoc" "${DETAILS}" >/dev/null; then
    fail "publisher artifact is ad-hoc signed"
  fi
  if ! grep -F "Authority=Developer ID Application:" "${DETAILS}" >/dev/null; then
    fail "Developer ID Application authority is absent"
  fi
  if grep -F "TeamIdentifier=not set" "${DETAILS}" >/dev/null || \
     ! grep -E 'TeamIdentifier=[A-Z0-9]+' "${DETAILS}" >/dev/null; then
    fail "Apple team identifier is absent"
  fi
  if ! grep -E 'flags=.*runtime' "${DETAILS}" >/dev/null; then
    fail "Hardened Runtime is absent"
  fi
  if grep -F "Timestamp=none" "${DETAILS}" >/dev/null || \
     ! grep -F "Timestamp=" "${DETAILS}" >/dev/null; then
    fail "secure signing timestamp is absent"
  fi
  if ! spctl -a -t exec -vv "${APP}"; then
    fail "Gatekeeper execution assessment failed"
  fi
  if ! xcrun stapler validate "${APP}"; then
    fail "stapled notarization ticket is absent or invalid"
  fi
fi

if [[ ${FAILURES} -ne 0 ]]; then
  echo "CangHui macOS ${MODE} audit failed with ${FAILURES} finding(s)." >&2
  exit 1
fi

echo "CangHui macOS ${MODE} audit passed for ${MACHO_COUNT} Mach-O file(s)."
if [[ "${MODE}" == "candidate" ]]; then
  echo "Candidate mode does not prove Developer ID, Hardened Runtime, notarization or store acceptance."
else
  echo "Developer ID distribution evidence is complete; App Store submission remains a separate owner receipt."
fi
