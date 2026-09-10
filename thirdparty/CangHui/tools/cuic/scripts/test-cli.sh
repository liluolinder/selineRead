#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-smoke"
REMOTE_FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-remote-smoke"
FAKE_BIN_DIR="${TMPDIR:-/tmp}/canghui-cli-fake-bin"
FAKE_LOCK_FILE="${TMPDIR:-/tmp}/canghui-cli-fake-lock"
FRAMEWORK_ROOT="$(cd "${ROOT_DIR}/../.." && pwd)"
DEBUG_CUIC="${ROOT_DIR}/target/debug/bin/main"

(cd "${ROOT_DIR}" && cjpm build -g)

run_debug_cuic() {
    CANGHUI_CLI_ROOT="${ROOT_DIR}" "${DEBUG_CUIC}" "$@"
}

rm -rf "${FIXTURE_DIR}"
rm -rf "${REMOTE_FIXTURE_DIR}"
rm -rf "${FAKE_BIN_DIR}"
rm -f "${FAKE_LOCK_FILE}"

"${ROOT_DIR}/bin/cuic" version | grep -Fq 'cuic 0.6.0 (development@unembedded)'
"${ROOT_DIR}/bin/cuic" examples | grep -q '^notepad$'
"${ROOT_DIR}/bin/cuic" init "${FIXTURE_DIR}" --name canghui_cli_smoke --platform macos \
    --canghui-path "${FRAMEWORK_ROOT}"
test -f "${FIXTURE_DIR}/assets/fonts/HarmonyOS_Sans_SC.ttf"
test -f "${FIXTURE_DIR}/assets/fonts/HARMONYOS_SANS_LICENSE.txt"
test -f "${FIXTURE_DIR}/assets/fonts/HARMONYOS_SANS_SOURCE.txt"
test -f "${FIXTURE_DIR}/canghui.toml"
MACOS_DOCTOR_JSON="$("${ROOT_DIR}/bin/cuic" doctor macos --project "${FIXTURE_DIR}" --json)"
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"schema":"canghui.doctor.v0"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"requestedTarget":"macos"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"exitCode":0'
"${ROOT_DIR}/bin/cuic" scripts list "${FIXTURE_DIR}" | grep -q '^  check:'
(
    cd "${FIXTURE_DIR}"
    "${ROOT_DIR}/bin/cuic" check
)
MAC_PACKAGE_JSON="$("${ROOT_DIR}/bin/cuic" package build macos "${FIXTURE_DIR}" --json)"
printf '%s' "${MAC_PACKAGE_JSON}" | grep -q '"schema":"canghui.packaging-artifact.v0"'
printf '%s' "${MAC_PACKAGE_JSON}" | grep -q '"executableIncluded":true'
test -x "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/Contents/MacOS/canghui_cli_smoke"
test -f "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/Contents/Info.plist"
test -f "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/Contents/Resources/canghui-packaging-receipt.json"
test ! -e "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/canghui-packaging-receipt.json"
plutil -lint "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/Contents/Info.plist" >/dev/null
if grep -q '/Users/' "${FIXTURE_DIR}/dist/canghui_cli_smoke.app/Contents/Resources/canghui-packaging-receipt.json"; then
    echo "error: macOS packaging receipt leaked an absolute project path" >&2
    exit 1
fi

WINDOWS_PACKAGE_JSON="$("${ROOT_DIR}/bin/cuic" package build windows "${FIXTURE_DIR}" --json)"
printf '%s' "${WINDOWS_PACKAGE_JSON}" | grep -q '"artifactKind":"windows-unsigned-resource-input-tree"'
printf '%s' "${WINDOWS_PACKAGE_JSON}" | grep -q '"executableIncluded":false'
test -f "${FIXTURE_DIR}/dist/canghui_cli_smoke/canghui_cli_smoke.exe.manifest"
test -f "${FIXTURE_DIR}/dist/canghui_cli_smoke/canghui_cli_smoke.version.rc"
test -f "${FIXTURE_DIR}/dist/canghui_cli_smoke/AppUserModelID.txt"

LINUX_PACKAGE_JSON="$("${ROOT_DIR}/bin/cuic" package build linux "${FIXTURE_DIR}" \
    --output dist/linux-input --json)"
printf '%s' "${LINUX_PACKAGE_JSON}" | grep -q '"artifactKind":"linux-unsigned-desktop-input-tree"'
test -f "${FIXTURE_DIR}/dist/linux-input/canghui_cli_smoke.desktop"
test -f "${FIXTURE_DIR}/dist/linux-input/share/applications/dev.canghui.canghui_cli_smoke.desktop"

if "${ROOT_DIR}/bin/cuic" package build windows "${FIXTURE_DIR}" >/dev/null 2>&1; then
    echo "error: package build unexpectedly replaced a non-empty output directory" >&2
    exit 1
