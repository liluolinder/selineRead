# CangHui Scene3D bgfx4cj Provider

Optional `Scene3DDriver` implementation backed by
[`bgfx4cj`](https://gitcode.com/Cangjie-TPC/bgfx4cj).

The package keeps bgfx handles and CFFI objects outside application code. A
platform host supplies the native window pointer and its matching serializable
surface identity when constructing `Bgfx4cjDriver`; applications use CangHui
`Scene3DProvider` contracts. The driver rejects an attach when that identity
does not match `Scene3DHostSurface.opaqueHandle`.

Current scope includes provider lifecycle, immutable backend-bound shader and
indexed-geometry resources, perspective/depth state, and a bounded semantic
low-poly scene. `Scene3DEntityKind` maps floor, route, vehicle, user, structure,
track, facility and exit snapshots onto slab, ribbon, box and marker families.
The default palette remains stable, while `BgfxSemanticPalette` lets a product
select normalized colors for those eight roles when it constructs the driver.
Identity, position, optional scale/rotation, visibility and an optional frame
camera stay in the sealed snapshot; product models do not enter this package.
Model/texture ingestion, picking and platform runtime certification remain
separate work.

`Scene3DBackend.Software` is an explicit metadata-only Noop verification lane:
it accepts sealed scene metadata and advances a clear frame without uploading
backend-specific shaders. Visible rendering still requires a matching native
backend and shader program.

On macOS, `MacOSSdlMetalHost` owns an SDL3 Metal window and extracts its native
`NSWindow` for the provider. `Bgfx4cjDriver` selects bgfx single-thread mode
before Metal initialization, avoiding a main-runloop initialization deadlock.
The host drains SDL events in `pump()` and exposes `shouldClose()` after a quit
request. A normal consumer loop must then detach and close; a bounded capture
proves pixels but does not by itself prove the user-close lifecycle.
The `scene3d-bgfx-metal-capture` example accepts `DesktopCaptureRequest` from
`cuic prnt`, uploads semantic vertex buffers plus one shared index topology and
Metal shader program, renders the eight generic entity classes, requests a
renderer backbuffer screenshot, and converts bgfx's 32-bit TGA output to the
BMP capture contract before `cuic` emits PNG. Verification checks both native
API receipts and bounded non-background pixels, so an accepted but uniform
frame is rejected.

## macOS arm64 consumption

The checked-in package is directly consumable as a CJPM source dependency. Its
`[ffi.c]` entries propagate the four provider-owned native archives to the final
consumer link; applications do not repeat bgfx, bimg, bx, libc++ or Apple
framework link flags.

First prepare one same-host native directory from the pinned bgfx4cj checkout,
an accepted archive supply and CangHui's bootstrapped SDL libraries:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/prepare-scene3d-bgfx-macos-native.sh \
  /tmp/canghui-scene3d-bgfx-macos-native

export CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR=/tmp/canghui-scene3d-bgfx-macos-native
export DYLD_LIBRARY_PATH="$CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR:${DYLD_LIBRARY_PATH:-}"
```

Then add the package beside `chui` in the application manifest. No provider
source needs to be copied into the application:

```toml
[dependencies]
chui = { path = "/path/to/CangHui" }
canghui_scene3d_bgfx = { path = "/path/to/CangHui/packages/scene3d-bgfx" }
```

[`scene3d-bgfx-metal-embedded`](../../examples/scene3d-bgfx-metal-embedded/) is
the complete checked-in consumer. It places a `CAMetalLayer` child surface in
the same CangHui window and constructs `MacOSEmbeddedMetalHost` from the
borrowed SDL window.

This is a source-package plus prepared same-host native-pack flow, not yet a
portable binary SDK. macOS x86_64, Windows, Linux and HarmonyOS providers remain
separate adapter work.

## Verification

The bounded macOS verification expects external source and archive locations:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/native-archives \
./scripts/verify-scene3d-bgfx-metal-embedded.sh \
  /tmp/scene3d-metal-embedded.bmp
```

The archive directory must contain `libbgfx.a`, `libbimg.a` and `libbx.a` built
for the frozen macOS arm64 Metal/Noop contract. Before linking, the verifier
checks the exact bgfx4cj revision, archive SHA-256 digests, architecture,
deployment metadata and renderer symbols. The embedded verifier then tests the
real provider package, builds the real example manifest and calls `cuic prnt`;
it does not synthesize replacement manifests or copy source into a staged
package. Its receipts and captures are current-host evidence, not a portable
binary release or a complete macOS 12 application-runtime claim. They also do
not prove a consumer's product mapping, fallback, meshes or listing artifact.

To reproduce the current-host archives from the pinned source checkout, use a
new empty output directory:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
./scripts/build-scene3d-bgfx-native-supply.sh \
  /tmp/canghui-bgfx-native
```

The build recipe freezes arm64, macOS 12, Metal plus Noop, the required ASTC
sources and Objective-C message-send setting. A build is accepted only when its
archives pass the same contract and receipt verifier; a different toolchain or
source result is rejected rather than silently promoted.

This package is Apache-2.0. Its `bgfx4cj` dependency is MIT-licensed and retains
its own upstream notices and dependency obligations.
