package chui.core

import sdl.{Color, IconName, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}

private class ButtonSlotProbe <: Widget {
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

@Test
func slotButtonMeasuresContentAndOwnsActivation(): Unit {
    let ctx = testContext()
    let clicks = State<Int64>(0)
    let probe = ButtonSlotProbe(80.0, 20.0)
    let button = Button(onClick: {=> clicks.value += 1}) {
        emit(probe)
    }.contentPadding(LengthInsets(10.vp, 6.vp)).key("slot")

    let measured = button.measure(ctx, Size(300.0, 100.0))
    @Expect(measured.w, Float32(100.0))
    @Expect(measured.h, Float32(38.0))
    button.layout(ctx, Rect(20.0, 30.0, measured.w, measured.h))
    @Expect(probe.laidOut.x, Float32(30.0))
    @Expect(probe.laidOut.y, Float32(36.0))
    @Expect(probe.laidOut.w, Float32(80.0))
    @Expect(probe.laidOut.h, Float32(26.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
    @Expect(button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 40.0, 40.0)))
    @Expect(clicks.value, Int64(1))
}

@Test
func slotButtonKeepsPermanentMoveOutCancellation(): Unit {
    let ctx = testContext()
    let clicks = State<Int64>(0)
    let button = Button(onClick: {=> clicks.value += 1}) {
        Label("Deploy")
    }.key("slot-cancel")
    button.layout(ctx, Rect(0.0, 0.0, 120.0, 42.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 20.0)))
    let _ = button.handle(ctx, UiEvent.MouseMove(180.0, 20.0))
    @Expect(!button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 30.0, 20.0)))
    @Expect(clicks.value, Int64(0))
}

@Test
func slotButtonSuppressesNestedFocusableDescendants(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        => Button(onClick: {=> ()}) {
            Button("Nested", {=> ()})
        }.key("outer")
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 1)
    @Expect(ring[0], "outer")
}

@Test
func componentThemeResolvesButtonStateAndPanelSurface(): Unit {
    let sawFocus = State<Bool>(false)
    let resolveCount = State<Int64>(0)
    let style = ButtonStyle(resolve: {
        theme, _, state =>
        sawFocus.value = state.focused
        resolveCount.value += 1
        ButtonAppearance(
            surface: SurfaceStyle(Color.rgb(12, 34, 56), radius: 18.0),
            foreground: theme.accentText,
            ink: Color.rgb(200, 210, 220),
            focusRadius: 18.0
        )
    })
    let panel = SurfaceStyle(Color.rgb(7, 8, 9), radius: 2.0)
    let theme = Theme.light().withComponents(ComponentTheme(
        buttonStyle: Some(style),
        buttonLayout: ButtonLayoutStyle(minWidth: 96.0, minHeight: 44.0),
        panelSurface: Some(panel)
    ))
    let ctx = UiContext(Renderer.headless(), theme)
    let button = Button("Styled", {=> ()}).key("styled")
    let measured = button.measure(ctx, Size(300.0, 100.0))
    @Expect(measured.w >= Float32(96.0))
    @Expect(measured.h, Float32(44.0))
    button.layout(ctx, Rect(0.0, 0.0, measured.w, measured.h))
    ctx.focus("styled")
    button.draw(ctx)
    @Expect(sawFocus.value)
    let iconButton = IconButton(IconName.Save) {=> ()}.key("styled-icon")
    iconButton.layout(ctx, Rect(0.0, 0.0, 40.0, 40.0))
    iconButton.draw(ctx)
    @Expect(resolveCount.value >= Int64(2))
    @Expect(theme.panelSurface().fill.r, panel.fill.r)
    @Expect(theme.panelSurface().radius, panel.radius)
}

@Test
func quietButtonStyleHasTransparentIdleAndVisibleInteraction(): Unit {
    let theme = Theme.light()
    let style = ButtonStyle.quiet()
    let idle = style.resolve(theme, ButtonRole.Normal, ButtonVisualState())
    let hover = style.resolve(theme, ButtonRole.Normal, ButtonVisualState(hover: 1.0))
    let press = style.resolve(theme, ButtonRole.Danger, ButtonVisualState(press: 1.0))

    @Expect(idle.surface.fill.a, UInt8(0))
    @Expect(idle.surface.borderWidth, Float32(0.0))
    @Expect(hover.surface.fill.a > UInt8(0))
    @Expect(press.surface.fill.a > UInt8(0))
    @Expect(press.foreground.r, theme.danger.r)
}
