#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOTS=("${ROOT_DIR}/src" "${ROOT_DIR}/tools/cuic/src")
PATTERN='import[[:space:]].*(std|stdx).*(net|socket|http)|foreign[[:space:]]+func.*(socket|connect|listen|accept)|<:[[:space:]]*KModeChannelModule|launch\([^\n]*(curl|nc|socat)'

findings="$(find "${SCAN_ROOTS[@]}" -type f -name '*.cj' ! -name '*_test.cj' -print0 | \
  xargs -0 grep -En "${PATTERN}" || true)"

if [[ -n "${findings}" ]]; then
  echo "CangHui source contains a network/control transport implementation candidate:" >&2
  echo "${findings}" >&2
  echo "Review and explicitly classify every finding before release." >&2
  exit 1
fi

echo "CangHui source network/control audit passed: no built-in listener, socket import,"
echo "native socket FFI, command tunnel, or KModeChannelModule implementation found."
echo "The transport-neutral KModeChannelModule interface is a contract, not a transport."
