package chui.core

import sdl.{FrameInfo, MouseButton, Rect, Size, UiEvent}

// A probe child that records pointer hits against the full-height frame Reveal lays it out at — the
// stand-in for any interactive widget (button, link) hidden inside a collapsed disclosure.
private class ProbePad <: Widget {
    var clicks: Int64 = 0
    var wheels: Int64 = 0
    private var frame = Rect.zero()

    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 40.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) where frame.contains(x, y) =>
                clicks += 1
                true
            case UiEvent.MouseWheel(_, _, x, y) where frame.contains(x, y) =>
                wheels += 1
                true
            case _ => false
        }
    }

    public func focusableIds(): Array<String> {
        ["probe-pad"]
    }
}

// Drives a Reveal across rebuilds under one store (so its Animator persists), returning the captured
// instance each frame. Mirrors how the app rebuilds the tree every frame in immediate mode.
private func buildReveal(store: StateStore, shown: State<Bool>, captured: State<?Reveal>): () -> Unit {
    {
        =>
        let _ = buildRoot(
            {
                =>
                let r = Reveal(shown: shown.value, key: "disclosure", duration: 100) {
                    Label("Answer body")
                }
                captured.value = Some(r)
            },
            store
        )
    }
}

// Same as buildReveal but with a start delay, as a staggered cascade gives each row.
private func buildDelayedReveal(store: StateStore, shown: State<Bool>, captured: State<?Reveal>): () -> Unit {
    {
        =>
        let _ = buildRoot(
            {
                =>
                let r = Reveal(shown: shown.value, key: "delayed", duration: 100, delay: 200) {
                    Label("Answer body")
                }
                captured.value = Some(r)
            },
            store
        )
    }
}

@Test
func revealDelayHoldsCollapsedThenOpens(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16)) // deltaMs = 16
    let store = StateStore()
    let shown = State<Bool>(false)
    let captured = State<?Reveal>(None)
    let build = buildDelayedReveal(store, shown, captured)

    // Prime content height while collapsed.
    build()
    let _ = captured.value.getOrThrow().measure(ctx, Size(240.0, 400.0))

    // Open it, but drive only part of the 200ms delay (6 frames * 16ms ≈ 96ms): still shut.
    shown.value = true
    var height: Float32 = 0.0
    for (_ in 0..6) {
        build()
        let reveal = captured.value.getOrThrow()
        let size = reveal.measure(ctx, Size(240.0, 400.0))
        reveal.layout(ctx, Rect(0.0, 0.0, 240.0, size.h))
        reveal.draw(ctx)
        height = size.h
    }
    @Expect(height < Float32(1.0)) // the delay is still holding this row's turn

    // Drive past the delay plus the ease: it opens fully, exactly as an undelayed reveal would.
    for (_ in 0..30) {
        build()
        let reveal = captured.value.getOrThrow()
        let size = reveal.measure(ctx, Size(240.0, 400.0))
        reveal.layout(ctx, Rect(0.0, 0.0, 240.0, size.h))
        reveal.draw(ctx)
        height = size.h
    }
    @Expect(height > Float32(20.0))
}

@Test
func revealCollapsedBlocksInputAndFocus(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let shown = State<Bool>(false)
    let reveal = State<?Reveal>(None)
    let probe = State<?ProbePad>(None)
    let build = {
        =>
        let _ = buildRoot(
            {
                =>
                let r = Reveal(shown: shown.value, key: "gate", duration: 100) {
                    probe.value = Some(ProbePad())
                }
                reveal.value = Some(r)
            },
            store
        )
    }

    // Collapsed: the child still gets a full-height layout frame (it wipes rather than squashes), but
    // a click into that hidden area must not reach it, and it must offer no keyboard focus stops.
    build()
    let shut = reveal.value.getOrThrow()
    let size = shut.measure(ctx, Size(240.0, 400.0))
    shut.layout(ctx, Rect(0.0, 0.0, 240.0, size.h))
    @Expect(size.h < Float32(1.0))
    @Expect(!shut.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)))
    @Expect(probe.value.getOrThrow().clicks, 0)
    @Expect(shut.focusableIds().size, 0)
    // The per-frame tick still flows to the hidden subtree (animations and polling keep running).
    let _ = shut.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(16), UInt64(16))))

    // Open it fully: the same click lands, and the focus stop is offered again.
    shown.value = true
    for (_ in 0..30) {
        build()
        let r = reveal.value.getOrThrow()
        let s = r.measure(ctx, Size(240.0, 400.0))
        r.layout(ctx, Rect(0.0, 0.0, 240.0, s.h))
        r.draw(ctx)
    }
    let open = reveal.value.getOrThrow()
    @Expect(open.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)))
    @Expect(probe.value.getOrThrow().clicks, 1)
    @Expect(open.focusableIds().size, 1)
}

