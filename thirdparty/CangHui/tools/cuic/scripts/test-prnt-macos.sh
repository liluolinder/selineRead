#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-${TMPDIR:-/tmp}/cuic-prnt-smoke.png}"

"${ROOT_DIR}/bin/cuic" prnt macos notepad --output "${OUTPUT}"
test -s "${OUTPUT}"
file "${OUTPUT}"
echo "CangHui prnt smoke passed: ${OUTPUT}"
