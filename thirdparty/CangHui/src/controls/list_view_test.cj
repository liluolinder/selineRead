package chui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{ScrollOptions, State, StateStore, Theme, UiContext, buildRoot}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func listViewUsesScrollOffsetWhenSelectingRows(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F"], selected, scroll: Some(scroll))
        .scrollOptions(ScrollOptions.immediate())

    list.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))

    @Expect(list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewArrowKeysMoveSelectionAndKeepItVisible(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))
    ctx.focus("ListView")

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(7))
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(0))
    @Expect(scroll.value, Float32(0.0))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Up, false))) // clamps at the top
    @Expect(selected.value, Int64(0))
}

@Test
func listViewIgnoresArrowsWithoutFocus(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(3)
    let list = ListView(["A", "B", "C", "D", "E"], selected)
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))

    @Expect(!list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(3))
}

// Without an external scroll state, the wheel offset must survive the per-frame rebuild — a
// regression guard for the fresh-State-each-frame bug that made a scrolled list spring back.
@Test
func listViewRetainsScrollAcrossRebuildsWithoutExternalState(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let selected = State<Int64>(0)
    let captured = State<?ListView>(None)
    let build = {
        =>
        let _ = buildRoot({
            =>
            let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected)
                .scrollOptions(ScrollOptions.immediate())
            captured.value = Some(list)
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    first.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    let _ = first.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)) // offset -> 72

    // Next frame: a brand-new ListView instance under the same store must see the retained offset.
    build()
    let second = captured.value.getOrThrow()
    second.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    // A click near the top now lands on a scrolled-past row (offset 72 / 28px rows -> index 2),
    // which only holds if the offset carried over rather than resetting to 0.
    @Expect(second.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewScrollbarThumbIsDraggable(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(Array<String>(20, {i => "row ${i}"}), selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    // Grab the thumb in the right-edge lane, then drag it down.
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 8.0)))
    ctx.leftMouseDown = true
    @Expect(list.handle(ctx, UiEvent.MouseMove(195.0, 60.0)))
    @Expect(scroll.value > Float32(0.0))
}

@Test
func listViewRevealsExternallyChangedSelectionOnDraw(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))

    list.draw(ctx) // reveals the initial selection (0) — stays at the top
    @Expect(scroll.value, Float32(0.0))

    selected.value = 7 // app moved it directly, bypassing the list's own key handling
    list.draw(ctx)
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    let held = scroll.value
    list.draw(ctx) // unchanged selection — must not re-scroll
    @Expect(scroll.value, held)
}

// From no selection (-1), Down must land on the first row, not skip to the second.
@Test
func listViewAcceptsOptionalExplicitId(): Unit {
    let ctx = controlTestContext()
    let sel = State<Int64>(-1)
    let list = ListView(["a", "b", "c"], sel, key: "servers")
    list.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    match (list.focusableId()) {
        case Some(fid) => @Expect(fid, "servers")
        case None => @Expect(false, true)
    }
}

// Stepper now accepts range/step in the constructor (aligning with Slider/ProgressBar), clamping the
// initial value into range at construction just as the chained range() does.

@Test
func listViewLetsWheelFallThroughWhenContentFits(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let list = ListView(["A", "B"], selected)

    list.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))

    // Two rows in a tall viewport: the list cannot scroll, so it leaves the wheel to an
    // enclosing scroller instead of consuming it into a dead zone.
    @Expect(!list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
}
