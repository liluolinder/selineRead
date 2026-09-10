#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to the pinned bgfx4cj Git checkout}"
OUTPUT_ROOT="${1:?usage: build-scene3d-bgfx-native-supply.sh <empty-output-directory> [receipt.json]}"
RECEIPT="${2:-$OUTPUT_ROOT/canghui-scene3d-bgfx-native-supply-receipt.json}"
EXPECTED_COMMIT="149e9d856de361c7c2afb813a68783f7d85fa5c9"
SOURCE_ROOT="$OUTPUT_ROOT/source"
BUILD_ROOT="$OUTPUT_ROOT/build"
SOURCE_ARCHIVE="$OUTPUT_ROOT/bgfx4cj-$EXPECTED_COMMIT.tar"
SOURCE_DATE_EPOCH="$(git -C "$BGFX4CJ_ROOT" show -s --format=%ct "$EXPECTED_COMMIT")"

for command_name in cmake ninja git; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf '%s is required.\n' "$command_name" >&2
        exit 1
    }
done

ACTUAL_COMMIT="$(git -C "$BGFX4CJ_ROOT" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]]; then
    printf 'bgfx4cj source revision mismatch.\n' >&2
    exit 1
fi

if [[ -e "$OUTPUT_ROOT" ]] && [[ -n "$(find "$OUTPUT_ROOT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    printf 'Output directory must be absent or empty: %s\n' "$OUTPUT_ROOT" >&2
    exit 1
fi
mkdir -p "$OUTPUT_ROOT"

git -C "$BGFX4CJ_ROOT" archive \
    --format=tar \
    --output="$SOURCE_ARCHIVE" \
    "$EXPECTED_COMMIT"
mkdir -p "$SOURCE_ROOT"
tar -xf "$SOURCE_ARCHIVE" -C "$SOURCE_ROOT"

cmake \
    -S "$ROOT/packages/scene3d-bgfx/native-supply" \
    -B "$BUILD_ROOT" \
    -G Ninja \
    -DBGFX4CJ_ROOT="$SOURCE_ROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
env \
    SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
    ZERO_AR_DATE=1 \
    cmake --build "$BUILD_ROOT" --target bx bimg bgfx

for archive_name in libbx.a libbimg.a libbgfx.a; do
    cmake -E copy "$BUILD_ROOT/$archive_name" "$OUTPUT_ROOT/$archive_name"
done

BGFX_NATIVE_ROOT="$OUTPUT_ROOT" \
    "$ROOT/scripts/verify-scene3d-bgfx-native-supply.sh" "$RECEIPT"
printf 'scene3d bgfx native archives: %s\n' "$OUTPUT_ROOT"
