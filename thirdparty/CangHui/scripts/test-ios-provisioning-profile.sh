#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/canghui-ios-profile-test.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

# shellcheck source=scripts/lib/ios-provisioning-profile.sh
source "${PROJECT_ROOT}/scripts/lib/ios-provisioning-profile.sh"

FIXTURE="${TEST_ROOT}/fixture.plist"
cat >"${FIXTURE}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>Name</key><string>CangHui test</string></dict></plist>
EOF

make_security() {
    local behavior="$1"
    cat >"${TEST_ROOT}/bin/security" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${behavior}" == "fail" ]]; then exit 1; fi
output=""
while (( \$# > 0 )); do
    if [[ "\$1" == "-o" ]]; then output="\$2"; shift 2; else shift; fi
done
cp "${FIXTURE}" "\${output}"
EOF
    chmod +x "${TEST_ROOT}/bin/security"
}

make_openssl() {
    local behavior="$1"
    cat >"${TEST_ROOT}/bin/openssl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${behavior}" == "fail" ]]; then exit 1; fi
output=""
while (( \$# > 0 )); do
    if [[ "\$1" == "-out" ]]; then output="\$2"; shift 2; else shift; fi
done
cp "${FIXTURE}" "\${output}"
EOF
    chmod +x "${TEST_ROOT}/bin/openssl"
}

mkdir -p "${TEST_ROOT}/bin"
ORIGINAL_PATH="${PATH}"
PATH="${TEST_ROOT}/bin:/usr/bin:/bin"

make_security success
make_openssl fail
decode_ios_provisioning_profile "${TEST_ROOT}/input.mobileprovision" \
    "${TEST_ROOT}/security.plist"
cmp "${FIXTURE}" "${TEST_ROOT}/security.plist"
[[ "${CANGHUI_IOS_PROFILE_DECODER_USED}" == "security-cms" ]]

make_security fail
make_openssl success
decode_ios_provisioning_profile "${TEST_ROOT}/input.mobileprovision" \
    "${TEST_ROOT}/openssl.plist"
cmp "${FIXTURE}" "${TEST_ROOT}/openssl.plist"
[[ "${CANGHUI_IOS_PROFILE_DECODER_USED}" == "openssl-smime" ]]

make_security fail
make_openssl fail
if decode_ios_provisioning_profile "${TEST_ROOT}/input.mobileprovision" \
    "${TEST_ROOT}/failure.plist" 2>/dev/null; then
    printf 'Decoder unexpectedly accepted two failing backends.\n' >&2
    exit 1
fi
if [[ -e "${TEST_ROOT}/failure.plist" ]]; then
    printf 'Decoder left a false-success output after failure.\n' >&2
    exit 1
fi
[[ -z "${CANGHUI_IOS_PROFILE_DECODER_USED}" ]]

PATH="${ORIGINAL_PATH}"
printf 'iOS provisioning profile decoder tests passed.\n'
