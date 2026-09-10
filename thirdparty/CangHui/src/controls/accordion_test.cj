package chui.controls

import std.collection.HashSet
import sdl.{FrameInfo, Key, MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{ScrollOptions, ScrollView, Spacer, State, StateStore, Theme, UiContext, Widget, buildRoot, emit}

private func accordionTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

// A reference-type counter so a build closure can tally invocations (captured vars are read-only).
private class LazyBuildCounter {
    var count: Int64 = 0

    func bump(): Unit {
        count += 1
    }
}

// A layout probe with a fixed desired size, standing in for real section content.
private class SizedLayoutProbe <: Widget {
    let desired: Size

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private func intSet(values: Array<Int64>): HashSet<Int64> {
    let set = HashSet<Int64>()
    for (value in values) {
        set.add(value)
    }
    set
}

// A leaf reporting a fixed focus id, so the accordion's focus order can be inspected.
private class AccFocusProbe <: Widget {
    private let id: String

    init(id: String) {
        this.id = id
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

private class AccordionScrollContent <: Widget {
    private let accordion: Accordion

    init(accordion: Accordion) {
        this.accordion = accordion
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(available.w, 200.0 + accordion.measure(ctx, available).h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        accordion.layout(ctx, Rect(rect.x, rect.y + 200.0, rect.w, max(0.0, rect.h - 200.0)))
    }

    public func draw(ctx: UiContext): Unit {
        accordion.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        accordion.handle(ctx, event)
    }

    public func focusableIds(): Array<String> {
        accordion.focusableIds()
    }
}

@Test
func accordionBuildsOnlyOpenBodies(): Unit {
    let counter = LazyBuildCounter()
    let acc = Accordion([
        AccordionSection("A") {=> counter.bump(); emit(Spacer())},
        AccordionSection("B") {=> counter.bump(); emit(Spacer())},
        AccordionSection("C") {=> counter.bump(); emit(Spacer())}
    ], expanded: State<HashSet<Int64>>(intSet([1])))
    // Only section 1 is open, so only its body builder ran.
    @Expect(counter.count, 1)
    @Expect(acc.focusableIds().size >= 3, true) // three headers at least
}

@Test
func accordionMeasureSumsHeadersAndOpenBodies(): Unit {
    let ctx = accordionTestContext()
    let acc = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: State<HashSet<Int64>>(intSet([0])))
    // header(42) + open body(50) + header(42); section B is collapsed and contributes nothing.
    @Expect(acc.measure(ctx, Size(300.0, 1000.0)).h, Float32(134.0))
}

@Test
func accordionClickHeaderTogglesSection(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(Spacer())},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: expanded)
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 400.0))

    // Header 0 spans y 0..42; a click on it opens the section.
    @Expect(acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 20.0)))
    @Expect(acc.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 150.0, 20.0)))
    @Expect(expanded.value.contains(0))
    // A second click closes it again.
    let _ = acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 20.0))
    let _ = acc.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 150.0, 20.0))
    @Expect(!expanded.value.contains(0))
}

@Test
func accordionHeaderMoveOutCancelsWithoutReactivatingOnMoveIn(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(Spacer())}
    ], expanded: expanded, key: "cancel")
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))

    @Expect(acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 100.0, 20.0)))
    let _ = acc.handle(ctx, UiEvent.MouseMove(320.0, 20.0))
    let _ = acc.handle(ctx, UiEvent.MouseMove(100.0, 20.0))
    @Expect(!acc.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 100.0, 20.0)))
    @Expect(!expanded.value.contains(0))
}

@Test
func accordionCollapsePreservesOuterScrollAnchor(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([0]))
    let offset = State<Float32>(200.0)
    let accordion = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 150.0)))}
    ], expanded: expanded, key: "anchor.child")
    let content = AccordionScrollContent(accordion)
    let view = ScrollView(key: "anchor.outer") {
        emit(content)
    }.scrollState(offset).scrollOptions(ScrollOptions.immediate())

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(200.0))
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    @Expect(!expanded.value.contains(0))

    ctx.frame = FrameInfo(UInt64(300), UInt64(300))
    view.draw(ctx)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(200.0))
}

