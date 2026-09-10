package chui.controls

import std.collection.HashSet
import sdl.{Color, Key, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}
import chui.core.{Button, ComponentControlAppearance, ComponentControlKind, ComponentControlState,
    ComponentControlStyle, ComponentProbe, ComponentShape, ComponentSpacing, ComponentTheme, ComponentTypography,
    ControlContentEnvironment, Label, LengthInsets, LengthUnits, State, StateStore, Theme, UiContext, VStack,
    Widget, buildRoot, emit}

private class ControlSlotProbe <: Widget {
    private let desired: Size
    var laidOut = Rect.zero()

    init(width: Float32, height: Float32) {
        desired = Size(width, height)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, desired.w), min(available.h, desired.h))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        laidOut = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class ControlSlotEnvironmentProbe <: Widget {
    var captured: ?ControlContentEnvironment = None

    init() { emit(this) }

    public func measure(_: UiContext, _: Size): Size { Size(40.0, 18.0) }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(ctx: UiContext): Unit { captured = ctx.controlContentEnvironment() }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

private func slotTestContext(theme!: Theme = Theme.light()): UiContext {
    let ctx = UiContext(Renderer.headless(), theme)
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

private func emptyIndexSet(): HashSet<Int64> {
    HashSet<Int64>()
}

@Test
func decorativeControlSlotsSuppressNestedFocusableDescendants(): Unit {
    let store = StateStore()
    let chipOn = State<Bool>(false)
    let checked = State<Bool>(false)
    let selected = State<Int64>(0)
    let _ = buildRoot({=>
        Chip(chipOn, key: Some("slot-chip")) { Button("nested-chip", {=> ()}) }
        Checkbox(checked) { Button("nested-checkbox", {=> ()}) }.key("slot-checkbox")
        Dropdown(["A", "B"], selected, key: Some("slot-dropdown"), selectedContent: {
            _, _ => Button("nested-dropdown", {=> ()})
        })
        Accordion([
            AccordionSection(header: {=> Button("nested-accordion", {=> ()})}, body: {=> Label("body")})
        ], expanded: State<HashSet<Int64>>(emptyIndexSet()), key: Some("slot-accordion"))
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 4)
    @Expect(ring[0], "slot-chip")
    @Expect(ring[1], "slot-checkbox")
    @Expect(ring[2], "slot-dropdown")
}

@Test
func slotChipMeasuresContentAndKeepsMoveOutCancellation(): Unit {
    let ctx = slotTestContext()
    let on = State<Bool>(false)
    let probe = ControlSlotProbe(64.0, 18.0)
    let chip = Chip(on, key: Some("chip-slot")) { emit(probe) }
    let measured = chip.measure(ctx, Size(300.0, 100.0))
    @Expect(measured.w, Float32(88.0))
    @Expect(measured.h, Float32(28.0))
    chip.layout(ctx, Rect(10.0, 20.0, measured.w, measured.h))
    @Expect(probe.laidOut.x, Float32(22.0))

    @Expect(chip.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 30.0)))
    let _ = chip.handle(ctx, UiEvent.MouseMove(160.0, 30.0))
    @Expect(!chip.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 30.0, 30.0)))
    @Expect(!on.value)
}

@Test
func slotCheckboxUsesOuterKeyboardActivation(): Unit {
    let ctx = slotTestContext()
    let checked = State<Bool>(false)
    let checkbox = Checkbox(checked) {
        Label("Allow offline navigation")
    }.key("checkbox-slot")
    checkbox.layout(ctx, Rect(0.0, 0.0, 240.0, 38.0))
    ctx.focus("checkbox-slot")
    @Expect(checkbox.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(checked.value)
}

@Test
func slotDropdownAndAccordionMeasureDecorativeFaces(): Unit {
    let ctx = slotTestContext()
    let selected = State<Int64>(0)
    let dropdownProbe = ControlSlotProbe(220.0, 30.0)
    let dropdown = Dropdown(["A", "B"], selected, key: Some("dropdown-slot"), selectedContent: {
        _, _ => emit(dropdownProbe)
    })
    let dropdownSize = dropdown.measure(ctx, Size(400.0, 100.0))
    @Expect(dropdownSize.w, Float32(260.0))
    @Expect(dropdownSize.h, Float32(38.0))
    dropdown.layout(ctx, Rect(0.0, 0.0, dropdownSize.w, dropdownSize.h))
    @Expect(dropdownProbe.laidOut.x, Float32(10.0))

    let headerProbe = ControlSlotProbe(120.0, 52.0)
    let accordion = Accordion([
        AccordionSection(header: {=> emit(headerProbe)}, body: {=> Label("body")})
    ], expanded: State<HashSet<Int64>>(emptyIndexSet()), key: Some("accordion-slot"))
    @Expect(accordion.measure(ctx, Size(300.0, 500.0)).h, Float32(52.0))
    accordion.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))
    @Expect(headerProbe.laidOut.x, Float32(32.0))
}

