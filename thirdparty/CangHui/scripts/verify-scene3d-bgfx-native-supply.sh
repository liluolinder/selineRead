#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="${CANGHUI_BGFX_SUPPLY_CONTRACT:-$ROOT/packages/scene3d-bgfx/native-supply/macos-arm64-metal-noop-v1.json}"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to a bgfx4cj Git checkout}"
: "${BGFX_NATIVE_ROOT:?set BGFX_NATIVE_ROOT to the directory containing libbgfx.a, libbimg.a and libbx.a}"
RECEIPT="${1:-${TMPDIR:-/tmp}/canghui-scene3d-bgfx-native-supply-receipt.json}"

fail() {
    printf 'scene3d bgfx native supply rejected: %s\n' "$1" >&2
    exit 1
}

json_value() {
    /usr/bin/plutil -extract "$2" raw -o - "$1"
}

archive_sha() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

archive_build_tuple() {
    /usr/bin/otool -l "$1" | /usr/bin/awk '
        /platform / { platform=$2 }
        /minos / { minos=$2 }
        /sdk / { print platform " " minos " " $2 }
    ' | /usr/bin/sort -u
}

[[ "$(uname -s)" == "Darwin" ]] || fail "the frozen supply contract is macOS-only"
[[ "$(uname -m)" == "arm64" ]] || fail "the frozen supply contract requires an arm64 host"
[[ -f "$CONTRACT" ]] || fail "contract is missing"
git -C "$BGFX4CJ_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "BGFX4CJ_ROOT is not a Git checkout"

[[ "$(json_value "$CONTRACT" schema)" == "canghui.scene3d-bgfx-native-supply-contract.v1" ]] || fail "unsupported contract schema"
[[ "$(json_value "$CONTRACT" platform)" == "macos" ]] || fail "unsupported contract platform"

EXPECTED_COMMIT="$(json_value "$CONTRACT" bgfx4cjCommit)"
EXPECTED_ARCH="$(json_value "$CONTRACT" architecture)"
EXPECTED_SOURCE_DATE_EPOCH="$(json_value "$CONTRACT" sourceDateEpoch)"
EXPECTED_MINOS="$(json_value "$CONTRACT" minimumOS)"
EXPECTED_SDK="$(json_value "$CONTRACT" sdk)"
ACTUAL_COMMIT="$(git -C "$BGFX4CJ_ROOT" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$EXPECTED_COMMIT" ]] || fail "bgfx4cj source revision mismatch"
[[ "$(git -C "$BGFX4CJ_ROOT" show -s --format=%ct "$ACTUAL_COMMIT")" == "$EXPECTED_SOURCE_DATE_EPOCH" ]] || fail "bgfx4cj source date mismatch"
[[ "$(json_value "$CONTRACT" renderers.0)" == "Metal" ]] || fail "contract renderer order is invalid"
[[ "$(json_value "$CONTRACT" renderers.1)" == "Noop" ]] || fail "contract renderer order is invalid"

ARCHIVE_NAMES=(libbx.a libbimg.a libbgfx.a)
ACTUAL_SHAS=()
for index in 0 1 2; do
    name="${ARCHIVE_NAMES[$index]}"
    [[ "$(json_value "$CONTRACT" "archives.$index.name")" == "$name" ]] || fail "contract archive order is invalid"
    path="$BGFX_NATIVE_ROOT/$name"
    [[ -f "$path" ]] || fail "$name is missing"
    archs="$(/usr/bin/lipo -archs "$path" 2>/dev/null || true)"
    [[ "$archs" == "$EXPECTED_ARCH" ]] || fail "$name architecture is '$archs', expected '$EXPECTED_ARCH'"
    expected_sha="$(json_value "$CONTRACT" "archives.$index.sha256")"
    actual_sha="$(archive_sha "$path")"
    [[ "$actual_sha" == "$expected_sha" ]] || fail "$name digest does not match the frozen source/build contract"
    build_tuple="$(archive_build_tuple "$path")"
    [[ "$build_tuple" == "1 $EXPECTED_MINOS $EXPECTED_SDK" ]] || fail "$name deployment metadata is '$build_tuple'"
    ACTUAL_SHAS+=("$actual_sha")
done

BGFX_SYMBOLS="$(/usr/bin/nm -gU "$BGFX_NATIVE_ROOT/libbgfx.a")"
[[ "$BGFX_SYMBOLS" == *'__ZN4bgfx3mtl'* ]] || fail "libbgfx.a has no Metal renderer symbols"
[[ "$BGFX_SYMBOLS" == *'__ZN4bgfx4noop'* ]] || fail "libbgfx.a has no Noop renderer symbols"

mkdir -p "$(dirname "$RECEIPT")"
cat >"$RECEIPT" <<EOF
{
  "schema": "canghui.scene3d-bgfx-native-supply-receipt.v1",
  "contractId": "$(json_value "$CONTRACT" contractId)",
  "status": "accepted",
  "platform": "macos",
  "architecture": "$EXPECTED_ARCH",
  "bgfx4cjCommit": "$ACTUAL_COMMIT",
  "sourceDateEpoch": "$EXPECTED_SOURCE_DATE_EPOCH",
  "minimumOS": "$EXPECTED_MINOS",
  "sdk": "$EXPECTED_SDK",
  "renderers": ["Metal", "Noop"],
  "buildOptions": [
    "$(json_value "$CONTRACT" buildOptions.0)",
    "$(json_value "$CONTRACT" buildOptions.1)",
    "$(json_value "$CONTRACT" buildOptions.2)",
    "$(json_value "$CONTRACT" buildOptions.3)",
    "$(json_value "$CONTRACT" buildOptions.4)",
    "$(json_value "$CONTRACT" buildOptions.5)",
    "$(json_value "$CONTRACT" buildOptions.6)",
    "$(json_value "$CONTRACT" buildOptions.7)",
    "$(json_value "$CONTRACT" buildOptions.8)"
  ],
  "archives": [
    {"name": "libbx.a", "sha256": "${ACTUAL_SHAS[0]}"},
    {"name": "libbimg.a", "sha256": "${ACTUAL_SHAS[1]}"},
    {"name": "libbgfx.a", "sha256": "${ACTUAL_SHAS[2]}"}
  ],
  "claims": {
    "nativeArchivesCommitted": false,
    "crossPlatformBinaryDistribution": false,
    "completeApplicationMacOS12Runtime": false
  }
}
EOF

[[ "$(json_value "$RECEIPT" schema)" == "canghui.scene3d-bgfx-native-supply-receipt.v1" ]] || fail "generated receipt is unreadable"
printf 'scene3d bgfx native supply accepted: %s\n' "$RECEIPT"
