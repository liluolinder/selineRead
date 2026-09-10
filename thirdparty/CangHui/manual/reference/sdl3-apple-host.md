# SDL3 Apple Host Notes

**English** | [中文](sdl3-apple-host.zh-CN.md)

## Sources

- `Ravbug/sdl3-sample@d6c3c1b46cfab879a4cae71e3da5fb908dc02563`
  under CC0-1.0.
- `KevinVitale/SwiftSDL@c9c26670c6aaa8130001064e3133a305082f70dc`
  under MIT.

The projects were reviewed as design references. No Swift or C++ source was
copied into CangHui.

## Host Modes

An SDL3 application and an embedded native view are different deployment
shapes and should not be forced through one window model:

- `OwnedWindow`: SDL3 owns application callbacks, event pumping, the window
  and renderer. This is the preferred route for a standalone CangHui app.
- `EmbeddedSurface`: UIKit, HarmonyOS or another application owns the native
  view and forwards a generation-bearing surface to CangHui.

Both modes share `HostApplicationLoop`, host lifecycle and input services, and
the same Cangjie widget/layout tree.

## Callback Lifecycle

SDL3's `SDL_AppInit`, `SDL_AppIterate`, `SDL_AppEvent` and `SDL_AppQuit`
separate initialization, frame work, event delivery and guaranteed shutdown.
CangHui represents the portable part with `HostLoopResult` and
`HostApplicationLoop`. A platform adapter maps those callbacks onto the fixed
Cangjie scheduler thread.

## Apple Packaging Facts

The Apple host must preserve:

- a real application bundle and launch-screen declaration;
- high-pixel-density window creation;
- logical and pixel-size queries as separate facts;
- statically linked or correctly embedded runtime dependencies on iOS;
- resources placed in the application bundle rather than process-relative
  desktop paths.

## Existing Ownership Rules

SwiftSDL's generic pointer owner, destroy callback, typed SDL failure and
allocation helpers are useful binding patterns, but CangHui already provides
equivalent rules:

- `Resource` implementations with idempotent deterministic `close`;
- `CuiException` plus checked SDL return values;
- conversion of native arrays and strings into Cangjie-owned values before
  releasing SDL memory;
- reverse-order managed-resource shutdown in `DesktopApp`.

Adding a second generic owner abstraction would weaken the current ownership
model.

## Current Limits

- Cangjie cjthreads use an M:N scheduler, while a macOS SDL/AppKit window still
  requires creation and event pumping on one native thread. `cuic prnt`
  therefore sets `cjProcessorNum=1` only for its capture child. An ordinary app
  that suspends during startup after creating its window must use the same
  constraint or move that work behind the running event loop. `SdlWindow`
  checks the native thread identity before polling so this fails as an explicit
  exception instead of a cross-thread native crash. The first `close()` applies
  the same rule and enters no native teardown on a worker mismatch; completed
  close remains idempotent. `DesktopApp` keeps an originating frame-loop failure
  authoritative if shutdown also reports that affinity error. A failed
  wrong-thread close cannot recover a vanished owner loop, so applications must
  still arrange first close on the owner thread rather than treat the guard as
  cross-thread marshalling.
- Direct `SDL_EnterAppMainCallbacks` binding waits for a complete iOS host
  entry and lifecycle integration.
- SDL3 GPU wrappers and shader packaging belong to renderer-specific work.
- CangHui does not vendor SDL3 source or an XCFramework.
- A SwiftUI/UIKit application shell remains application-side code rather than
  shared framework source.