@Test
func revealStartsCollapsedAndSettled(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let shown = State<Bool>(false)
    let captured = State<?Reveal>(None)
    let build = buildReveal(store, shown, captured)

    build()
    let reveal = captured.value.getOrThrow()
    // Collapsed and settled on the first frame: measured height is essentially zero, no animation.
    let size = reveal.measure(ctx, Size(240.0, 400.0))
    @Expect(size.h < Float32(1.0))
}

@Test
func revealStartsExpandedWhenShown(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let shown = State<Bool>(true)
    let captured = State<?Reveal>(None)
    let build = buildReveal(store, shown, captured)

    build()
    let reveal = captured.value.getOrThrow()
    // Already open: a static first frame shows full content height immediately (snapshot-stable).
    let size = reveal.measure(ctx, Size(240.0, 400.0))
    @Expect(size.h > Float32(20.0)) // a single Label is ~28 tall headless
}

@Test
func revealAnimatesOpenThenClosed(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16)) // deltaMs = 16
    let store = StateStore()
    let shown = State<Bool>(false)
    let captured = State<?Reveal>(None)
    let build = buildReveal(store, shown, captured)

    // Prime content height while collapsed.
    build()
    let _ = captured.value.getOrThrow().measure(ctx, Size(240.0, 400.0))

    // Open it and drive frames (100ms duration / 16ms ≈ 7 frames; drive well past).
    shown.value = true
    var openedH: Float32 = 0.0
    for (_ in 0..30) {
        build()
        let reveal = captured.value.getOrThrow()
        let size = reveal.measure(ctx, Size(240.0, 400.0))
        reveal.layout(ctx, Rect(0.0, 0.0, 240.0, size.h))
        reveal.draw(ctx) // ticks the animator toward open
        openedH = size.h
    }
    @Expect(openedH > Float32(20.0)) // reached full content height

    // Close it and drive frames back down to zero.
    shown.value = false
    var closedH: Float32 = openedH
    for (_ in 0..30) {
        build()
        let reveal = captured.value.getOrThrow()
        let size = reveal.measure(ctx, Size(240.0, 400.0))
        reveal.layout(ctx, Rect(0.0, 0.0, 240.0, size.h))
        reveal.draw(ctx)
        closedH = size.h
    }
    @Expect(closedH < Float32(1.0)) // fully collapsed again
}

@Test
func revealGatesWheelByPointerPositionNotDelta(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let shown = State<Bool>(true)
    let reveal = State<?Reveal>(None)
    let probe = State<?ProbePad>(None)
    let build = {
        =>
        let _ = buildRoot(
            {
                =>
                let r = Reveal(shown: shown.value, key: "wheel-gate", duration: 100) {
                    probe.value = Some(ProbePad())
                }
                reveal.value = Some(r)
            },
            store
        )
    }

    // Open it fully, laid out away from the origin, so a wheel delta of ±1 can never fall inside
    // the frame by accident — the gate must test the pointer position, not the scroll delta.
    for (_ in 0..30) {
        build()
        let r = reveal.value.getOrThrow()
        let s = r.measure(ctx, Size(240.0, 400.0))
        r.layout(ctx, Rect(100.0, 80.0, 240.0, s.h))
        r.draw(ctx)
    }
    let open = reveal.value.getOrThrow()
    @Expect(open.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 110.0, 90.0)))
    @Expect(probe.value.getOrThrow().wheels, 1)
    // A wheel with the pointer outside the revealed area stays gated.
    @Expect(!open.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 10.0, 10.0)))
    @Expect(probe.value.getOrThrow().wheels, 1)
}
