package chui.core

import sdl.{FontStyle, Key, Rect, Renderer, Size, UiEvent}

private class TypographyPhaseCapture <: Widget {
    var phases = ""

    init() { emit(this) }

    public func measure(ctx: UiContext, _: Size): Size {
        @Expect(ctx.typographyEnvironment().resolvedFontStyle().bold)
        phases = phases + "m"
        Size(20.0, 20.0)
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        @Expect(ctx.typographyEnvironment().resolvedFontStyle().bold)
        phases = phases + "l"
    }

    public func draw(ctx: UiContext): Unit {
        @Expect(ctx.typographyEnvironment().resolvedFontStyle().bold)
        phases = phases + "d"
    }

    public func handle(ctx: UiContext, _: UiEvent): Bool {
        @Expect(ctx.typographyEnvironment().resolvedFontStyle().bold)
        phases = phases + "h"
        false
    }
}

@Test
func typographyEnvironmentMergesFieldwiseAndRestores(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    @Expect(ctx.typographyEnvironment().fontSize.isNone())
    ctx.withTypographyEnvironment(TypographyEnvironment(
        fontFamily: "Outer",
        fontSize: Length(22.0, LengthUnit.Fp),
        bold: true,
        italic: true
    )) {=>
        ctx.withTypographyEnvironment(TypographyEnvironment(fontSize: Length(14.0, LengthUnit.Fp),
            italic: false)) {=>
            let inner = ctx.typographyEnvironment()
            @Expect(inner.fontFamily.getOrThrow(), "Outer")
            @Expect(inner.fontSize.getOrThrow().value, Float32(14.0))
            @Expect(inner.resolvedFontStyle().bold)
            @Expect(!inner.resolvedFontStyle().italic)
        }
        @Expect(ctx.typographyEnvironment().fontSize.getOrThrow().value, Float32(22.0))
    }
    @Expect(ctx.typographyEnvironment().fontFamily.isNone())
}

@Test
func typographyModifierScopesEveryWidgetPhase(): Unit {
    let capture = TypographyPhaseCapture()
    let widget = capture.typography(TypographyEnvironment(bold: true))
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let _ = widget.measure(ctx, Size(100.0, 100.0))
    widget.layout(ctx, Rect(0.0, 0.0, 20.0, 20.0))
    widget.draw(ctx)
    let _ = widget.handle(ctx, UiEvent.KeyDown(Key.Enter, false))
    @Expect(capture.phases, "mldh")
    @Expect(!ctx.typographyEnvironment().resolvedFontStyle().bold)
}

@Test
func labelInheritsContainerTypographyWhileExplicitLeafWins(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let widget = VStack {
        Label("Inherited")
        Label("Explicit").fontStyle(FontStyle.regular).fontSize(12.0)
    }.fontSize(24.0).bold()
    let size = widget.measure(ctx, Size(400.0, 200.0))
    widget.layout(ctx, Rect(0.0, 0.0, 400.0, size.h))
    widget.draw(ctx)
    let commands = renderer.drawIr()
    @Expect(commands.size, 2)
    @Expect(commands[0].toJson().contains("\"pointSize\":24.000000"))
    @Expect(commands[0].toJson().contains("\"bold\":true"))
    @Expect(commands[1].toJson().contains("\"pointSize\":12.000000"))
    @Expect(commands[1].toJson().contains("\"bold\":false"))
}

@Test
func labelMetricsCacheKeysInheritedSizeAndStyle(): Unit {
    let label = Label("Typography cache")
    let small = label.typography(TypographyEnvironment(fontSize: Length(12.0, LengthUnit.Fp), bold: false))
    let large = label.typography(TypographyEnvironment(fontSize: Length(28.0, LengthUnit.Fp), bold: true))
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let smallSize = small.measure(ctx, Size(1000.0, 200.0))
    let largeSize = large.measure(ctx, Size(1000.0, 200.0))
    @Expect(largeSize.w > smallSize.w)
    @Expect(largeSize.h > smallSize.h)
}

@Test
func overlayCapturesTypographyForDeferredRenderAndDispatch(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let rendered = State<Bool>(false)
    let dispatched = State<Bool>(false)
    ctx.withTypographyEnvironment(TypographyEnvironment(bold: true, fontSize: Length(21.0, LengthUnit.Fp))) {=>
        ctx.setOverlay(Overlay(
            handleEvent: {c, _ =>
                dispatched.value = c.typographyEnvironment().resolvedFontStyle().bold
                true
            },
            render: {c =>
                rendered.value = c.typographyEnvironment().fontSize.getOrThrow().value == Float32(21.0)
            },
            owner: "typography-overlay"
        ))
    }
    ctx.drawActiveOverlay()
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(rendered.value)
    @Expect(dispatched.value)
    @Expect(ctx.typographyEnvironment().fontSize.isNone())
}