fi
if "${ROOT_DIR}/bin/cuic" package build linux "${FIXTURE_DIR}" --output ../escape >/dev/null 2>&1; then
    echo "error: package build unexpectedly accepted an escaping output directory" >&2
    exit 1
fi
mkdir -p "${FIXTURE_DIR}/recursive-resource"
sed -i.bak 's/resources = \[\]/resources = ["recursive-resource"]/' "${FIXTURE_DIR}/canghui.toml"
if "${ROOT_DIR}/bin/cuic" package build linux "${FIXTURE_DIR}" \
    --output recursive-resource/package-output >/dev/null 2>&1; then
    echo "error: package build unexpectedly nested its output inside a declared resource" >&2
    exit 1
fi
"${ROOT_DIR}/bin/cuic" init "${REMOTE_FIXTURE_DIR}" --name canghui_cli_remote_smoke --platform macos
grep -q 'git = "https://github.com/Celading/CangHui.git"' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
grep -q 'commitId = "a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02"' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
grep -q -- '--set-runtime-rpath' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
if grep -q '/Users/' "${REMOTE_FIXTURE_DIR}/cjpm.toml"; then
    echo "error: generated remote consumer leaked a local absolute path" >&2
    exit 1
fi
if grep -q 'cjpm.lock' "${REMOTE_FIXTURE_DIR}/.gitignore"; then
    echo "error: generated consumer unexpectedly ignores its dependency lock" >&2
    exit 1
fi
expect_missing_lock_failure() {
    local route="$1"
    shift
    set +e
    local output
    output="$("$@" 2>&1)"
    local code=$?
    set -e
    if [[ ${code} -eq 0 ]] || [[ "${output}" != *"dependency lock is missing"* ]]; then
        echo "error: ${route} did not fail closed on a missing dependency lock" >&2
        exit 1
    fi
    test ! -f "${REMOTE_FIXTURE_DIR}/cjpm.lock"
}

expect_missing_lock_failure build \
    "${ROOT_DIR}/bin/cuic" build macos "${REMOTE_FIXTURE_DIR}"
expect_missing_lock_failure kmode \
    run_debug_cuic kmode list "${REMOTE_FIXTURE_DIR}"
expect_missing_lock_failure probe \
    run_debug_cuic probe list "${REMOTE_FIXTURE_DIR}" --json
expect_missing_lock_failure snapshot \
    run_debug_cuic prnt macos "${REMOTE_FIXTURE_DIR}" --output "${REMOTE_FIXTURE_DIR}/missing-lock.bmp"
expect_missing_lock_failure lifecycle-alias \
    run_debug_cuic snapshot-ui "${REMOTE_FIXTURE_DIR}"
set +e
MISSING_LOCK_DOCTOR="$("${ROOT_DIR}/bin/cuic" doctor macos --project "${REMOTE_FIXTURE_DIR}" --json 2>&1)"
MISSING_LOCK_DOCTOR_CODE=$?
set -e
if [[ ${MISSING_LOCK_DOCTOR_CODE} -eq 0 ]] || \
    [[ "${MISSING_LOCK_DOCTOR}" != *'"id":"project.lock"'* ]] || \
    [[ "${MISSING_LOCK_DOCTOR}" != *'"status":"blocked"'* ]] || \
    [[ "${MISSING_LOCK_DOCTOR}" != *'"kind":"manual"'* ]]; then
    echo "error: doctor did not report the missing lock as an explicit blocked action" >&2
    exit 1
fi

mkdir -p "${FAKE_BIN_DIR}"
printf '%s\n' \
    '[requires]' \
    'chui = { git = "https://github.com/Celading/CangHui.git", commitId = "a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02" }' \
    > "${FAKE_LOCK_FILE}"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '[[ "${1:-}" == "update" ]]' \
    'cp "${CANGHUI_TEST_LOCK_SOURCE:?}" cjpm.lock' \
    > "${FAKE_BIN_DIR}/cjpm"
chmod +x "${FAKE_BIN_DIR}/cjpm"
CANGHUI_TEST_LOCK_SOURCE="${FAKE_LOCK_FILE}" PATH="${FAKE_BIN_DIR}:${PATH}" \
    "${ROOT_DIR}/bin/cuic" dependency update "${REMOTE_FIXTURE_DIR}" |
    grep -q 'CangHui dependency locked at a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02'

sed -i.bak 's/a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02/deadbeefdeadbeefdeadbeefdeadbeefdeadbeef/' \
    "${REMOTE_FIXTURE_DIR}/cjpm.toml"
