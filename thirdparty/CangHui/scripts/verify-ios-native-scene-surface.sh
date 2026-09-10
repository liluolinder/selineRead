#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ROOT="${1:-${ROOT_DIR}/target/ios-native-scene-surface}"
DEPLOYMENT_TARGET="${CANGHUI_IOS_DEPLOYMENT_TARGET:-13.0}"

compile_target() {
    local sdk="$1"
    local minimum_flag="$2"
    local output="$3"
    local clang sdk_path
    clang="$(xcrun --sdk "${sdk}" --find clang)"
    sdk_path="$(xcrun --sdk "${sdk}" --show-sdk-path)"
    mkdir -p "${output}/modules"
    for source in \
        CangHuiUIKitHostView.m \
        CangHuiDisplayLinkDriver.m \
        CangHuiMetalSurfaceView.m \
        CangHuiNativeSceneSurfaceView.m
    do
        "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
            -fobjc-arc -fblocks -fmodules -Werror -Wall -Wextra \
            -fmodules-cache-path="${output}/modules" \
            -I "${ROOT_DIR}/platform/ios/include" \
            -c "${ROOT_DIR}/platform/ios/runtime/${source}" \
            -o "${output}/${source%.m}.o"
    done
}

rm -rf "${OUTPUT_ROOT}"
compile_target iphonesimulator \
    "-mios-simulator-version-min=${DEPLOYMENT_TARGET}" "${OUTPUT_ROOT}/simulator"
compile_target iphoneos \
    "-miphoneos-version-min=${DEPLOYMENT_TARGET}" "${OUTPUT_ROOT}/device"

printf 'CangHui iOS native-scene surface compile passed: %s\n' "${OUTPUT_ROOT}"
