package chui.core

import std.collection.ArrayList
import sdl.{MouseButton, Rect, Size, UiEvent}


class LayoutProbe <: Widget {
    var rect = Rect.zero()

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

class SizedLayoutProbe <: Widget {
    let desired: Size
    var rect = Rect.zero()

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

class NaturallyFlexibleLayoutProbe <: Widget {
    var rect = Rect.zero()

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        true
    }
}

class ZOrderLog {
    let values = ArrayList<String>()
}

class ZOrderProbe <: Widget {
    let name: String
    let log: ZOrderLog
    let consumes: Bool

    init(name: String, log: ZOrderLog, consumes!: Bool = false) {
        this.name = name
        this.log = log
        this.consumes = consumes
    }

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit { log.values.add("draw-" + name) }
    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(_, _, _) =>
                log.values.add("event-" + name)
                consumes
            case _ => false
        }
    }
}

@Test
func exactWidthRemovesNaturallyFlexibleChildFromHorizontalFlexPass(): Unit {
    let ctx = testContext()
    let gutter = NaturallyFlexibleLayoutProbe()
    let editor = LayoutProbe()
    let view = HStack(spacing: 0.vp) {
        emit(gutter)
        gutter.width(45.0)
        emit(editor)
        editor.layoutWeight()
    }

    view.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))

    @Expect(gutter.rect.w, Float32(45.0))
    @Expect(editor.rect.x, Float32(45.0))
    @Expect(editor.rect.w, Float32(255.0))
}

@Test
func exactHeightRemovesNaturallyFlexibleChildFromVerticalFlexPass(): Unit {
    let ctx = testContext()
    let header = NaturallyFlexibleLayoutProbe()
    let body = LayoutProbe()
    let view = VStack(spacing: 0.vp) {
        emit(header)
        header.height(32.0)
        emit(body)
        body.layoutWeight()
    }

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 200.0))

    @Expect(header.rect.h, Float32(32.0))
    @Expect(body.rect.y, Float32(32.0))
    @Expect(body.rect.h, Float32(168.0))
}

@Test
func chainedSizeModifiersReplaceEmittedNode(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(12.0, 12.0))
    let view = VStack {
        emit(child)
        child.width(100.0).height(24.0)
    }

    view.layout(ctx, Rect(0.0, 0.0, 300.0, 80.0))

    @Expect(child.rect.w, Float32(100.0))
    @Expect(child.rect.h, Float32(24.0))
}

@Test
func paddingModifierContributesToMeasuredSize(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(40.0, 20.0))
    let decorated = child.padding(6.0)
    let measured = decorated.measure(ctx, Size(200.0, 100.0))

    @Expect(measured.w, Float32(52.0))
    @Expect(measured.h, Float32(32.0))
}

@Test
func stackAlignmentPositionsContentWithoutConstructorNoise(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(40.0, 20.0))
    let view = VStack {
        emit(child)
    }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.End)

    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    @Expect(child.rect.x, Float32(160.0))
    @Expect(child.rect.y, Float32(40.0))
    @Expect(child.rect.w, Float32(40.0))
    @Expect(child.rect.h, Float32(20.0))
}

@Test
func gridAssignsEqualColumnsAndContentSizedRows(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(30.0, 20.0))
    let second = SizedLayoutProbe(Size(40.0, 32.0))
    let third = SizedLayoutProbe(Size(50.0, 18.0))
    let grid = Grid(2) {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(10.0)

    grid.layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))

    @Expect(first.rect.w, Float32(100.0))
    @Expect(second.rect.x, Float32(110.0))
    @Expect(first.rect.h, Float32(32.0))
    @Expect(third.rect.y, Float32(42.0))
}

@Test
func flowRowWrapsAtAvailableWidth(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(70.0, 20.0))
    let second = SizedLayoutProbe(Size(70.0, 24.0))
    let third = SizedLayoutProbe(Size(70.0, 18.0))
    let flow = FlowRow {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(8.0)

    flow.layout(ctx, Rect(0.0, 0.0, 150.0, 100.0))

    @Expect(second.rect.x, Float32(78.0))
    @Expect(third.rect.x, Float32(0.0))
    @Expect(third.rect.y, Float32(32.0))
}

@Test
func invisibleWidgetLeavesNoStackGap(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(40.0, 20.0))
    let hidden = SizedLayoutProbe(Size(40.0, 20.0))
    let last = SizedLayoutProbe(Size(40.0, 20.0))
    let view = VStack {
        emit(first)
        emit(hidden)
        hidden.visible(false)
        emit(last)
    }.spacing(10.0).crossAxisAlignment(CrossAxisAlignment.Start)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    @Expect(last.rect.y, Float32(30.0))
    @Expect(hidden.rect.h, Float32(0.0))
}

@Test
func flexibleWeightSpansColumnsExactly(): Unit {
    let ctx = testContext()
    let zero = LayoutProbe()
    let dot = LayoutProbe()
    let equals = LayoutProbe()
    let row = HStack(spacing: 10.vp) {
        Flexible(weight: 2.0) {
            emit(zero)
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            emit(equals)
        }
    }

    row.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // unit = (430 - two gaps - one absorbed gap) / 4 weights = 100; the weight-2 cell
    // spans two units plus the gap between them, exactly two single columns wide.
    @Expect(zero.rect.w, Float32(210.0))
    @Expect(dot.rect.x, Float32(220.0))
    @Expect(dot.rect.w, Float32(100.0))
    @Expect(equals.rect.x, Float32(330.0))
}