LOCK_BEFORE_MISMATCH="$(shasum -a 256 "${REMOTE_FIXTURE_DIR}/cjpm.lock" | awk '{print $1}')"
set +e
MISMATCH_OUTPUT="$("${ROOT_DIR}/bin/cuic" test macos "${REMOTE_FIXTURE_DIR}" 2>&1)"
MISMATCH_CODE=$?
set -e
if [[ ${MISMATCH_CODE} -eq 0 ]] || [[ "${MISMATCH_OUTPUT}" != *"does not match the manifest"* ]]; then
    echo "error: test did not fail closed on a manifest/lock mismatch" >&2
    exit 1
fi
LOCK_AFTER_MISMATCH="$(shasum -a 256 "${REMOTE_FIXTURE_DIR}/cjpm.lock" | awk '{print $1}')"
[[ "${LOCK_BEFORE_MISMATCH}" == "${LOCK_AFTER_MISMATCH}" ]]
run_debug_cuic probe diff component-gallery
PROBE_LIST_JSON="$(run_debug_cuic probe list component-gallery --json)"
printf '%s' "${PROBE_LIST_JSON}" | grep -q 'gallery.primary-button'
PROBE_DESCRIBE_JSON="$(run_debug_cuic probe describe component-gallery gallery.primary-button --json)"
printf '%s' "${PROBE_DESCRIBE_JSON}" | grep -q '"kind":"function"'
PROBE_RUN_JSON="$(run_debug_cuic probe run component-gallery gallery.primary-button \
    --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
    --json)"
printf '%s' "${PROBE_RUN_JSON}" | grep -q '"ok":true'
PROBE_ASCII="$(run_debug_cuic probe ascii component-gallery gallery.primary-button \
    --columns 72 --rows 24)"
printf '%s' "${PROBE_ASCII}" | grep -q 'CangHui headless Draw IR 320.000000x120.000000 -> 72x24'
printf '%s' "${PROBE_ASCII}" | grep -q 'Run probe'
printf '%s' "${PROBE_ASCII}" | grep -Fq 'Semantic map:'
printf '%s' "${PROBE_ASCII}" | grep -Fq '$i1 - "Button#primary-button"'

MOBILE_HOST_REPLAY_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.host.replay 'player.toggle|4|9')"
printf '%s' "${MOBILE_HOST_REPLAY_JSON}" | grep -q '"protocol":"canghui.mobile-host-replay.v0"'
printf '%s' "${MOBILE_HOST_REPLAY_JSON}" | grep -q '"stage":"input-tree"'
printf '%s' "${MOBILE_HOST_REPLAY_JSON}" | grep -q '"installable":false'
printf '%s' "${MOBILE_HOST_REPLAY_JSON}" | grep -q '"decision":"current"'

IOS_PROVIDER_REPLAY_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.provider.replay 'player.toggle|4|9')"
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q '"platform":"ios"'
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q '"stage":"input-tree"'
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q '"signing":"unsigned"'
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q '"deviceProven":false'
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q 'platform/ios/probe/Info.plist'
printf '%s' "${IOS_PROVIDER_REPLAY_JSON}" | grep -q '"decision":"current"'

IOS_SIGNING_PREPARATION_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.signing.prepare 'ios-signing-identity,ios-provisioning-profile')"
printf '%s' "${IOS_SIGNING_PREPARATION_JSON}" | grep -q '"protocol":"canghui.mobile-signing-preparation.v0"'
printf '%s' "${IOS_SIGNING_PREPARATION_JSON}" | grep -q '"state":"requirements-satisfied"'
printf '%s' "${IOS_SIGNING_PREPARATION_JSON}" | grep -q '"missingCapabilities":\[\]'
printf '%s' "${IOS_SIGNING_PREPARATION_JSON}" | grep -q '"signedPackage":false'
printf '%s' "${IOS_SIGNING_PREPARATION_JSON}" | grep -q '"installable":false'

IOS_SIGNING_BINDING="input-tree-v0:ios:ios-application-bundle:id-31:4:9:14"
IOS_SIGNING_RECEIPT_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.signing.bind "CangHui.app|xcode|identity-ref|profile-ref|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|${IOS_SIGNING_BINDING}")"
printf '%s' "${IOS_SIGNING_RECEIPT_JSON}" | grep -q '"protocol":"canghui.mobile-external-signer-receipt.v0"'
printf '%s' "${IOS_SIGNING_RECEIPT_JSON}" | grep -q '"state":"accepted"'
printf '%s' "${IOS_SIGNING_RECEIPT_JSON}" | grep -q '"signedPackage":false'
printf '%s' "${IOS_SIGNING_RECEIPT_JSON}" | grep -q '"deviceProven":false'

IOS_SIGNED_PACKAGE_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.signing.verify "CangHui.app|ios-platform-owner|codesign-verify|strict-v1|verify-20260819-cli|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|4096|${IOS_SIGNING_BINDING}|passed")"
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"protocol":"canghui.mobile-signed-package-evidence.v0"'
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"state":"applied"'
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"signedPackage":true'
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"installable":true'
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"installationProven":false'
printf '%s' "${IOS_SIGNED_PACKAGE_JSON}" | grep -q '"deviceProven":false'

