# Font Resolution

**English** | [中文](fonts.zh-CN.md)

CangHui ships the unmodified HarmonyOS Sans SC font and uses it as the default
cross-platform text face. Installing the font into the host operating system is
optional.

## Resolution Order

Each text run resolves faces in this order:

1. a family explicitly selected by a component, such as `Label.fontFamily`;
2. a family selected by `Theme.withFontFamily`;
3. a process-wide application family selected by `Fonts.useApplicationFamily`;
4. the packaged HarmonyOS Sans SC fallback;
5. a platform system UI font.

Families in the first three tiers must be registered with `Fonts.register`.
Unknown or unreadable files are skipped. On a live SDL_ttf renderer, CangHui
checks glyph coverage for the complete text run and advances to the next face
when the current face is incomplete.

For `.bold()`, CangHui first selects a real `Bold` named instance carried by a
variable font (the bundled HarmonyOS Sans SC includes one), then tries a
separate bold companion file, and only then synthesizes bold on the selected
base face. The family/fallback order therefore stays unchanged when weight
changes.

```cangjie
Fonts.register("brand", "assets/fonts/Brand-Regular.ttf")
let theme = Theme.light().withFontFamily(Some("brand"))
let app = DesktopApp(WindowSpec("Example", 720, 480), theme: theme)
```

Use `Fonts.useApplicationFamily("brand")` when the application wants one default
without coupling it to a particular Theme value. A component-level family still
wins over both defaults.

## Packaging

The integrated `cuic init` command copies the default TTF and license into the
new application's `assets/fonts` directory. `cuic build`, `test`, `run`, and
`prnt` also provide the framework-owned asset path through
`CANGHUI_HARMONYOS_SANS` for the supervised process.

Other build systems should package these files together:

```text
assets/fonts/HarmonyOS_Sans_SC.ttf
assets/fonts/HARMONYOS_SANS_LICENSE.txt
assets/fonts/HARMONYOS_SANS_SOURCE.txt
```

An application host with a different resource layout can call
`Fonts.registerBundledFallback(path)` before creating a window, or set
`CANGHUI_HARMONYOS_SANS` before process startup.

## Diagnostics

`Renderer.fontResolution()` reports the first logical tier. On a live renderer,
`Renderer.fontResolutionForText(text)` also applies glyph coverage and reports
the tier actually selected for that string. The recording renderer includes
`resolvedFamily` and `fontSource` in text Draw IR.

```bash
./tools/cuic/bin/cuic font status macos
./tools/cuic/bin/cuic doctor macos --verbose
```

The stable machine-readable contract is
[`canghui.font-resolution.v0`](../../contracts/canghui-font-resolution-v0.json).
