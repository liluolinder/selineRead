#!/bin/sh

set -eu

MODE="${1:-static}"
OUTPUT_ROOT="${2:-target/ios-native-surface-contract}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ "$MODE" != "static" ]; then
    echo "usage: $0 [static] [output-dir]" >&2
    exit 2
fi

mkdir -p "$OUTPUT_ROOT"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
COMMON_FLAGS="-fobjc-arc -fblocks -fmodules -fmodules-cache-path=$OUTPUT_ROOT/modules -Werror -Wall -Wextra -mios-simulator-version-min=13.0"

xcrun --sdk iphonesimulator clang $COMMON_FLAGS \
    -isysroot "$SDK" \
    -I "$PROJECT_ROOT/platform/ios/include" \
    -x objective-c \
    -fsyntax-only \
    -include "$PROJECT_ROOT/platform/ios/include/CangHuiNativeSurface.h" \
    /dev/null

for source in \
    CangHuiUIKitHostView.m \
    CangHuiMetalSurfaceView.m \
    CangHuiDisplayLinkDriver.m \
    CangHuiNativeSceneSurfaceView.m
do
    path="$PROJECT_ROOT/platform/ios/runtime/$source"
    if [ -f "$path" ]; then
        xcrun --sdk iphonesimulator clang $COMMON_FLAGS \
            -isysroot "$SDK" \
            -I "$PROJECT_ROOT/platform/ios/include" \
            -c "$path" \
            -o "$OUTPUT_ROOT/${source%.m}.o"
    fi
done

xcrun --sdk iphonesimulator clang $COMMON_FLAGS \
    -isysroot "$SDK" \
    -I "$PROJECT_ROOT/platform/ios/include" \
    -c "$PROJECT_ROOT/platform/ios/probe/AppDelegate.m" \
    -o "$OUTPUT_ROOT/AppDelegate.o"

for symbol in \
    canghui_ios_surface_attach \
    canghui_ios_surface_resize \
    canghui_ios_surface_detach \
    canghui_ios_surface_safe_area \
    canghui_ios_surface_lifecycle \
    canghui_ios_surface_touch \
    canghui_ios_surface_pointer \
    canghui_ios_surface_traits \
    canghui_ios_surface_frame
do
    rg -q "int64_t ${symbol}\\(" "$PROJECT_ROOT/platform/ios/include/CangHuiNativeSurface.h"
done

private_home='/''Users/'
private_helper='_''helper/'
private_system='Hao''mo'
private_lane='HQ''/OD'
private_protocol='Parallel ''Convergence'
private_pattern="${private_home}|${private_helper}|${private_system}|${private_lane}|${private_protocol}"

if rg -n "$private_pattern" \
    "$PROJECT_ROOT/platform/ios" \
    "$PROJECT_ROOT/scripts/verify-ios-native-surface-contract.sh"
then
    echo "internal-only wording or paths found in the public iOS surface" >&2
    exit 1
fi

echo "CangHui iOS native-surface contract: passed"
