package chui.core

import sdl.{FrameInfo, MouseButton, Rect, Size, UiEvent}

private class CollapsibleScrollProbe <: Widget {
    let contentExtent: State<Float32>
    var rect = Rect.zero()

    init(contentExtent: State<Float32>) {
        this.contentExtent = contentExtent
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, contentExtent.value)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        this.rect = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (rect.contains(x, y)) {
                    ctx.preserveScrollAnchor()
                    contentExtent.value = 150.0
                    return true
                }
            case _ => ()
        }
        false
    }
}


@Test
func scrollWheelClampsOffsetWithinContent(): Unit {
    @Expect(scrollOffsetAfterWheel(0.0, -1.0, 240.0, 96.0), Float32(72.0))
    @Expect(scrollOffsetAfterWheel(140.0, -1.0, 240.0, 96.0), Float32(144.0))
    @Expect(scrollOffsetAfterWheel(20.0, 1.0, 240.0, 96.0), Float32(0.0))
}

@Test
func scrollViewUsesExternalOffsetAndEasesDefaultWheelInput(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(120.0, 240.0))
    let view = ScrollView(key: "audit") {
        emit(child)
    }.scrollState(offset)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    @Expect(offset.value, Float32(0.0))
    @Expect(ctx.takeFrameRequest())

    ctx.frame = FrameInfo(UInt64(110), UInt64(110))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    @Expect(offset.value > Float32(0.0))
    @Expect(offset.value < Float32(72.0))
    @Expect(child.rect.y < Float32(0.0))

    ctx.frame = FrameInfo(UInt64(330), UInt64(220))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    @Expect(offset.value, Float32(72.0))
    @Expect(child.rect.y, Float32(-72.0))
}

@Test
func scrollThumbGeometryMapsOffsetsBothWays(): Unit {
    let frame = Rect(0.0, 0.0, 120.0, 100.0)

    // Content fits: no thumb.
    @Expect(scrollThumbRect(frame, 0.0, 80.0, 100.0).isNone())

    // Overflowing: thumb sits at the track top for offset 0.
    let top = scrollThumbRect(frame, 0.0, 300.0, 100.0)
    @Expect(top.isSome())
    @Expect(top.getOrThrow().y, Float32(2.0))

    // Offset → thumb top → offset round-trips exactly.
    let track = scrollBarTrackRect(frame)
    let thumbH = scrollThumbHeight(track, 300.0, 100.0)
    let thumbTop = scrollThumbTop(track, thumbH, 100.0, 300.0, 100.0)
    @Expect(scrollOffsetForThumbTop(thumbTop, track, thumbH, 300.0, 100.0), Float32(100.0))
}

@Test
func scrollViewThumbDragUpdatesOffset(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(120.0, 300.0))
    let view = ScrollView(key: "bar") {
        emit(child)
    }.scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    // Grab the thumb (top-left at y=2, height 32) near its top, then drag down 40px.
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 115.0, 10.0)))
    ctx.leftMouseDown = true
    @Expect(view.handle(ctx, UiEvent.MouseMove(115.0, 50.0)))
    @Expect(offset.value, Float32(125.0))
}

@Test
func scrollViewTrackClickPagesTowardClick(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(120.0, 300.0))
    let view = ScrollView(key: "bar2") {
        emit(child)
    }.scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    // Click the track well below the thumb: page down by 0.9 * viewport height.
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 115.0, 80.0)))
    @Expect(offset.value, Float32(90.0))
}

@Test
func scrollViewReservesBarGutterOnlyWhenContentOverflows(): Unit {
    let ctx = testContext()
    let tall = SizedLayoutProbe(Size(300.0, 240.0))
    let overflowing = ScrollView(key: "gutter.tall") {
        emit(tall)
    }
    overflowing.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    // 240 > 80: the bar appears, so content gives up its 10-px gutter (6 + 2 margin each side).
    @Expect(tall.rect.w, Float32(110.0))

    let short = SizedLayoutProbe(Size(300.0, 40.0))
    let fitting = ScrollView(key: "gutter.short") {
        emit(short)
    }
    fitting.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    // 40 <= 80: no bar, content keeps the full viewport width.
    @Expect(short.rect.w, Float32(120.0))
}

