package chui.core

import sdl.{Color, Rect, Renderer, Size, SurfaceStyle, UiEvent}

private class ContentEnvironmentCapture <: Widget {
    var captured: ?ControlContentEnvironment = None

    init() { emit(this) }

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(ctx: UiContext): Unit { captured = ctx.controlContentEnvironment() }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func controlContentEnvironmentNestsAndRestores(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let outer = ControlContentEnvironment(Color.rgb(10, 20, 30), role: "button", interactionOwner: "outer")
    let inner = ControlContentEnvironment(Color.rgb(90, 80, 70), role: "checkbox", interactionOwner: "inner",
        selected: true)
    @Expect(ctx.controlContentEnvironment().isNone())
    @Expect(outer.enabled)
    @Expect(!outer.readOnly)
    ctx.withControlContentEnvironment(outer) {=>
        @Expect(ctx.contentForeground().r, UInt8(10))
        ctx.withControlContentEnvironment(inner) {=>
            @Expect(ctx.contentForeground().r, UInt8(90))
            @Expect(ctx.controlContentEnvironment().getOrThrow().selected)
        }
        @Expect(ctx.controlContentEnvironment().getOrThrow().interactionOwner, "outer")
    }
    @Expect(ctx.controlContentEnvironment().isNone())
    @Expect(ctx.contentForeground().r, ctx.theme.text.r)
}

@Test
func interactionEnabledScopesNestByConjunctionAndRestore(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    @Expect(ctx.interactionsEnabled())
    ctx.withInteractionsEnabled(false) {=>
        @Expect(!ctx.interactionsEnabled())
        ctx.withInteractionsEnabled(true) {=> @Expect(!ctx.interactionsEnabled()) }
        @Expect(!ctx.interactionsEnabled())
    }
    @Expect(ctx.interactionsEnabled())
}

@Test
func disabledScopeFlowsIntoExistingControlContentEnvironment(): Unit {
    let capture = ContentEnvironmentCapture()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let button = Button(onClick: {=> ()}) { emit(capture) }.enabled(false)
    button.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    button.draw(ctx)
    @Expect(!capture.captured.getOrThrow().enabled)
}

@Test
func slotButtonPublishesResolvedForegroundAndStateToDecorativeContent(): Unit {
    let capture = ContentEnvironmentCapture()
    let foreground = Color.rgb(17, 44, 91)
    let style = ButtonStyle(resolve: {_, _, _ =>
        ButtonAppearance(
            surface: SurfaceStyle(Color.rgb(230, 234, 240), radius: 9.0),
            foreground: foreground,
            ink: foreground,
            focusRadius: 9.0
        )
    })
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let button = Button(onClick: {=> ()}) { emit(capture) }
        .buttonStyle(style)
        .accessibilityLabel("Publish")
        .key("publish")
    button.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    ctx.focus("publish")
    button.draw(ctx)
    let environment = capture.captured.getOrThrow()
    @Expect(environment.foreground.r, foreground.r)
    @Expect(environment.foreground.g, foreground.g)
    @Expect(environment.foreground.b, foreground.b)
    @Expect(environment.role, "button")
    @Expect(environment.interactionOwner, "publish")
    @Expect(environment.focused)
}

@Test
func labelUsesInheritedForegroundUnlessExplicitlyOverridden(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let inherited = Color.rgb(12, 34, 56)
    let explicit = Color.rgb(91, 82, 73)
    let implicitLabel = Label("inherited")
    let explicitLabel = Label("explicit").foregroundColor(explicit)
    implicitLabel.layout(ctx, Rect(0.0, 0.0, 120.0, 30.0))
    explicitLabel.layout(ctx, Rect(0.0, 30.0, 120.0, 30.0))
    ctx.withControlContentEnvironment(ControlContentEnvironment(inherited, interactionOwner: "owner")) {=>
        implicitLabel.draw(ctx)
        explicitLabel.draw(ctx)
    }
    let commands = renderer.drawIr()
    @Expect(commands.size, 2)
    @Expect(commands[0].toJson().contains("\"r\":12,\"g\":34,\"b\":56"))
    @Expect(commands[1].toJson().contains("\"r\":91,\"g\":82,\"b\":73"))
}
