package chui.core

import sdl.{Color, MouseButton, Rect, Size, UiEvent}

private class SurfaceEnvironmentCapture <: Widget {
    var environment: ?ControlContentEnvironment = None

    init() { emit(this) }
    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(ctx: UiContext): Unit { environment = ctx.controlContentEnvironment() }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func decorativeSurfaceResolvesMaterialClipsAndPublishesForeground(): Unit {
    let capture = SurfaceEnvironmentCapture()
    let foreground = Color.rgb(12, 34, 56)
    let report = ComponentProbe("test.surface", width: 140.0, height: 60.0).run("") {
        Surface(
            shape: Shape.rounded(11.0),
            material: Materials.solid(Color.rgb(220, 230, 240), foreground: Some(foreground)),
            clip: ClipPolicy.Shape
        ) { emit(capture) }
    }
    @Expect(report.contains("\"kind\":\"clip.push\""))
    @Expect(report.contains("\"kind\":\"clip.pop\""))
    let environment = capture.environment.getOrThrow()
    @Expect(environment.foreground.r, foreground.r)
    @Expect(environment.enabled)
    @Expect(environment.interactionOwner.isEmpty())
}

@Test
func decorativeSurfaceForwardsChildFocusAndEventsWithoutOwningEither(): Unit {
    let clicks = State<Int64>(0)
    let surface = Surface { Button("Child", {=> clicks.value += 1}).key("child") }
    let ctx = testContext()
    surface.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    @Expect(surface.focusableId().getOrThrow(), "child")
    @Expect(surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    @Expect(clicks.value, Int64(1))
}

@Test
func decorativeSurfacePainterOverridesOnlyPaintAndKeepsForeground(): Unit {
    let capture = SurfaceEnvironmentCapture()
    let painted = State<Bool>(false)
    let foreground = Color.rgb(32, 48, 64)
    let report = ComponentProbe("test.surface-painter", width: 140.0, height: 60.0).run("") {
        Surface(
            shape: Shape.rounded(12.0),
            material: Materials.solid(Color.rgb(220, 230, 240), foreground: Some(foreground)),
            painter: Some(SurfacePainter(paint: {ctx, rect, shape, material =>
                painted.value = true
                ctx.renderer.fillRoundedRect(rect, shape.cornerRadius(), material.style.fill)
            }))
        ) { emit(capture) }
    }
    @Expect(painted.value)
    @Expect(report.contains("paint.fill-rounded-rect"))
    @Expect(capture.environment.getOrThrow().foreground.r, foreground.r)
}
