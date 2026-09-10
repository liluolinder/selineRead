#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to a bgfx4cj Git checkout}"
: "${BGFX_NATIVE_ROOT:?set BGFX_NATIVE_ROOT to the directory containing libbgfx.a, libbimg.a and libbx.a}"
OUTPUT="${1:-${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal.png}"
RECEIPT="${2:-${OUTPUT%.*}.native-supply.json}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

fail_capture() {
    printf 'scene3d Metal capture rejected: %s\n' "$1" >&2
    exit 1
}

for link_root in "$BGFX_NATIVE_ROOT" "$ROOT/sdl/.sdl3"; do
    if [[ "$link_root" == *[[:space:]]* || "$link_root" == *\"* || "$link_root" == *\\* ]]; then
        printf 'Native link roots contain unsupported characters: %s\n' "$link_root" >&2
        exit 1
    fi
done

"$ROOT/scripts/verify-scene3d-bgfx-native-supply.sh" "$RECEIPT"

mkdir -p "$STAGE/bgfx4cj" "$STAGE/scene3d-bgfx" "$STAGE/scene3d-bgfx-metal-capture"
git -C "$BGFX4CJ_ROOT" archive --format=tar HEAD -o "$STAGE/bgfx4cj.tar"
tar -xf "$STAGE/bgfx4cj.tar" -C "$STAGE/bgfx4cj"
cp -R "$ROOT/packages/scene3d-bgfx/src" "$STAGE/scene3d-bgfx/src"
cp -R "$ROOT/examples/scene3d-bgfx-metal-capture/src" "$STAGE/scene3d-bgfx-metal-capture/src"

cat >"$STAGE/bgfx4cj/cjpm.toml" <<EOF
[package]
  cjc-version = "1.1.0"
  name = "bgfx4cj"
  description = "This project encapsulates the C++ library bgfx into the Cangjie ecosystem"
  version = "1.0.0"
  output-type = "static"
  compile-option = "-Woff unused -Woff parser --diagnostic-format=noColor"
  link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
EOF

cat >"$STAGE/scene3d-bgfx/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "canghui_scene3d_bgfx"
version = "0.1.0"
output-type = "static"
description = "Optional bgfx4cj Scene3D driver for CangHui"
license = "Apache-2.0"
link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
chui = { path = "$ROOT" }
sdl = { path = "$ROOT/sdl" }
bgfx4cj = { path = "$STAGE/bgfx4cj" }
EOF

cat >"$STAGE/scene3d-bgfx-metal-capture/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "canghui_scene3d_bgfx_metal_capture"
version = "0.1.0"
output-type = "executable"
description = "CangHui Scene3D bgfx Metal capture example"
license = "Apache-2.0"
link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
chui = { path = "$ROOT" }
canghui_scene3d_bgfx = { path = "$STAGE/scene3d-bgfx" }
EOF

(cd "$STAGE/scene3d-bgfx" && cjpm test --no-progress)
(cd "$STAGE/scene3d-bgfx-metal-capture" && cjpm build)
(cd "$ROOT/tools/cuic" && cjpm build)
RUN_LOG="$STAGE/capture.log"
"$ROOT/tools/cuic/bin/cuic" prnt macos "$STAGE/scene3d-bgfx-metal-capture" --output "$OUTPUT" --frames 12 | tee "$RUN_LOG"
test -s "$OUTPUT"
grep -Fq 'submit=accepted detail=4 semantic debug entities submitted present=accepted' "$RUN_LOG" || \
    fail_capture "runtime did not submit exactly four visible semantic entities"
grep -Fq 'camera=non-default transform=non-default' "$RUN_LOG" || \
    fail_capture "runtime did not declare the non-default camera and transform fixture"
grep -Fq 'renderer=Metal' "$RUN_LOG" || fail_capture "runtime did not report the Metal renderer"

command -v magick >/dev/null 2>&1 || fail_capture "ImageMagick 'magick' is required for pixel proof"
read -r WIDTH HEIGHT OPAQUE COLORS CORNER <<<"$(
    magick identify -format '%w %h %[opaque] %k %[pixel:p{0,0}]' "$OUTPUT"
)"
[[ "$WIDTH" == "1280" && "$HEIGHT" == "840" ]] || \
    fail_capture "dimensions are ${WIDTH}x${HEIGHT}, expected 1280x840"
[[ "$OPAQUE" == "True" ]] || fail_capture "capture is not fully opaque"
[[ "$COLORS" -ge 14 ]] || fail_capture "capture has only $COLORS colors"
[[ "$CORNER" == "srgb(58,128,104)" ]] || \
    fail_capture "corner background is '$CORNER', expected srgb(58,128,104)"

BOUNDS="$(magick "$OUTPUT" -alpha off -trim -format '%wx%h%O' info:)"
GEOMETRY_PIXELS="$(
    magick "$OUTPUT" -alpha off \
        -fill white +opaque '#3A8068' \
        -fill black -opaque '#3A8068' \
        -format '%[fx:round(mean*w*h)]' info:
)"
color_pixels() {
    magick "$OUTPUT" -alpha off \
        -fill black +opaque "$1" \
        -fill white -opaque "$1" \
        -format '%[fx:round(mean*w*h)]' info:
}
FLOOR_PIXELS="$(color_pixels '#697D86')"
ROUTE_PIXELS="$(color_pixels '#FFB743')"
VEHICLE_PIXELS="$(color_pixels '#D45242')"
USER_MARKER_PIXELS="$(color_pixels '#2EA3F5')"
[[ "$BOUNDS" == "553x329+362+323" ]] || \
    fail_capture "geometry bounds are '$BOUNDS', expected 553x329+362+323"
[[ "$GEOMETRY_PIXELS" -ge 85000 && "$GEOMETRY_PIXELS" -le 105000 ]] || \
    fail_capture "geometry pixel count $GEOMETRY_PIXELS is outside the bounded proof range"
[[ "$FLOOR_PIXELS" -ge 60000 ]] || fail_capture "floor semantic color has only $FLOOR_PIXELS pixels"
[[ "$ROUTE_PIXELS" -ge 2000 ]] || fail_capture "route semantic color has only $ROUTE_PIXELS pixels"
[[ "$VEHICLE_PIXELS" -ge 2500 ]] || fail_capture "vehicle semantic color has only $VEHICLE_PIXELS pixels"
[[ "$USER_MARKER_PIXELS" -ge 1500 ]] || \
    fail_capture "user-marker semantic color has only $USER_MARKER_PIXELS pixels"

printf 'scene3d Metal capture: %s\n' "$OUTPUT"
printf 'scene3d native supply receipt: %s\n' "$RECEIPT"
printf 'scene3d pixel proof: %sx%s opaque=%s colors=%s background=#3A8068 bounds=%s geometryPixels=%s\n' \
    "$WIDTH" "$HEIGHT" "$OPAQUE" "$COLORS" "$BOUNDS" "$GEOMETRY_PIXELS"
printf 'scene3d semantic palette proof: floor=%s route=%s vehicle=%s userMarker=%s\n' \
    "$FLOOR_PIXELS" "$ROUTE_PIXELS" "$VEHICLE_PIXELS" "$USER_MARKER_PIXELS"
