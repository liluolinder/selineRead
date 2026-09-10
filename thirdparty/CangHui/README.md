<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-CangHui-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie" />
  <img src="https://img.shields.io/badge/version-0.17.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.17.0" />
  <img src="https://img.shields.io/badge/package-chui-2f855a?style=for-the-badge&labelColor=1f2430" alt="Package chui" />
  <img src="https://img.shields.io/badge/output-static-805ad5?style=for-the-badge&labelColor=1f2430" alt="Static Output" />
  <img src="https://img.shields.io/badge/focus-multiplatform%20GUI-1f9d55?style=for-the-badge&labelColor=1f2430" alt="Multiplatform GUI" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">CangHui / 仓绘</span><br/>
<span style="font-weight:100;font-size:24px">CangHui Multiplatform</span><br/>
<span style="font-weight:100;font-size:18px">A multiplatform declarative GUI framework for Cangjie</span>
<p align="center">
  <strong>A GUI runtime for turning Cangjie intent into native pixels</strong><br/>
  <sub>Declarative semantics · deterministic probes · self-rendered surfaces · native host contracts</sub>
</p>
</div>

**English** | [中文](README.zh-CN.md)

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## What is CangHui

CangHui is a self-rendered, declarative GUI framework written in the
[Cangjie programming language](https://cangjie-lang.cn/). It evolved from
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI) and
retains its upstream attribution and MIT notice. CangHui and its original
contributions are distributed under Apache License 2.0; the upstream MIT terms
remain preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The
declarative core (`chui`) and the safe SDL3 wrapper (`sdl`) live in this
repository, together with the integrated `cuic` toolchain, component-package
contracts, responsive layout primitives, and native host contracts.

The framework is designed to be platform-neutral at the source level: common
widgets and product components depend only on typed host capabilities and
viewport facts, while each platform adapter owns lifecycle, native surfaces,
IME, accessibility, packaging, and signing. Platform-specific hosts can be
implemented independently without changing common widgets or application
state.

The framework name is **CangHui**, its full positioning is **CangHui
Multiplatform**, and its Cangjie package is **`chui`**. A few older identifiers
remain deliberately stable at compatibility boundaries: `cui.probe.v0` and
`@cui-ascii` are wire identifiers; `CUI_*` declarations are source-compatible
names; `cuic` and `--cui-path` are tool-compatible names; existing
`dev.cui.examples.*` application ids remain persisted example identities.
They are not package names or alternate CangHui branding.

> CangHui is not a screenshot layer and not a bag of widgets. It is a small
> language-facing runtime: application intent enters as Cangjie composition,
> passes through layout, state, motion, symbols and host capabilities, and
> leaves as a frame that can be rendered, inspected or replayed.

## The CangHui Stack

```text
Application code
        |
        v
cuic project lifecycle  ----  kMode / probe / Draw IR / prnt
        |
        v
CangHui declarative core  ----  state, identity, layout, controls, overlays
        |                    theme, motion, typography, Symbol providers
        v
Host capability contracts  --  window, input, IME, files, clipboard, time
        |
        v
Native surface adapters  ----  SDL3 desktop | UIKit/Metal slice | mobile bootstrap
        |
        v
Platform runtime and GPU backend
```

The stack is deliberately layered. A component should be able to describe its
behavior without importing a platform host; a host should be able to expose a
surface without knowing the application's business state; and `cuic` should be
able to exercise the same public functions without opening a window.

## Platform Status

Platform claims below are intentionally conservative. Desktop layout previews
do not prove a mobile runtime, and a native-surface probe is not product-level
scene rendering or application acceptance.