@Test
func hugOptsStackOutOfParentFlexPass(): Unit {
    // A stack fills its parent's main-axis slot by default; .hug() sizes it to content instead —
    // the intent-revealing equivalent of the (far more common) .flexible(false).
    @Expect((VStack {emit(LayoutProbe())}).isFlexible(), true)
    @Expect((VStack {emit(LayoutProbe())}.hug()).isFlexible(), false)
    @Expect((VStack {emit(LayoutProbe())}.flexible(false)).isFlexible(), false)
    @Expect((HStack {emit(LayoutProbe())}.hug()).isFlexible(), false)
}

@Test
func hugStackSizesToContentWhileFlexibleSiblingFills(): Unit {
    let ctx = testContext()
    // A 200-tall column whose first child holds a 30-tall probe; the trailing probe's y reveals how
    // much room the first child consumed. With .hug() the first child takes only its content, so the
    // tail sits near the top; by default the first child fills, shoving the tail to the bottom.
    let hugTail = LayoutProbe()
    let hugColumn = VStack {
        VStack {emit(SizedLayoutProbe(Size(50.0, 30.0)))}.hug()
        emit(hugTail)
    }
    hugColumn.layout(ctx, Rect(0.0, 0.0, 100.0, 200.0))

    let fillTail = LayoutProbe()
    let fillColumn = VStack {
        VStack {emit(SizedLayoutProbe(Size(50.0, 30.0)))} // default flexible: fills the column
        emit(fillTail)
    }
    fillColumn.layout(ctx, Rect(0.0, 0.0, 100.0, 200.0))

    @Expect(hugTail.rect.y < fillTail.rect.y, true)
    @Expect(hugTail.rect.y < 60.0, true) // content (30) + one gap, nowhere near the 200-tall column
    @Expect(fillTail.rect.y > 150.0, true) // the filling child pushed the tail down the column
}

@Test
func flexibleWeightRowsAlignWithUniformRows(): Unit {
    let ctx = testContext()
    let third = LayoutProbe()
    let uniform = HStack(spacing: 10.vp) {
        Flexible {
            Spacer()
        }
        Flexible {
            Spacer()
        }
        Flexible {
            emit(third)
        }
        Flexible {
            Spacer()
        }
    }
    let dot = LayoutProbe()
    let weighted = HStack(spacing: 10.vp) {
        Flexible(weight: 2.0) {
            Spacer()
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            Spacer()
        }
    }

    uniform.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))
    weighted.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // The cell after a weight-2 span starts exactly where the third uniform column does.
    @Expect(dot.rect.x, third.rect.x)
    @Expect(dot.rect.w, third.rect.w)
}

// A probe that refuses stretching, so overlay alignment math can be asserted.
class RigidLayoutProbe <: Widget {
    let desired: Size
    var rect = Rect.zero()

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}

@Test
func stackSpaceBetweenPinsEndsAndSharesLeftover(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(20.0, 10.0))
    let second = SizedLayoutProbe(Size(20.0, 10.0))
    let third = SizedLayoutProbe(Size(20.0, 10.0))
    let view = HStack {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(0.0).mainAxisAlignment(MainAxisAlignment.SpaceBetween)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))

    @Expect(first.rect.x, Float32(0.0))
    @Expect(second.rect.x, Float32(50.0))
    @Expect(third.rect.x, Float32(100.0))
}

@Test
func stackSpaceEvenlyDistributesAroundChildren(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(20.0, 10.0))
    let second = SizedLayoutProbe(Size(20.0, 10.0))
    let view = HStack {
        emit(first)
        emit(second)
    }.spacing(0.0).mainAxisAlignment(MainAxisAlignment.SpaceEvenly)

    view.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))

    @Expect(first.rect.x, Float32(20.0))
    @Expect(second.rect.x, Float32(60.0))
}

@Test
func zstackPositionsRigidChildByAlignment(): Unit {
    let ctx = testContext()
    let badge = RigidLayoutProbe(Size(20.0, 10.0))
    let banner = RigidLayoutProbe(Size(20.0, 10.0))
    let corner = ZStack {
        emit(badge)
    }.alignment(Alignment.BottomTrailing)
    let center = ZStack {
        emit(banner)
    }

    corner.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    center.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))

    @Expect(badge.rect.x, Float32(80.0))
    @Expect(badge.rect.y, Float32(40.0))
    @Expect(banner.rect.x, Float32(40.0))
    @Expect(banner.rect.y, Float32(20.0))
}


@Test
func zstackCentersChainedFixedSizeBox(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(12.0, 12.0))
    let stack = ZStack {
        emit(child)
        child.width(100.0).height(40.0)
    }

    stack.layout(ctx, Rect(0.0, 0.0, 300.0, 200.0))

    // Each size modifier pins its own axis and defers the other to the chain below, so the
    // fixed-size box reports rigid on both axes and centres instead of pinning to an edge.
    @Expect(child.rect.x, Float32(100.0))
    @Expect(child.rect.y, Float32(80.0))
    @Expect(child.rect.w, Float32(100.0))
    @Expect(child.rect.h, Float32(40.0))
}

@Test
func zIndexChangesPaintAndHitOrderWithoutChangingDeclarationTies(): Unit {
    let ctx = testContext()
    let log = ZOrderLog()
    let low = ZOrderProbe("low", log, consumes: true)
    let firstEqual = ZOrderProbe("first-equal", log, consumes: true)
    let secondEqual = ZOrderProbe("second-equal", log, consumes: true)
    let stack = ZStack {
        emit(firstEqual)
        firstEqual.zIndex(4)
        emit(low)
        low.zIndex(-2)
        emit(secondEqual)
        secondEqual.zIndex(4)
    }

    stack.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    stack.draw(ctx)
    @Expect(log.values.toArray(), ["draw-low", "draw-first-equal", "draw-second-equal"])

    log.values.clear()
    @Expect(stack.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)))
    @Expect(log.values.toArray(), ["event-second-equal"])
}
