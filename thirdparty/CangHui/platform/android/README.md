# Android Host Runtime Probe

This directory contains the Android-specific CangHui host adapter and its
device acceptance probe. It owns the Activity and native-surface lifecycle,
multi-pointer/key/IME ingress, an explicit system-bars policy, a private JNI
receipt boundary, a minimal NDK renderer, and a standalone probe APK assembled
without Gradle.

It does not contain a Cangjie Android runtime, a CangHui scene renderer,
accessibility integration, or production application packaging.

## Host Contract

`CangHuiNativeSurfaceHost` registers as a `SurfaceHolder.Callback2` and keeps
the `ANativeWindow` behind an opaque handle. Every successful attach and detach
advances a monotonic generation. A detach callback must present the generation
returned by its attach; a stale callback cannot release a newer native window.

The native side owns each `ANativeWindow_fromSurface` reference until it is
replaced, detached, or destroyed. Width, height, event counts, rendered frame
count and the device-proof receipt are synchronized with the same owner state.

`CangHuiSurfaceActivity` creates the host and `CangHuiAndroidView` in
`onCreate`, binds callbacks in `onStart`, detaches in `onStop`, and closes the
native owner in `onDestroy`.

## Input, IME And Renderer Probe

`CangHuiAndroidView` is focusable and forwards the complete Android pointer
snapshot for every `MotionEvent`, including pointer ids, coordinates and
pressure for multi-touch. It also forwards non-system key events to private JNI
entrypoints. Its `InputConnection` forwards composing, commit, deletion, finish
and selection operations while retaining Android's normal editable behavior.

Touch only requests focus. It does not show the soft keyboard. An Activity or
control that owns a text-editing session must call `showInputMethod()` and may
later call `hideInputMethod()` explicitly.

`CangHuiSurfaceActivity.setSystemBarsMode(...)` exposes three Android-only
policies:

- `VISIBLE`: status and navigation bars remain visible and inset content;
- `EDGE_TO_EDGE`: bars remain visible while content extends behind them;
- `IMMERSIVE_STICKY`: status and navigation bars are hidden and may be revealed
  transiently with a system swipe.

The implementation uses `WindowInsetsController` on API 30+ and compatible
system-UI flags on API 26-29. The probe Activity selects `IMMERSIVE_STICKY`.

The NDK renderer locks the attached `ANativeWindow`, presents an RGBA clear
whose color changes with pointer/key/IME counters, and draws a white marker at
the last pointer position. Rendering after attach and each ingress event proves
that lifecycle, input and frame presentation share one live native owner.

This renderer is deliberately a host proof. It does not consume CangHui Draw IR
or claim CangHui widget rendering.

## Static Proof

All build output stays outside the repository:

```bash
ANDROID_SDK_ROOT=/path/to/android-sdk \
  CANGHUI_ANDROID_OUTPUT=/private/tmp/canghui-android-host \
  ./scripts/verify-android-toolchain.sh

ANDROID_SDK_ROOT=/path/to/android-sdk \
  CANGHUI_ANDROID_APK_OUTPUT=/private/tmp/canghui-android-apk \
  ./scripts/verify-android-apk.sh
```

The first verifier compiles Java plus `arm64-v8a` and `x86_64` JNI libraries,
checks all private JNI exports and inspects lifecycle/input/IME bytecode. The
second verifier assembles `classes.dex`, both native libraries and the manifest,
then runs zip alignment and Android APK signature verification.

## Device Proof

The optional device mode installs and launches the probe, injects a synthetic
two-pointer sequence plus real ADB pointer/keyboard activity, exercises the IME
bridge explicitly, checks the immersive system-bars mode, resumed Activity and
installed package, and preserves logcat plus a screen capture in the independent
output directory:

```bash
ANDROID_SDK_ROOT=/path/to/android-sdk \
  CANGHUI_ANDROID_APK_OUTPUT=/private/tmp/canghui-android-device \
  ./scripts/verify-android-apk.sh --device ADB_SERIAL
```

The generated signing key is probe-only and is created inside the output
directory. It is not a release or production signing identity.

## Fail-Closed Cangjie Gate

`verify-android-toolchain.sh --require-cangjie` requires an actual Cangjie
Android cross SDK. A normal macOS Cangjie SDK is insufficient: the Android SDK
must provide `modules/linux_android_aarch64_cjnative` and matching Android
runtime libraries. The verifier exits `2` when either side is missing.

## Open Work

- Obtain and validate a Cangjie Android cross SDK and runtime.
- Cross-compile the CangHui Cangjie package without changing the common ABI.
- Bind the host to the real CangHui renderer while preserving generation gates.
- Add accessibility and production application lifecycle integration.
- Add release-owned application identity, resources, signing and distribution.

The current proof is an Android Java/JNI/NDK host runtime and APK acceptance
slice. It is not Cangjie Android runtime support, product application
acceptance, release, production or LTS proof.