@Test
func scrollLineHelpersSplitOffsetIntoIndexAndRemainder(): Unit {
    @Expect(scrollLineIndex(0.0), 0)
    @Expect(scrollLineIndex(28.0), 1)
    @Expect(scrollLineIndex(70.0), 2)
    @Expect(scrollLineRemainder(70.0), Float32(14.0))
    @Expect(scrollLineIndex(-5.0), 0)
    @Expect(scrollLineRemainder(-5.0), Float32(0.0))
}


@Test
func scrollBarDragKeepsGrabAcrossRebuilds(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let frame = Rect(0.0, 0.0, 12.0, 200.0)
    let contentH: Float32 = 400.0

    // Frame N: press the middle of the thumb on this frame's controller instance.
    let pressBar = ScrollBar("audit:thumb")
    let thumb = scrollThumbRect(frame, offset.value, contentH, 200.0).getOrThrow()
    let grabY = thumb.y + thumb.h / 2.0
    @Expect(pressBar.press(ctx, frame, offset, contentH, 200.0, thumb.x + thumb.w / 2.0, grabY))

    // Frame N+1: the tree rebuilds, so a fresh instance continues the drag. The grab point rides
    // in the context beside the drag id; a motionless pointer must not move the content.
    ctx.leftMouseDown = true
    let dragBar = ScrollBar("audit:thumb")
    @Expect(dragBar.drag(ctx, frame, offset, contentH, 200.0, grabY))
    @Expect(offset.value, Float32(0.0))
}

@Test
func scrollViewLetsWheelFallThroughWhenContentFits(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(120.0, 80.0))
    let view = ScrollView(key: "fits") {
        emit(child)
    }.scrollState(offset)

    view.layout(ctx, Rect(0.0, 0.0, 160.0, 200.0))

    // Content shorter than the viewport: the wheel is not consumed (no dead zone inside an
    // enclosing scroller) and the offset stays put.
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 50.0, 50.0)))
    @Expect(offset.value, Float32(0.0))
}

@Test
func repeatedStaticScrollViewLayoutDoesNotInvalidateAnotherFrame(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(120.0, 240.0))
    let view = ScrollView(key: "static-layout") {
        emit(child)
    }
    let bounds = Rect(0.0, 0.0, 120.0, 80.0)

    view.layout(ctx, bounds)
    let settledGeneration = currentStateGeneration()
    view.layout(ctx, bounds)

    @Expect(currentStateGeneration(), settledGeneration)
}

@Test
func scrollViewRetainsOffsetWhileDynamicContentCollapses(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(200.0)
    let height = State<Float32>(300.0)
    let child = CollapsibleScrollProbe(height)
    let view = ScrollView(key: "anchor") {
        emit(child)
    }.scrollState(offset)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(200.0))
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    // The raw content lost 150px, but retained tail space prevents an automatic jump from 200 to 50.
    @Expect(height.value, Float32(150.0))
    @Expect(offset.value, Float32(200.0))

    // The next explicit scroll gesture releases the retained anchor and clamps to the new real extent.
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, 0.0, 20.0, 20.0)))
    @Expect(offset.value, Float32(50.0))
}

@Test
func scrollViewDoesNotConsumeAStaleAnchorRequestFromOutsideItsSubtree(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(200.0)
    let height = State<Float32>(300.0)
    let child = CollapsibleScrollProbe(height)
    let view = ScrollView(key: "anchor.stale") {
        emit(child)
    }.scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    ctx.preserveScrollAnchor()
    @Expect(!view.handle(ctx, UiEvent.MouseMove(20.0, 20.0)))
    height.value = 150.0
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    @Expect(offset.value, Float32(50.0))
}
