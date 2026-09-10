#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET_SOURCE="${ROOT_DIR}/src/core/widget.cj"
FIXTURE="${ROOT_DIR}/tools/testdata/probe-option-collision"

typed_count="$(rg -F 'None<ProbeSemanticProvider>' "${WIDGET_SOURCE}" | wc -l | tr -d ' ')"
if [[ "${typed_count}" != "3" ]]; then
    echo "expected exactly three explicitly typed empty probe providers, found ${typed_count}" >&2
    exit 1
fi

if rg -n 'applyProbeModifier\([^;]*, None\)' "${WIDGET_SOURCE}" >/dev/null; then
    echo "untyped empty probe provider remains in widget overloads" >&2
    exit 1
fi

echo "==> clean external probe Option collision fixture"
(cd "${FIXTURE}" && cjpm clean && cjpm build)

echo "==> incremental external probe Option collision fixture"
(cd "${FIXTURE}" && cjpm build -i)

echo "CangHui probe Option disambiguation passed"