| Platform | Status | Notes |
| --- | --- | --- |
| macOS desktop | Available | Build, the full framework/SDL/CLI test suites, the interactive gallery, and deterministic snapshots pass on this host. |
| iOS | Native-surface adapter proven | Simulator and physical-device proof covers static-package bootstrap, a UIKit `CAMetalLayer`, lifecycle, safe area, touch, `CADisplayLink`, detach/reattach generation replay and a Metal clear pass. Full CangHui scene rendering, IME, accessibility and product application acceptance remain open. |
| HarmonyOS / HarmonyPC | XComponent host ingress available | The repository publishes a versioned C ABI and `HarmonyXComponentScene3DHost` lifecycle bridge. An ArkTS/HAP application host, provider pixels, signing and standalone device acceptance remain consumer-owned gates. |
| Windows / Linux | Code paths present | `cuic` contains bootstrap, doctor and build code paths; this repository does not claim host-verified runtime proof for either platform. |
| Android | Native-surface bootstrap only | A minimal Activity owns the generation-safe `SurfaceView` to JNI to `ANativeWindow` lifecycle, and the slice builds for `arm64-v8a` and `x86_64`. The Cangjie Android SDK, renderer bridge, input/IME, APK packaging and device runtime proof remain open. |

## Capability Map

| Layer | In the public tree | Boundary |
| --- | --- | --- |
| CangHui core | Declarative composition, identity, state, layout, controls, overlays and text editing | Platform-neutral source API |
| Rendering | SDL3-backed desktop renderer, phase-aware retained bookkeeping, bounded damage planning, FrameGraph scheduling, provider-neutral graphics negotiation and bounded render packets | SDL currently preserves/stages damage internally but still calls full-window `SDL_RenderPresent`; Metal, Vulkan, D3D11/12, OpenGL ES, WebGPU and software are adapter identities, not claims that every backend driver is shipped or verified |
| Scene3D | Sealed semantic snapshots, a focusable embedded `Scene3DView`, optional shared-frame composition, macOS bgfx4cj packaging, and a versioned HarmonyOS XComponent host ingress | The selected SDL path composes bounded CPU RGBA8 frames in normal tree order; native private-texture/fence composition, field HDR and other-host provider pixels remain separate gates |
| Interaction | Pointer capture, focus, keyboard/gamepad routing, plus a bounded in-process semantic snapshot/diff and typed-action plane | Voice and agent actions are opt-in; this is not an IPC or remote-control channel, and native accessibility/IME adapters remain host responsibilities where not proven |
| Desktop windows | `DesktopApp` for one window and `DesktopApplication` for one process-level SDL pump with independently owned windows | Focus, overlays, pointer capture and Scene3D state are window-local; process-global gamepad events target the active window, and the multi-window path does not yet have full advanced FrameGraph/effect/transition parity with `DesktopApp` |
| Inspection | debug-build-only `kMode`, `cuic probe`, component/function/event reports, Draw IR and deterministic `prnt` | Release applications and release cuic refuse privileged inspection; reports prove semantics and geometry, not a full device UI acceptance |
| Packaging | `cuic init`, manifest validation, deterministic unsigned inputs, release-exclusion and network audits, plus opt-in macOS Developer ID/notarization gates | Runtime closure and publisher credentials remain owner inputs; App Store/MSIX publication and non-macOS host launch remain separate gates |
| Mobile bridge | iOS native-surface lifecycle slice, Android surface bootstrap, staged package receipts, signed-package evidence, installation-attempt receipts and debug-only kMode callback replay | Platform signers/installers are never run implicitly; installation receipts remain platform-owner attestations, while launch, rendering, device replay and consumer acceptance stay separate gates |

## Quick Start

The easiest way to create, build, and run a CangHui application is through the
integrated `cuic` CLI. Installing `cuic` only sparse-fetches and builds
`tools/cuic`; it does not keep a full framework checkout next to your project.

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Create and run a blank project:

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic dependency update
cuic doctor macos
cuic build macos
cuic run macos
```

Generated applications depend on the public CangHui Git repository pinned by
commit. `cuic dependency update` is the explicit lock/cache mutation step;
build-like commands require a matching `cjpm.lock` and never update it
implicitly. The framework resolves through the CJPM cache instead of being
copied into every project.

A minimal window in `src/main.cj`:

```cangjie
import chui.*