@Test
func componentThemeTokensAndStyleReachAllCompositeControls(): Unit {
    let sawChip = State<Bool>(false)
    let sawCheckbox = State<Bool>(false)
    let sawDropdown = State<Bool>(false)
    let sawAccordion = State<Bool>(false)
    let sawSelected = State<Bool>(false)
    let style = ComponentControlStyle(resolve: {
        theme, kind, state =>
        match (kind) {
            case ComponentControlKind.Chip => sawChip.value = true
            case ComponentControlKind.Checkbox => sawCheckbox.value = true
            case ComponentControlKind.Dropdown => sawDropdown.value = true
            case ComponentControlKind.AccordionHeader => sawAccordion.value = true
        }
        if (state.selected || state.expanded || state.selection > 0.0) {
            sawSelected.value = true
        }
        ComponentControlAppearance(
            surface: SurfaceStyle(Color.rgb(20, 30, 40), radius: 14.0),
            foreground: theme.text,
            indicator: theme.accent,
            ink: theme.inkColor(),
            focusRadius: 14.0
        )
    })
    let theme = Theme.light().withComponents(ComponentTheme(
        controlStyle: Some(style),
        typography: ComponentTypography(control: 17.fp),
        spacing: ComponentSpacing(
            compactPadding: LengthInsets(16.vp, 4.vp),
            controlPadding: LengthInsets(14.vp, 5.vp),
            selectionPadding: LengthInsets(top: 6.vp, right: 12.vp, bottom: 6.vp, left: 2.vp),
            inlineGap: 10.vp,
            compactMinHeight: 34.0,
            controlMinHeight: 46.0,
            indicatorSize: 20.0
        ),
        shape: ComponentShape(smallRadius: Some(5.0), controlRadius: Some(14.0), pillRadius: Some(17.0))
    ))
    let ctx = slotTestContext(theme: theme)
    let chip = Chip("On", State<Bool>(true), key: Some("styled-chip"))
    chip.layout(ctx, Rect(0.0, 0.0, 90.0, 34.0))
    chip.draw(ctx)
    let checkbox = Checkbox("Checked", State<Bool>(true)).key("styled-checkbox")
    checkbox.layout(ctx, Rect(0.0, 40.0, 180.0, 46.0))
    checkbox.draw(ctx)
    let dropdown = Dropdown(["A"], State<Int64>(0), key: Some("styled-dropdown"))
    dropdown.layout(ctx, Rect(0.0, 90.0, 190.0, 46.0))
    dropdown.draw(ctx)
    let expanded = HashSet<Int64>()
    expanded.add(0)
    let accordion = Accordion([
        AccordionSection("Open") {=> Label("body")}
    ], expanded: State<HashSet<Int64>>(expanded),
        key: Some("styled-accordion"))
    accordion.layout(ctx, Rect(0.0, 140.0, 240.0, 120.0))
    accordion.draw(ctx)

    @Expect(sawChip.value)
    @Expect(sawCheckbox.value)
    @Expect(sawDropdown.value)
    @Expect(sawAccordion.value)
    @Expect(sawSelected.value)
    @Expect(chip.measure(ctx, Size(300.0, 100.0)).h, Float32(34.0))
    @Expect(checkbox.measure(ctx, Size(300.0, 100.0)).h, Float32(46.0))
}

@Test
func compositeControlSlotReceivesResolvedStateEnvironment(): Unit {
    let probe = ControlSlotEnvironmentProbe()
    let foreground = Color.rgb(41, 73, 109)
    let style = ComponentControlStyle(resolve: {theme, _, _ =>
        ComponentControlAppearance(
            surface: SurfaceStyle(theme.field, radius: 12.0),
            foreground: foreground,
            indicator: theme.accent,
            ink: theme.inkColor(),
            focusRadius: 12.0
        )
    })
    let ctx = slotTestContext()
    let chip = Chip(State<Bool>(true), key: Some("environment-chip")) { emit(probe) }
        .controlStyle(style)
        .accessibilityLabel("Active filter")
    chip.layout(ctx, Rect(0.0, 0.0, 120.0, 34.0))
    ctx.focus("environment-chip")
    chip.draw(ctx)
    let environment = probe.captured.getOrThrow()
    @Expect(environment.foreground.r, foreground.r)
    @Expect(environment.role, "checkbox")
    @Expect(environment.interactionOwner, "environment-chip")
    @Expect(environment.selected)
    @Expect(environment.focused)
}

@Test
func compoundControlsExposeOneOuterHeadlessSemanticAction(): Unit {
    let report = ComponentProbe("test.compound-semantics", width: 360.0, height: 240.0).run("") {
        VStack {
            Chip("Nearby", State<Bool>(true), key: Some("semantic-chip"))
            Checkbox(State<Bool>(false)) { Label("Offline") }
                .accessibilityLabel("Offline mode")
                .key("semantic-checkbox")
            Dropdown(["Local", "Remote"], State<Int64>(1), key: Some("semantic-dropdown"))
                .accessibilityLabel("Engine")
            Accordion([
                AccordionSection(accessibilityLabel: "Details", header: {=> Label("Details")},
                    body: {=> Label("Body")})
            ], initiallyExpanded: [0], key: Some("semantic-accordion"))
        }
    }
    @Expect(report.contains("\"id\":\"control-semantic:semantic-chip\""))
    @Expect(report.contains("\"actionOwner\":\"semantic-chip\""))
    @Expect(report.contains("\"selected\":\"true\""))
    @Expect(report.contains("\"label\":\"Offline mode\""))
    @Expect(report.contains("\"label\":\"Engine\""))
    @Expect(report.contains("\"value\":\"Remote\""))
    @Expect(report.contains("\"action\":\"Accordion.toggle(0)\""))
    @Expect(report.contains("\"semanticDescendants\":\"decorative\""))

    let ascii = ComponentProbe("test.compound-semantics-ascii", width: 220.0, height: 70.0)
        .run("@cui-ascii 55 14") {
            Chip("Nearby", State<Bool>(true), key: Some("ascii-chip"))
        }
    @Expect(ascii.contains("Nearby"))
    @Expect(ascii.contains("Chip.toggle()"))
}
