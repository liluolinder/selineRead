package chui.core

import sdl.{Rect, Size, UiEvent}

private class AdaptiveGridLayoutProbe <: Widget {
    let preferred: Size
    var frame = Rect.zero()

    init(width: Float32, height: Float32) { preferred = Size(width, height) }
    public func measure(_: UiContext, _: Size): Size { preferred }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func adaptiveGridColumnMathCoversCompactCommonAndWideWidths(): Unit {
    @Expect(adaptiveGridColumns(220.0, 160.0, 8.0), 1)
    @Expect(adaptiveGridColumns(500.0, 160.0, 8.0), 3)
    @Expect(adaptiveGridColumns(1200.0, 160.0, 8.0, maxColumns: 4), 4)
    @Expect(adaptiveGridColumns(80.0, 160.0, 8.0, minColumns: 2, maxColumns: 4), 2)
}

@Test
func adaptiveGridLaysOutStableEqualCellsWithoutChangingFixedGrid(): Unit {
    let first = AdaptiveGridLayoutProbe(40.0, 20.0)
    let second = AdaptiveGridLayoutProbe(40.0, 30.0)
    let third = AdaptiveGridLayoutProbe(40.0, 10.0)
    let grid = AdaptiveGrid(120.0) {
        emit(first); emit(second); emit(third)
    }.spacing(10.0)
    let ctx = testContext()
    let measured = grid.measure(ctx, Size(380.0, 500.0))
    grid.layout(ctx, Rect(0.0, 0.0, 380.0, measured.h))
    @Expect(grid.resolvedColumns(), 3)
    @Expect(first.frame.w, 120.0)
    @Expect(second.frame.x, 130.0)
    @Expect(third.frame.x, 260.0)
}
