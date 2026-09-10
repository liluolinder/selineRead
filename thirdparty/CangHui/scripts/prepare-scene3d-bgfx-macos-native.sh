#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to the pinned bgfx4cj Git checkout}"
: "${BGFX_NATIVE_ROOT:?set BGFX_NATIVE_ROOT to an accepted bgfx native supply}"
OUTPUT_ROOT="${1:?usage: prepare-scene3d-bgfx-macos-native.sh <empty-output-directory>}"
SDL_ROOT="${CANGHUI_SDL_NATIVE_ROOT:-$ROOT/sdl/.sdl3}"
CONTRACT_RECEIPT="$OUTPUT_ROOT/bgfx-supply-receipt.json"
PACK_RECEIPT="$OUTPUT_ROOT/canghui-scene3d-bgfx-macos-native-receipt.json"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/canghui-scene3d-bgfx-macos-native.XXXXXX")"
trap 'rm -rf "$WORK_ROOT"' EXIT

fail_prepare() {
    printf 'scene3d macOS native preparation rejected: %s\n' "$1" >&2
    exit 1
}

if [[ -e "$OUTPUT_ROOT" ]] && [[ -n "$(find "$OUTPUT_ROOT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail_prepare "output directory must be absent or empty: $OUTPUT_ROOT"
fi
[[ ! -L "$OUTPUT_ROOT" ]] || fail_prepare "output directory must not be a symbolic link"
for input_root in "$BGFX4CJ_ROOT" "$BGFX_NATIVE_ROOT" "$SDL_ROOT" "$OUTPUT_ROOT"; do
    [[ "$input_root" != *[[:space:]]* && "$input_root" != *\"* && "$input_root" != *\\* ]] || \
        fail_prepare "native input root contains unsupported characters: $input_root"
done
for required in libbgfx.a libbimg.a libbx.a; do
    [[ -f "$BGFX_NATIVE_ROOT/$required" ]] || fail_prepare "missing $required"
done
for required in libSDL3.dylib libSDL3_ttf.dylib; do
    [[ -f "$SDL_ROOT/$required" ]] || fail_prepare "missing $required"
done
command -v xcrun >/dev/null 2>&1 || fail_prepare "xcrun is required"
command -v shasum >/dev/null 2>&1 || fail_prepare "shasum is required"

mkdir -p "$OUTPUT_ROOT" "$WORK_ROOT/clang-cache"
BGFX4CJ_ROOT="$BGFX4CJ_ROOT" BGFX_NATIVE_ROOT="$BGFX_NATIVE_ROOT" \
    "$ROOT/scripts/verify-scene3d-bgfx-native-supply.sh" "$CONTRACT_RECEIPT"

xcrun clang -arch arm64 -mmacosx-version-min=12.0 -fobjc-arc \
    -fno-objc-msgsend-selector-stubs -fmodules \
    -fmodules-cache-path="$WORK_ROOT/clang-cache" \
    -c "$ROOT/packages/scene3d-bgfx/platform/macos/macos_embedded_metal_host.m" \
    -o "$WORK_ROOT/macos_embedded_metal_host.o"
ZERO_AR_DATE=1 ar rcs "$OUTPUT_ROOT/libcanghui_embedded_metal_host.a" \
    "$WORK_ROOT/macos_embedded_metal_host.o"

[[ "$(/usr/bin/lipo -archs "$OUTPUT_ROOT/libcanghui_embedded_metal_host.a")" == "arm64" ]] || \
    fail_prepare "embedded Metal host archive is not arm64"
HOST_SYMBOLS="$(/usr/bin/nm -gU "$OUTPUT_ROOT/libcanghui_embedded_metal_host.a")"
[[ "$HOST_SYMBOLS" == *'_chui_macos_embedded_metal_create'* ]] || \
    fail_prepare "embedded Metal host archive is missing its create symbol"
HOST_LINK_OPTIONS="$(/usr/bin/otool -l "$OUTPUT_ROOT/libcanghui_embedded_metal_host.a")"
[[ "$HOST_LINK_OPTIONS" == *'string #1 -lc++'* ]] || \
    fail_prepare "embedded Metal host archive is missing libc++ autolink metadata"
for framework in Metal QuartzCore Cocoa Foundation IOKit; do
    [[ "$HOST_LINK_OPTIONS" == *"string #2 $framework"* ]] || \
        fail_prepare "embedded Metal host archive is missing $framework autolink metadata"
done

for artifact in libbgfx.a libbimg.a libbx.a; do
    cp "$BGFX_NATIVE_ROOT/$artifact" "$OUTPUT_ROOT/$artifact"
done
for artifact in libSDL3.dylib libSDL3_ttf.dylib; do
    cp "$SDL_ROOT/$artifact" "$OUTPUT_ROOT/$artifact"
done

hash_of() {
    shasum -a 256 "$OUTPUT_ROOT/$1" | awk '{print $1}'
}
cat >"$PACK_RECEIPT" <<EOF
{
  "schema": "canghui.scene3d-bgfx-macos-native-receipt.v1",
  "target": "aarch64-apple-darwin",
  "provider": "canghui_scene3d_bgfx",
  "artifacts": {
    "libcanghui_embedded_metal_host.a": "$(hash_of libcanghui_embedded_metal_host.a)",
    "libbgfx.a": "$(hash_of libbgfx.a)",
    "libbimg.a": "$(hash_of libbimg.a)",
    "libbx.a": "$(hash_of libbx.a)",
    "libSDL3.dylib": "$(hash_of libSDL3.dylib)",
    "libSDL3_ttf.dylib": "$(hash_of libSDL3_ttf.dylib)"
  }
}
EOF
[[ "$(/usr/bin/plutil -extract schema raw -o - "$PACK_RECEIPT")" == \
    "canghui.scene3d-bgfx-macos-native-receipt.v1" ]] || \
    fail_prepare "generated native pack receipt is unreadable"

printf 'CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR=%s\n' "$OUTPUT_ROOT"
printf 'scene3d macOS native receipt: %s\n' "$PACK_RECEIPT"