main() {
    let message = State<String>("Hello, CangHui")
    let app = DesktopApp(WindowSpec("CangHui Example", 640, 420))

    app.run {
        VStack {
            Panel {
                Label(message.value)
            }.flexible(false)
            Button("Update", {=> message.value = "State updated"})
                .role(ButtonRole.Primary)
                .width(160.vp)
        }.spacing(12.vp).padding(20.vp)
    }
}
```

Buttons also accept arbitrary decorative content while retaining the same
focus, keyboard, release-inside and move-out cancellation contract:

```cangjie
Button(onClick: {=> openWorkspace()}, role: ButtonRole.Primary) {
    HStack(spacing: 8.vp) {
        Icon(IconName.OpenFolder)
        VStack(spacing: 2.vp) {
            Label("Open workspace").bold()
            Label("Local or remote").muted().fontSize(12.fp)
        }.hug()
    }.hug()
}.accessibilityLabel("Open workspace")
 .contentPadding(LengthInsets(16.vp, 10.vp))
```

Slot content is decorative: the outer button remains the only focus and click
owner. `ButtonStyle` and `ComponentTheme` customize state-aware button chrome
and default Panel surfaces across an application. Slot Label, Icon and Symbol
content inherits the resolved outer foreground through
`ControlContentEnvironment`; explicit child colors still win.

The same decorative-slot contract is available for `Chip`, `Checkbox`, the
closed face of `Dropdown`, and `AccordionSection` headers. Their shared
`ComponentControlStyle` receives selection/expansion, hover, press and focus
state, while `ComponentTypography`, `ComponentSpacing`, and `ComponentShape`
provide one product-wide control rhythm without replacing each widget. These
compound controls also publish one outer `ControlSemantics` action to the
headless probe/Draw IR surface, so function-level UI checks do not need a
screenshot or hand-authored probe node for each stock control.

Primitive controls follow the same headless contract. `IconButton`, `Switch`,
`RadioButton`, `Slider`, `Picker` and `Stepper` expose one semantic region with
their action owner, keyboard shortcut and current value/selection state;
`accessibilityLabel` supplies a stable name for icon-only or value-only faces.

See [consumer workflow](manual/reference/consumer-workflow.md) for cache, lock, and local
override rules.

The intended consumer shape is small: depend on `chui`, install `cuic`, and let
the tool create the project skeleton. A framework checkout is useful for
framework development, but it is not the normal application layout.

## Core Capabilities

- Self-rendered GUI engine on SDL3 with GPU geometry, supersampled anti-aliasing,
  rounded corners, strokes, icons, shadows, and gradient fills.
- Declarative UI built on Cangjie trailing lambdas, `extend`, and `prop`.
- Layout containers: `VStack`, ArkTS-shaped `Row`, `HStack`, `ZStack`, `Grid`, `Panel`, `FlowRow`,
  `ScrollView`, `SplitView`, `Accordion`, animated `Reveal`, and viewport-focused
  lazy containers `LazyColumn`, `LazyRow`, `LazyList`, and `LazyGrid`.
- Controls: buttons, text fields, switches, checkboxes, radio buttons, pickers,
  steppers, sliders, progress bars, rating, badges, chips, step indicators,
  pagination, breadcrumbs, lists, data tables, tree views, date/time pickers,
  reorderable lists, segmented controls, tabs, dropdowns, and combo boxes.
- Overlays: dropdowns, context menus, menu bars, pickers, tooltips,
  notifications, and modal dialogs with a stack that supports nesting.
- Order-sensitive chained modifiers for size, constraints, padding, surface,
  radius, border, shadow, gradient, flex, visibility, and enabled state, with
  `.px`, `.vp`, and `.fp` units.
- State management: read/write split `Observable`/`Bindable`, writable
  `State<T>`, cached `DerivedState` (`derive`/`map`), and two-way `Binding`
  (`project`).
- Thread-safe `UiOwnerQueue` and `DesktopApp.postToUi`: workers prepare
  immutable results, and the single UI owner commits them in ticket order before
  the next declarative build, with epoch/native-surface-generation gates,
  cancellation, close receipts, and bounded draining. `State` itself remains
  UI-owner-only.
- `DesktopApplication` opens, focuses, steps and closes multiple native windows
  under one SDL event pump. Window-scoped events retain their `WindowId`; focus,
  overlays, pointer capture and Scene3D state stay window-local, while
  process-global gamepad events are assigned to the active window.
- `SemanticRuntime` records one bounded, revisioned semantic tree per window and
  exposes deterministic snapshot/diff plus typed actions. Agent and voice action
  sources are denied unless the application opts in; no coordinate, key,
  process-attach, socket or command execution surface is included.
- `Scene3DView` can opt into `PreferSharedFrame`. The current desktop path
  samples a bounded CPU RGBA8 lease at the widget's normal paint position and
  releases it exactly once with the terminal composition outcome; native private GPU textures
  and acquire fences remain provider work, not an implied zero-copy claim.
- Phase-aware retained bookkeeping records exact state dependencies and bounded
  damage, while the FrameGraph reuses topology schedules. An exactly fingerprinted
  keyed `Label` may reuse its committed measure output and a shape-clipped `Surface`
  with a framework-resolved material may bound paint damage; custom material providers and
  generic widget callbacks remain conservative, and SDL
  still performs a full-window present even when internal damage is smaller.
- Stable widget identity via `Keyed`, `rememberState`, and `ForEach`; focus,
  hover, cursor, and click identity follow deterministic per-frame build order.
- Animation primitives: `Spring`, duration/easing `Animator`, repeating `Pulse`,
  render-loop-as-clock with dirty-frame continuation, and `AnimationSpec` scaled
  by theme `MotionLevel`.
- Device-paced desktop rendering uses renderer VSync without adding a second
  fixed delay. `FramePacing.Fixed(fps)` and `FramePacing.Unbounded` are explicit
  alternatives; kMode selects unbounded rendered frames unless the application
  chooses another policy.
- Scrollable views use browser-like retained wheel easing by default. A shared
  `ScrollOptions` policy configures immediate or smooth behavior, logical-pixel
  wheel step, duration, and easing across views, lazy lists, tables, trees,
  text areas, dropdowns, and combo boxes.
- Design tokens: `Spacing`, `Radii`, `Motion`, color `Theme`, component-scoped
  `ComponentTheme` / `ButtonStyle`, `FontSizes`, and `Shadow.elevation`.
- Pointer-origin light/dark theme reveal and semantic-color InkWell feedback
  clipped to real rounded geometry, with release-inside activation and permanent
  move-out cancellation.
- Text editing: UTF-8 cursor/selection, double-click word selection, triple-click
  line selection, clipboard best-effort, undo/redo grouping, and IME anchor
  reporting.
- Platform capability SPI: file dialogs, message boxes, clipboard, cursor,
  displays, filesystem, time, and system information.
- Provider-neutral `Symbol` with built-in icon compatibility and optional
  Material, Ant Design, and Arco provider packages; `cuic symbol generate`
  emits declared subsets with duplicate/collision rejection.
- Bundled HarmonyOS Sans with explicit component, theme, application, bundled,
  and system resolution tiers plus license/source notices.

## Integrated Toolchain (`cuic`)

`tools/cuic` is the framework-owned CLI:

- `cuic init` / `build` / `test` / `run` with per-platform preparation
- `cuic doctor` for grouped Cangjie, repository, SDL, macOS, Windows, Linux,
  iOS, HarmonyOS, Android, font, Symbol, kMode, and probe readiness
- debug-built `cuic kmode` for supervised headless invocation without opening a
  window; release cuic keeps only `kmode diff` and refuses execution
- debug-built `cuic probe` / `pview` for deterministic component/function/event/
  animation and Draw IR reports; release cuic keeps only `probe diff`
- `cuic symbol` for declared provider subsets and generation
- `cuic font` for font preparation and registration
- `cuic prnt` for deterministic settled-frame screenshots
- `cuic check` / `dev` / `snapshot-ui` lifecycle aliases declared in
  `canghui.toml` (bounded to existing cuic actions)

Doctor status model and JSON contract:
[`manual/reference/doctor.md`](manual/reference/doctor.md).

The release/debug control-plane boundary, reverse-engineering limits, compiler
trim/strip contract and macOS Developer ID/notarization evidence chain are in
[`manual/reference/security-and-release.md`](manual/reference/security-and-release.md).

## Components, Gallery, and Packages

Common component packages are normal CJPM source dependencies. They expose a
typed `ComponentPackageDescriptor`, receive a `ComponentContext` with
`HostProfile` and `ViewportSpec`, and may branch on `Compact`, `Medium`, and
`Expanded` layout classes without importing a platform host.

- Reference package: `packages/gallery-components`
- Desktop gallery: `examples/component-gallery`
- Responsive preview matrix: `src/testkit/preview_matrix.cj`
- Component-package schema: `contracts/canghui-component-package-v0.schema.json`
- Symbol providers: `packages/symbol-material`, `packages/symbol-ant`,
  `packages/symbol-arco`
- Optional style pack: `packages/style-liquid-glass` provides light/dark,
  regular/clear/vapor material recipes, SDR optical layers, deforming stock
  segmented lenses and accessibility fallbacks. The bounded `sdl-readback`
  renderer-effect adapter can sample the current frame for a first-pass optical
  backdrop on proven SDL hosts; other backends and native platform-material
  identity are not claimed.

## A Public Contract, Not a Platform Costume

CangHui uses a strict vocabulary for capability claims:

- **Implemented** means the source, tests and the named host proof agree.
- **Experimental** means the adapter or protocol is usable for bounded work,
  while broader runtime or consumer proof is still open.
- **Contract** means CangHui defines the interface and invariants, but a host
  project still owns the platform implementation.
- **Planned** means the direction is documented, not shipped.

This distinction is part of the product. It keeps a desktop snapshot from being
mistaken for an iPad runtime, and keeps a native-surface bootstrap from being
mistaken for a complete application host.

## Technical Lineage and Ecosystem

The following map is intentionally layered. It shows what CangHui uses, what it
exposes, and what it studies; it does not fold upstream project capabilities
into the CangHui implementation claim.

| Role | Project or surface | Relationship to CangHui |
| --- | --- | --- |
| Language | [Cangjie](https://cangjie-lang.cn/) | Primary implementation and application language |
| Declarative runtime | CangHui (`chui`) | Framework-owned composition, state, layout and component surface |
| Desktop substrate | [SDL3](https://www.libsdl.org/) / SDL3_ttf | Upstream runtime dependency wrapped by the public `sdl` package |
| Native surface | UIKit, Metal, Android `SurfaceView` and `ANativeWindow` | Adapter targets and bounded bootstrap surfaces; each platform claim requires its own reproducible receipt |
| Design language | HarmonyOS Sans, Theme, Motion and Symbol contracts | Bundled fallback plus provider-neutral public APIs |
| Tooling | `cuic`, kMode, probe, Draw IR, doctor and `prnt` | Framework-owned project, inspection and verification entry points |
| Component references | ArkUI container conventions and mature GUI systems | API and design references, not bundled platform implementations |
| Graphics references | SDL, GPU geometry and native-surface literature | Engineering inputs for the renderer boundary, not a claim of owning every backend |

The useful mental model is a **semantic bridge**: CangHui carries Cangjie
meaning across hosts, while each host remains accountable for its lifecycle,
surface, input, text system, accessibility and packaging truth.

### SDL in Production

SDL3 is the current generation of a runtime lineage that has shipped beneath
games, emulators, media software and Valve's catalog. The gallery below is a
visual reference to that wider SDL production ecosystem. These are **not
CangHui applications**, and the exact SDL generation and backend used by each
title may vary.

<table>
  <tr>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/265630/">
        <img src="https://www.libsdl.org/steam_images/265630.jpg" width="100%" alt="Fistful of Frags" /><br/>
        <sub>Fistful of Frags · SDL official showcase</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/355180/">
        <img src="https://www.libsdl.org/steam_images/355180.jpg" width="100%" alt="Codename CURE" /><br/>
        <sub>Codename CURE · SDL official showcase</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/570/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/570/header.jpg" width="100%" alt="Dota 2" /><br/>
        <sub>Dota 2 · Valve catalog</sub>
      </a>
    </td>
  </tr>
  <tr>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/730/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/730/header.jpg" width="100%" alt="Counter-Strike 2" /><br/>
        <sub>Counter-Strike 2 · Valve catalog</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/620/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/620/header.jpg" width="100%" alt="Portal 2" /><br/>
        <sub>Portal 2 · Valve catalog</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/550/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/550/header.jpg" width="100%" alt="Left 4 Dead 2" /><br/>
        <sub>Left 4 Dead 2 · Valve catalog</sub>
      </a>
    </td>
  </tr>
</table>

SDL's own site cites Valve's award-winning catalog and many Humble Bundle games
as production users. Product names and artwork belong to their respective
owners; the remote images above link to their source pages and are not bundled
with CangHui. Their presence illustrates the reach of the upstream substrate,
not compatibility, endorsement or a CangHui runtime claim.

## Where This Is Going

The next architectural frontier is not adding a longer widget catalogue. It is
making the same application inspectable at three resolutions:

1. **Semantic**: invoke a public function or event through kMode.
2. **Geometric**: inspect layout bounds, hit regions and Draw IR without a
   window.
3. **Visual**: render the settled frame and capture it when pixels are the
   question.

That gives automated tools, CI and developers a shared vocabulary for debugging UI without
forcing every question through a screenshot. Screenshots remain valuable for
visual acceptance; they simply stop carrying the entire testing burden.

## Documentation

- [Public manual and release notes](manual/index.md)
- [Examples](examples/)
- [Manual home](manual/index.md)
- [Getting started](manual/guide/index.md)
- [API reference](manual/api/index.md)
- [Architecture](manual/reference/architecture.md)
- [Consumer workflow](manual/reference/consumer-workflow.md)
- [Multiplatform doctor](manual/reference/doctor.md)
- [Symbols and providers](manual/reference/symbols.md)
- [Fonts](manual/reference/fonts.md)
- [Liquid Glass optional style pack](manual/reference/liquid-glass-style.md)
- [Renderer effects and backdrop adapters](manual/reference/renderer-effects.md)
- [Scene3D semantic projection](manual/reference/scene3d.md)
- [Runtime semantic interaction](manual/reference/semantic-runtime.md)
- [Desktop multi-window runtime](manual/reference/desktop-multi-window.md)
- [Probe and kMode](manual/reference/probe.md)
- [SDL3 Apple host notes](manual/reference/sdl3-apple-host.md)
- [Modern GUI insights](manual/reference/modern-GUI-insights-and-analysis.md)

## License

This project is released under the
[Apache License 2.0](LICENSE). See [NOTICE](NOTICE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for retained upstream and
third-party attribution. The SDL3 and SDL3_ttf run-time libraries use the Zlib
license; see the respective upstream projects. The upstream source attribution
remains [`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI).

> [!IMPORTANT]
> When distributing desktop software built with CangHui, ensure the SDL and SDL_ttf
> dynamic libraries are placed beside the Cangjie executable or on the target
> platform's dynamic-library search path.
