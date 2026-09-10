#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
IDENTITY="${CANGHUI_DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${CANGHUI_NOTARY_PROFILE:-}"
ENTITLEMENTS="${CANGHUI_ENTITLEMENTS:-}"

if [[ -z "${APP}" || ! -d "${APP}/Contents" ]]; then
  echo "usage:" >&2
  echo "  CANGHUI_DEVELOPER_ID_APPLICATION='Developer ID Application: ...'" >&2
  echo "  CANGHUI_NOTARY_PROFILE=keychain-profile $0 /path/To.app" >&2
  exit 2
fi
if [[ -z "${IDENTITY}" || -z "${NOTARY_PROFILE}" ]]; then
  echo "Developer ID identity and notary keychain profile are required by reference." >&2
  echo "No signing or notarization secret may be passed as a command argument." >&2
  exit 2
fi
if [[ -n "${ENTITLEMENTS}" && ! -f "${ENTITLEMENTS}" ]]; then
  echo "CANGHUI_ENTITLEMENTS does not name a readable file" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$(cd "$(dirname "${APP}")" && pwd)/$(basename "${APP}")"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/canghui-notary.XXXXXX")"
ARCHIVE="${WORK_ROOT}/$(basename "${APP}").zip"

cleanup() {
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

sign_one() {
  local target="$1"
  local args=(--force --options runtime --timestamp --sign "${IDENTITY}")
  if [[ -n "${ENTITLEMENTS}" && "${target}" == "${APP}" ]]; then
    args+=(--entitlements "${ENTITLEMENTS}")
  fi
  codesign "${args[@]}" "${target}"
}

"${ROOT_DIR}/scripts/audit-macos-release.sh" --candidate "${APP}"

echo "==> sign nested Mach-O code inside-out"
while IFS= read -r -d '' candidate; do
  if file "${candidate}" | grep -F "Mach-O" >/dev/null; then
    sign_one "${candidate}"
  fi
done < <(find "${APP}/Contents" -type f -print0)
sign_one "${APP}"

codesign --verify --deep --strict --verbose=2 "${APP}"
ditto -c -k --keepParent "${APP}" "${ARCHIVE}"

echo "==> submit with keychain profile ${NOTARY_PROFILE}"
xcrun notarytool submit "${ARCHIVE}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${APP}"
xcrun stapler validate "${APP}"

"${ROOT_DIR}/scripts/audit-macos-release.sh" --publisher "${APP}"
echo "CangHui Developer ID signing and notarization flow completed."
