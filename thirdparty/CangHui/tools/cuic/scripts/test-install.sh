#!/usr/bin/env bash

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_ROOT="${TMPDIR:-/tmp}/canghui-cuic-install-smoke"
CONSUMER_ROOT="${INSTALL_ROOT}/external-chui-consumer"

rm -rf "${INSTALL_ROOT}"
"${FRAMEWORK_ROOT}/scripts/install-cuic.sh" --source "${FRAMEWORK_ROOT}" --root "${INSTALL_ROOT}"
test -x "${INSTALL_ROOT}/bin/cuic"
EXPECTED_REVISION="$(git -C "${FRAMEWORK_ROOT}" rev-parse HEAD)"
if [[ -n "$(git -C "${FRAMEWORK_ROOT}" status --porcelain -- tools/cuic)" ]]; then
    EXPECTED_REVISION="${EXPECTED_REVISION}+dirty"
fi
CUIC_VERSION="$(sed -n 's/^version = "\([0-9][^"]*\)"/\1/p' "${FRAMEWORK_ROOT}/tools/cuic/cjpm.toml" | head -1)"
CJC_VERSION="$(sed -n 's/^cjc-version = "\([0-9][^"]*\)"/\1/p' "${FRAMEWORK_ROOT}/cjpm.toml" | head -1)"
EXPECTED_VERSION="cuic ${CUIC_VERSION} (local-source@${EXPECTED_REVISION})"
[[ "$("${INSTALL_ROOT}/bin/cuic" version)" == "${EXPECTED_VERSION}" ]]
ROOT_DOCTOR_JSON="$("${INSTALL_ROOT}/bin/cuic" doctor macos --json)"
python3 -c '
import json, sys
document = json.load(sys.stdin)
expected = sys.argv[1]
provenance = document.get("cliProvenance", {})
if provenance.get("channel") != "local-source" or provenance.get("revision") != expected:
    raise SystemExit("installed cuic provenance mismatch")
' "${EXPECTED_REVISION}" <<< "${ROOT_DOCTOR_JSON}"

assert_doctor_check_ready() {
    local document="$1"
    local check_id="$2"
    python3 -c '
import json, sys
document = json.load(sys.stdin)
check_id = sys.argv[1]
checks = [check for group in document.get("groups", []) for check in group.get("checks", [])]
matches = [check for check in checks if check.get("id") == check_id]
if len(matches) != 1 or matches[0].get("status") != "ready":
    raise SystemExit("doctor check is not uniquely ready: " + check_id)
' "${check_id}" <<< "${document}"
}

mkdir -p "${CONSUMER_ROOT}/src"
cat > "${CONSUMER_ROOT}/cjpm.toml" <<EOF
[package]
cjc-version = "${CJC_VERSION}"
name = "cuic_install_external_consumer"
description = "Disposable installed-CUIC dependency regression"
version = "0.1.0"
output-type = "executable"
compile-option = ""
override-compile-option = ""
link-option = ""
src-dir = ""
target-dir = ""
package-configuration = {}

[dependencies]
chui = { path = "${FRAMEWORK_ROOT}" }
EOF

cat > "${CONSUMER_ROOT}/src/main.cj" <<'EOF'
package cuic_install_external_consumer

import chui.*

main() {
    Row(space: 8.vp) {
        Label("installed cuic")
    }
    println("external-chui-consumer-ready")
}
EOF

DOCTOR_JSON="$("${INSTALL_ROOT}/bin/cuic" doctor macos --project "${CONSUMER_ROOT}" --json)"
assert_doctor_check_ready "${DOCTOR_JSON}" "project.dependency"
assert_doctor_check_ready "${DOCTOR_JSON}" "project.cache"
[[ "$(python3 -c 'import json, sys; print(next(group["status"] for group in json.load(sys.stdin)["groups"] if group["id"] == "repository"))' <<< "${DOCTOR_JSON}")" == "ready" ]]
"${INSTALL_ROOT}/bin/cuic" build macos "${CONSUMER_ROOT}"

if [[ -n "${CANGHUI_SHARED_CUIC:-}" ]]; then
    test -x "${CANGHUI_SHARED_CUIC}"
    [[ "$("${CANGHUI_SHARED_CUIC}" version)" == cuic\ "${CUIC_VERSION}"* ]]
    SHARED_DOCTOR_JSON="$("${CANGHUI_SHARED_CUIC}" doctor macos --project "${CONSUMER_ROOT}" --json)"
    assert_doctor_check_ready "${SHARED_DOCTOR_JSON}" "project.dependency"
    assert_doctor_check_ready "${SHARED_DOCTOR_JSON}" "project.cache"
    [[ "$(python3 -c 'import json, sys; print(next(group["status"] for group in json.load(sys.stdin)["groups"] if group["id"] == "repository"))' <<< "${SHARED_DOCTOR_JSON}")" == "ready" ]]
    "${CANGHUI_SHARED_CUIC}" build macos "${CONSUMER_ROOT}"
fi

echo "CangHui cuic install smoke passed"