@Test
func accordionExpansionPreservesOuterScrollAnchor(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let offset = State<Float32>(142.0)
    let accordion = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 150.0)))}
    ], expanded: expanded, key: "anchor.expand.child")
    let content = AccordionScrollContent(accordion)
    let view = ScrollView(key: "anchor.expand.outer") {
        emit(content)
    }.scrollState(offset).scrollOptions(ScrollOptions.immediate())

    // Closed content is 242px high, so offset 142 is its exact bottom edge in a 100px viewport.
    // The header appears at y=58 after scrolling and must stay at the same visual location on expand.
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(142.0))
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 70.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 70.0)))
    @Expect(expanded.value.contains(0))

    ctx.frame = FrameInfo(UInt64(300), UInt64(300))
    view.draw(ctx)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(142.0))
}

@Test
func accordionSingleModeClosesOthersOnOpen(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([0]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("B") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("C") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))}
    ], single: true, expanded: expanded)
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 600.0))

    // Header 1 sits below header 0 (42) and open body 0 (50), at y 92..134.
    @Expect(acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 110.0)))
    @Expect(acc.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 150.0, 110.0)))
    @Expect(expanded.value.contains(1))
    @Expect(!expanded.value.contains(0)) // single mode closed the previously open section
}

@Test
func accordionExpansionUsesRetainedAutomaticHeightMotion(): Unit {
    let ctx = accordionTestContext()
    let store = StateStore()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let captured = State<?Widget>(None)

    let first = buildRoot({
        => captured.value = Some(Accordion([
            AccordionSection("Animated") {=> emit(SizedLayoutProbe(Size(100.0, 80.0)))}
        ], expanded: expanded, key: "animated"))
    }, store)
    first.layout(ctx, Rect(0.0, 0.0, 300.0, 200.0))
    @Expect(first.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 100.0, 20.0)))
    @Expect(first.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 100.0, 20.0)))

    let second = buildRoot({
        => captured.value = Some(Accordion([
            AccordionSection("Animated") {=> emit(SizedLayoutProbe(Size(100.0, 80.0)))}
        ], expanded: expanded, key: "animated"))
    }, store)
    second.layout(ctx, Rect(0.0, 0.0, 300.0, 200.0))
    ctx.frame = FrameInfo(UInt64(80), UInt64(80))
    second.draw(ctx)
    let animatedHeight = second.measure(ctx, Size(300.0, 500.0)).h
    @Expect(animatedHeight > Float32(42.0))
    @Expect(animatedHeight < Float32(122.0))
}

@Test
func accordionKeyboardTogglesFocusedHeader(): Unit {
    let ctx = accordionTestContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(Spacer())},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: expanded, key: "acc")
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 400.0))
    ctx.focus("Accordion:acc:header:1")

    @Expect(acc.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(expanded.value.contains(1))
    @Expect(acc.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!expanded.value.contains(1)) // Space toggles it back
}

@Test
func accordionFocusOrderInterleavesHeadersAndOpenBodies(): Unit {
    let expanded = State<HashSet<Int64>>(intSet([0]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(AccFocusProbe("bodyA"))},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: expanded, key: "acc")

    let ids = acc.focusableIds()
    // header 0, then its open body's stop, then header 1 (its body is collapsed).
    @Expect(ids.size, 3)
    @Expect(ids[0], "Accordion:acc:header:0")
    @Expect(ids[1], "bodyA")
    @Expect(ids[2], "Accordion:acc:header:1")

    // The body may remain mounted for its closing animation, but it leaves input and focus immediately.
    expanded.value = intSet([])
    let closingIds = acc.focusableIds()
    @Expect(closingIds.size, 2)
    @Expect(closingIds[0], "Accordion:acc:header:0")
    @Expect(closingIds[1], "Accordion:acc:header:1")
}
