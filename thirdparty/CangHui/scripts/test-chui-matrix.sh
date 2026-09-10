#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="${1:-packages}"

case "${SCOPE}" in
    packages)
        SEARCH_ROOTS=("packages")
        ;;
    all)
        SEARCH_ROOTS=("bench" "examples" "packages" "tools/release-fixtures" "tools/cuic/testdata")
        ;;
    *)
        echo "usage: $0 [packages|all]" >&2
        exit 2
        ;;
esac

cd "${ROOT_DIR}"

mapfile_compat() {
    while IFS= read -r line; do
        MANIFESTS+=("${line}")
    done
}

MANIFESTS=()
mapfile_compat < <(
    find "${SEARCH_ROOTS[@]}" -name cjpm.toml -type f -print 2>/dev/null |
        LC_ALL=C sort
)

passed=0
skipped_native=0
negative=0

for manifest in "${MANIFESTS[@]}"; do
    if ! grep -Eq '^[[:space:]]*chui[[:space:]]*=' "${manifest}"; then
        continue
    fi

    if [[ "${manifest}" == "tools/cuic/testdata/duplicate-probe/cjpm.toml" ]]; then
        echo "==> negative fixture retained: ${manifest}"
        negative=$((negative + 1))
        continue
    fi

    case "${manifest}" in
        packages/scene3d-bgfx/cjpm.toml|examples/scene3d-bgfx-*/cjpm.toml)
            if [[ -z "${CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR:-}" || \
                  ! -d "${CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR}" ]]; then
                echo "==> native gap recorded: ${manifest} (set CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR)"
                skipped_native=$((skipped_native + 1))
                continue
            fi
            ;;
    esac

    package_dir="${manifest%/cjpm.toml}"
    echo "==> build ${package_dir}"
    (cd "${package_dir}" && cjpm build)
    echo "==> test ${package_dir}"
    # The interactive progress renderer can stop draining concurrent dependency-scan output when
    # this matrix reaches large consumers. Keep CI and agent runs non-interactive and pipe-safe.
    (cd "${package_dir}" && cjpm test --no-progress)
    passed=$((passed + 1))
done

if [[ "${passed}" -eq 0 ]]; then
    echo "no positive chui consumer manifests were exercised" >&2
    exit 1
fi

if [[ "${CANGHUI_MATRIX_REQUIRE_NATIVE:-0}" == "1" && "${skipped_native}" -ne 0 ]]; then
    echo "native Scene3D manifests were required but ${skipped_native} were skipped" >&2
    exit 1
fi

echo "CangHui ${SCOPE} matrix passed: positive=${passed} native-skipped=${skipped_native} negative-fixtures=${negative}"