IOS_INSTALLATION_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.installation.record "CangHui.app|ios-platform-owner|physical-device|devicectl|development-install-v1|install-20260819-cli|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|4096|${IOS_SIGNING_BINDING}|installed")"
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"protocol":"canghui.mobile-installation-attempt.v0"'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"state":"recorded"'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"sourceStage":"signed-package"'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"installed":true'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"installationProven":true'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"launchProven":false'
printf '%s' "${IOS_INSTALLATION_JSON}" | grep -q '"deviceProven":false'

IOS_FAILED_INSTALLATION_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.installation.record "CangHui.app|ios-platform-owner|physical-device|devicectl|development-install-v1|install-20260819-cli-failed|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|4096|${IOS_SIGNING_BINDING}|failed")"
printf '%s' "${IOS_FAILED_INSTALLATION_JSON}" | grep -q '"state":"recorded"'
printf '%s' "${IOS_FAILED_INSTALLATION_JSON}" | grep -q '"outcome":"failed"'
printf '%s' "${IOS_FAILED_INSTALLATION_JSON}" | grep -q '"installationProven":false'

IOS_STALE_INSTALLATION_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.installation.record "CangHui.app|ios-platform-owner|physical-device|devicectl|development-install-v1|install-20260819-cli-stale|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|4096|input-tree-v0:ios:ios-application-bundle:stale:4:9:14|installed")"
printf '%s' "${IOS_STALE_INSTALLATION_JSON}" | grep -q '"state":"rejected"'
printf '%s' "${IOS_STALE_INSTALLATION_JSON}" | grep -q '"installationProven":false'
printf '%s' "${IOS_STALE_INSTALLATION_JSON}" | grep -q '"deviceProven":false'

IOS_STALE_SIGNED_PACKAGE_JSON="$(run_debug_cuic kmode call mobile-host-replay \
    mobile.demo.ios.signing.verify "CangHui.app|ios-platform-owner|codesign-verify|strict-v1|verify-20260819-stale|sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef|4096|input-tree-v0:ios:ios-application-bundle:stale:4:9:14|passed")"
printf '%s' "${IOS_STALE_SIGNED_PACKAGE_JSON}" | grep -q '"state":"rejected"'
printf '%s' "${IOS_STALE_SIGNED_PACKAGE_JSON}" | grep -q '"signedPackage":false'

SYMBOL_CATALOG_JSON="$("${ROOT_DIR}/bin/cuic" symbol list --json)"
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"schema":"canghui.symbol.catalog.v0"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"material"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"ant"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"arco"'

(
    cd "${FIXTURE_DIR}"
    "${ROOT_DIR}/bin/cuic" symbol generate material:plus@primary_add ant:check arco:right \
        --output generated_symbols.cj --package canghui_cli_smoke
    grep -q 'MaterialSymbolProvider(included: \["add"\])' generated_symbols.cj
    grep -q 'AntSymbolProvider(included: \["check"\])' generated_symbols.cj
    grep -q 'ArcoSymbolProvider(included: \["right"\])' generated_symbols.cj
)

if "${ROOT_DIR}/bin/cuic" symbol generate material:add material:plus \
    --output "${FIXTURE_DIR}/duplicate-symbols.cj" --package canghui_cli_smoke; then
    echo "error: alias-equivalent Symbol selections unexpectedly passed" >&2
    exit 1
fi

if "${ROOT_DIR}/bin/cuic" symbol generate material:add@action ant:plus@action \
    --output "${FIXTURE_DIR}/colliding-symbols.cj" --package canghui_cli_smoke; then
    echo "error: cross-provider Symbol export collision unexpectedly passed" >&2
    exit 1
fi

if run_debug_cuic probe diff "${ROOT_DIR}/testdata/duplicate-probe"; then
    echo "error: duplicate probe scanner unexpectedly passed" >&2
    exit 1
fi

if "${ROOT_DIR}/bin/cuic" doctor android; then
    echo "error: Android doctor unexpectedly passed" >&2
    exit 1
fi

if ANDROID_DOCTOR_JSON="$("${ROOT_DIR}/bin/cuic" doctor android --json)"; then
    echo "error: Android JSON doctor unexpectedly passed" >&2
    exit 1
fi
printf '%s' "${ANDROID_DOCTOR_JSON}" | grep -q '"status":"unsupported"'
printf '%s' "${ANDROID_DOCTOR_JSON}" | grep -q '"exitCode":1'

if "${ROOT_DIR}/bin/cuic" build linux "${FIXTURE_DIR}"; then
    echo "error: cross-host Linux build unexpectedly passed" >&2
    exit 1
fi

echo "CangHui CLI smoke passed"
