# NativeScene

`chui.native_scene` is the SDL-free display-list boundary for embedded mobile
surfaces. It lets Cangjie product code emit deterministic Draw IR while UIKit,
ArkUI or another native host owns pixel presentation.

The package currently provides:

- `NativeScene`, `NativeRect` and `NativeColor`;
- fill, rounded panel, line, circle, text, symbol and clip commands;
- button and progress helpers;
- `NativeScenePointer`, including press, move-out cancellation, release and a
  deterministic synthetic tap used by host acceptance tests;
- `copyNativeSceneUtf8ToCaller`, a two-pass caller-buffer helper that reports
  the UTF-8 byte length before copying and fails closed on invalid capacity;
- a stable `canghui.native-scene.v0` JSON report with Draw IR and hit regions.

Rounded stroke commands encode their geometry width as `width` and their
stroke thickness as `strokeWidth`. Hosts should accept the legacy `width`
fallback for reports produced before this distinction was introduced.

The package does not own product state, native text shaping, accessibility,
IME, retained SceneDiff or platform packaging. Consumers import
`chui.native_scene` directly; the umbrella `chui` export remains unchanged while
the mobile renderer is incubating.
