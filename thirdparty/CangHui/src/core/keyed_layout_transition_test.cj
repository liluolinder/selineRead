package chui.core

import std.collection.ArrayList
import sdl.{Color, FrameInfo, MouseButton, Rect, Renderer, Size, UiEvent}

private class LayoutTransitionProbe <: Widget {
    let name: String
    let focusIdValue: String
    var frame = Rect.zero()
    let paintedFrames = ArrayList<Rect>()
    var presses: Int64 = 0

    init(name: String) {
        this.name = name
        this.focusIdValue = focusableControlIdentity("layout-transition-${name}")
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(40.0, available.w), min(40.0, available.h))
    }

    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }

    public func draw(ctx: UiContext): Unit {
        paintedFrames.add(frame)
        ctx.renderer.fill(frame, Color(66, 126, 214))
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) where frame.contains(x, y) =>
                presses += 1
                true
            case _ => false
        }
    }

    public func focusableId(): ?String { Some(focusIdValue) }
}

private class TransitionBuildCapture {
    var root: ?Widget = None
    var transition: ?KeyedLayoutTransition = None
    var probe: ?LayoutTransitionProbe = None
}

private func buildTransitionGrid(
    store: StateStore,
    items: Array<String>,
    columns: Int64,
    capture: TransitionBuildCapture,
    clip!: LayoutTransitionClip = LayoutTransitionClip.NoClip
): Unit {
    capture.root = Some(buildRoot(
        {
            =>
                Grid(columns) {
                    for (item in items) {
                        let transition = KeyedLayoutTransition(
                            item,
                            animation: AnimationSpec(duration: UInt64(100), easing: Easing.Linear),
                            clip: clip
                        ) {
                            let probe = LayoutTransitionProbe(item)
                            if (item == "a") { capture.probe = Some(probe) }
                        }
                        if (item == "a") { capture.transition = Some(transition) }
                    }
                }.spacing(10.0)
        },
        store
    ))
}

@Test
func keyedLayoutTransitionReordersAndRegridsWithoutMovingLogicalInput(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let capture = TransitionBuildCapture()

    buildTransitionGrid(store, ["a", "b"], 2, capture)
    capture.root.getOrThrow().layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))
    capture.root.getOrThrow().draw(ctx)
    let firstFocus = capture.probe.getOrThrow().focusIdValue
    @Expect(capture.transition.getOrThrow().geometry().current.x, Float32(0.0))

    buildTransitionGrid(store, ["b", "a"], 2, capture)
    let reordered = capture.root.getOrThrow()
    reordered.layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))
    let beforePaint = capture.transition.getOrThrow().geometry()
    @Expect(beforePaint.current.x, Float32(0.0))
    @Expect(beforePaint.target.x, Float32(110.0))
    reordered.draw(ctx)
    let moving = capture.transition.getOrThrow().geometry()
    @Expect(moving.current.x > Float32(0.0))
    @Expect(moving.current.x < Float32(110.0))
    @Expect(capture.probe.getOrThrow().focusIdValue, firstFocus)

    // Drawing happens at the interpolated rectangle, but the finally block restores the target.
    let probe = capture.probe.getOrThrow()
    @Expect(probe.frame.x, Float32(110.0))
    @Expect(!capture.transition.getOrThrow().handle(ctx,
        UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(capture.transition.getOrThrow().handle(ctx,
        UiEvent.MouseDown(MouseButton.Left, 130.0, 20.0)))
    @Expect(probe.presses, Int64(1))

    // A responsive two-column -> one-column change animates x, y and width together.
    let currentBeforeRetarget = moving.current
    buildTransitionGrid(store, ["b", "a"], 1, capture)
    ctx.frame = FrameInfo(UInt64(32), UInt64(0))
    let regridded = capture.root.getOrThrow()
    regridded.layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))
    regridded.draw(ctx)
    let retargeted = capture.transition.getOrThrow().geometry()
    @Expect(retargeted.current.x, currentBeforeRetarget.x)
    @Expect(retargeted.current.y, currentBeforeRetarget.y)
    @Expect(retargeted.current.w, currentBeforeRetarget.w)
    @Expect(retargeted.target.x, Float32(0.0))
    @Expect(retargeted.target.y, Float32(50.0))
    @Expect(retargeted.target.w, Float32(210.0))
}

@Test
func keyedLayoutTransitionFirstPlacementAndRemountAreSettled(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let capture = TransitionBuildCapture()

    buildTransitionGrid(store, ["a"], 1, capture)
    capture.root.getOrThrow().layout(ctx, Rect(50.0, 0.0, 100.0, 40.0))
    capture.root.getOrThrow().draw(ctx)
    let initial = capture.transition.getOrThrow().geometry()
    @Expect(initial.settled)
    @Expect(initial.current.x, Float32(50.0))

    // Unmount prunes the keyed local motion. The same key later starts from its new placement.
    let _ = buildRoot({=> Spacer()}, store)
    buildTransitionGrid(store, ["a"], 1, capture)
    capture.root.getOrThrow().layout(ctx, Rect(200.0, 0.0, 100.0, 40.0))
    let remounted = capture.transition.getOrThrow().geometry()
    @Expect(remounted.settled)
    @Expect(remounted.current.x, Float32(200.0))
    @Expect(remounted.target.x, Float32(200.0))
}

@Test
func keyedLayoutTransitionAutomaticSpecHonorsReducedMotion(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let captured = State<?KeyedLayoutTransition>(None)
    let build = {
        =>
            let _ = buildRoot(
                {
                    => captured.value = Some(KeyedLayoutTransition("reduced") {
                        LayoutTransitionProbe("reduced")
                    })
                },
                store
            )
    }

    build()
    captured.value.getOrThrow().layout(ctx, Rect(0.0, 0.0, 40.0, 40.0))
    captured.value.getOrThrow().draw(ctx)
    build()
    captured.value.getOrThrow().layout(ctx, Rect(100.0, 30.0, 80.0, 60.0))
    captured.value.getOrThrow().draw(ctx)
    let geometry = captured.value.getOrThrow().geometry()
    @Expect(geometry.settled)
    @Expect(geometry.current.x, Float32(100.0))
    @Expect(geometry.current.y, Float32(30.0))
    @Expect(geometry.current.w, Float32(80.0))
    @Expect(geometry.current.h, Float32(60.0))
}

@Test
func keyedLayoutTransitionClipProducesDeterministicDrawIr(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let capture = TransitionBuildCapture()

    buildTransitionGrid(store, ["a", "b"], 2, capture, clip: LayoutTransitionClip.AnimatedBounds)
    capture.root.getOrThrow().layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))
    capture.root.getOrThrow().draw(ctx)
    buildTransitionGrid(store, ["b", "a"], 2, capture, clip: LayoutTransitionClip.AnimatedBounds)
    renderer.clearDrawIr()
    capture.root.getOrThrow().layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))
    capture.root.getOrThrow().draw(ctx)

    var pushes: Int64 = 0
    var pops: Int64 = 0
    var fills: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == "clip.push") { pushes += 1 }
        if (command.kind == "clip.pop") { pops += 1 }
        if (command.kind == "paint.fill") { fills += 1 }
    }
    @Expect(pushes, Int64(2))
    @Expect(pops, Int64(2))
    @Expect(fills, Int64(2))
}
