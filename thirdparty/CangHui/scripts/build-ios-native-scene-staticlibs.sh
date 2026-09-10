#!/bin/sh

set -eu

MODE="${1:-all}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="${2:-$ROOT_DIR/target/ios-native-scene}"

: "${CANGJIE_HOME:?set CANGJIE_HOME to a Cangjie SDK with iOS targets}"
CJC="$CANGJIE_HOME/bin/cjc"

if [ ! -x "$CJC" ]; then
    echo "cjc not found at $CJC" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

build_target() {
    target="$1"
    output_name="$2"
    "$CJC" \
        "$ROOT_DIR/src/native_scene/native_scene.cj" \
        --target="$target" \
        --output-type=staticlib \
        -O2 \
        -o "$OUTPUT_DIR/$output_name"

    if nm -u "$OUTPUT_DIR/$output_name" | grep -E '(_SDL_|_TTF_)' >/dev/null 2>&1; then
        echo "native-scene archive unexpectedly references SDL or SDL_ttf" >&2
        exit 1
    fi
}

case "$MODE" in
    all)
        build_target aarch64-apple-ios libcanghui_native_scene_ios.a
        build_target aarch64-apple-ios-simulator libcanghui_native_scene_ios_simulator.a
        ;;
    device)
        build_target aarch64-apple-ios libcanghui_native_scene_ios.a
        ;;
    simulator)
        build_target aarch64-apple-ios-simulator libcanghui_native_scene_ios_simulator.a
        ;;
    *)
        echo "usage: $0 [all|device|simulator] [output-dir]" >&2
        exit 2
        ;;
esac

echo "CangHui iOS native-scene static libraries: $OUTPUT_DIR"
