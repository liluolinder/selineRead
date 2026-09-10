# iOS Host Bootstrap

CangHui embeds its platform-neutral host contracts into an Xcode application as
a Cangjie static library. The platform host may be Objective-C,
Objective-C++ or Swift. Applications use the supplied Objective-C bootstrap
helper instead of writing a separate C shim or calling an `@C` symbol directly
from an arbitrary UIKit thread.

## Build

Use a Cangjie SDK that contains `ios_aarch64_cjnative` and
`ios_simulator_aarch64_cjnative` targets:

```bash
export CANGJIE_HOME=/path/to/cangjie-ios-sdk
./scripts/build-ios-host-staticlibs.sh
```

The default output is ignored under `target/ios-host/`:

- `libcanghui_host_ios.a`
- `libcanghui_host_ios_simulator.a`

The build also emits `libcangjiegui_host_ios*.a` compatibility aliases for
existing hosts. Pass `device` or `simulator` as the first argument to build one
target. The second argument overrides the output directory.

The iOS static package is compiled with `-O2`. This is part of the tested
bootstrap contract for Cangjie `1.3.0-alpha.20260725010033`: its unoptimized
static-package safepoint stub does not return to the original call site, while
the optimized form keeps the safepoint slow path local to the function.

## Xcode Link Contract

For the selected device or simulator target:

1. Add the generated CangHui archive.
2. Add `section.o`, then `cjstart.o`, from the matching Cangjie runtime target.
3. Link the Cangjie runtime and required standard-library archives. The
   repository probe uses `std-collection`, `std-math`, `std-sync`, `std-time`,
   `std-binary`, `std-convert`, `std-io`, `std-core`, `runtime`,
   `boundscheck-static` and `cangjie-thread`; adding every `.a` from the matching
   runtime directory follows the broader toolchain guidance.
4. Link UIKit, Foundation, QuartzCore, Metal and `libc++`.
5. Set Dead Code Stripping to `No`.
6. With Xcode 15 or later, add `-Wl,-no_compact_unwind` when required by the
   linker.
7. Add `platform/ios/bootstrap/CangHuiRuntimeBootstrap.m` and the Objective-C
   sources under `platform/ios/runtime` to the native target, then expose
   `platform/ios/include` as a header search path.

The target runtime must match the application destination:

- device: `$CANGJIE_HOME/lib/ios_aarch64_cjnative`
- Apple Silicon simulator:
  `$CANGJIE_HOME/lib/ios_simulator_aarch64_cjnative`

## Runtime Bootstrap

Include `CangHuiRuntimeBootstrap.h` and `CangHuiHost.h`. Start the runtime from a
background queue using the executable basename registered in the final app,
then enter exported Cangjie functions through `canghui_runtime_run_task`:

```objective-c
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    const char *name =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(name, 5000000000LL);
    CangHuiRuntimeTaskResult task =
        canghui_runtime_run_task(my_cangjie_entry, NULL, 5000000000LL);
});
```

The helper performs the process-wide sequence:

1. `InitCJRuntime`;
2. fixed scheduler creation with `InitUIScheduler` and `RunUIScheduler`;
3. `InitCJLibrary` using the final executable basename;
4. foreign-thread invocation with `RunCJTask` and bounded result wait.

`InitCJLibraryStub` is not a package initializer and is not used by this path.
The bootstrap start function is process-wide; later calls return the first
result. Application code should initialize it once before renderer startup.

## Replayable Probe

The repository probe recompiles the Cangjie static library, compiles the native
helper and UIKit app, links the final executable, installs it and requires a
result with `passed=1`:

```text
CANGHUI_IOS_SURFACE result passed=1 metal=ready drawable=ready attached=1 attaches=2 resizes=1 detaches=1 generation=2 frames=<positive> touches=1 pointers=1 traits=1
```

Run the simulator acceptance with no signing configuration:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/verify-ios-static-package.sh simulator
```

The script uses a booted simulator, or boots the first available simulator when
none is running. Set `CANGHUI_IOS_SIMULATOR_DEVICE` to a name or identifier to
select one explicitly.

Physical-device acceptance requires values owned by the local developer
environment; none are stored in the repository:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
CANGHUI_IOS_DEVICE=<device-name-or-id> \
CANGHUI_IOS_BUNDLE_ID=<profile-bundle-id> \
CANGHUI_IOS_CODESIGN_IDENTITY=<identity-name-or-sha> \
CANGHUI_IOS_PROVISIONING_PROFILE=/path/to/profile.mobileprovision \
    ./scripts/verify-ios-static-package.sh device
```

The device must be unlocked. The script validates the provisioning profile
against the requested bundle id before signing and installing the app.

The probe intentionally renders only a Cangjie-selected Metal clear color. Its
high-contrast diagnostic panel remains above the surface and explicitly says
that the CangHui scene is not mounted, so a successful native-surface probe cannot
be mistaken for a product application screen.

## Surface Proxy

The implemented iOS adapter follows an XComponent-like proxy model:

- UIKit owns a `UIView` backed by `CAMetalLayer` or `MTKView`.
- UIKit forwards lifecycle, safe-area, touch, Pencil/indirect-pointer hover,
  trait, surface-generation and `CADisplayLink` events through an integer-only
  C ABI.
- `IOSNativeSurfaceBridge` commits the host-owned surface facts through the
  Cangjie UI-owner queue and rejects stale generations.
- The probe uses the Cangjie-selected clear color for a real Metal clear pass.
- Native callbacks are marshalled through the runtime task gate onto the fixed
  Cangjie scheduler thread.

The host still owns signing and packaging. This proof does not yet connect the
full declarative CangHui scene renderer, IME or accessibility to UIKit.

## Native Scene Static Package

Embedded iOS consumers that need Cangjie-owned product scenes without the
desktop SDL dependency closure can build the focused `chui.native_scene`
package:

```bash
CANGJIE_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/build-ios-native-scene-staticlibs.sh simulator
```

The package emits `canghui.native-scene.v0` Draw IR, bounded hit regions and
press/move/release cancellation without SDL or a C shim. UIKit remains the
pixel presenter. This is a mobile display-list boundary, not a claim that the
desktop `Renderer.recordingHeadless()` archive is link-safe on iOS.

Applications can use `CangHuiNativeSceneSurfaceView` instead of copying the
native presenter. The view accepts one caller-buffer render function and
reuses the framework-owned UIKit/Metal lifecycle, display link and ordered
input path. It paints the native-scene Draw IR with CoreGraphics, resolves
`sf` symbols through SF Symbols and presents the result through the shared
CAMetalLayer. Product state, labels and acceptance receipts stay in the
consumer application.

The render callback uses a two-step event contract: the sizing callback applies
the input event exactly once, while the buffer-copy callback receives the
`none` event and snapshots the resulting state. Render functions must keep a
`none` event side-effect free.

## Host Modes

- `OwnedWindow` follows SDL3's callback application model. SDL owns the iOS
  window, event pump and renderer; this is preferred for a standalone app.
- `EmbeddedSurface` keeps the UIKit `CAMetalLayer/MTKView` proxy described
  above; this is preferred when CangHui is one surface inside an existing
  application.

Both modes require a launch screen, high-pixel-density configuration, bundled
resources and correctly embedded or statically linked dependencies. Current
device and simulator proof covers runtime, scheduler, static-package
initialization, N2C task entry, ABI return, UIKit lifecycle and safe area,
touch, frame clock, generation replay, drawable acquisition and a Metal clear
pass. Full CangHui scene rendering, IME, accessibility and product acceptance
remain separate platform work.
