package chui.core

import sdl.{FrameInfo, Key, Rect, Size, UiEvent}

private class EventHandlerProbe <: Widget {
    private let trace: State<String>
    private let label: String
    private let consumes: Bool

    init(trace: State<String>, label: String, consumes: Bool) {
        this.trace = trace
        this.label = label
        this.consumes = consumes
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        trace.value = trace.value + label
        consumes
    }
}

@Test
func eventHandlerFrameAlwaysReachesHookAndChildWithoutConsumption(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let handler = EventHandler(onEvent: {
        _ =>
        trace.value = trace.value + "hook"
        true
    }) {
        EventHandlerProbe(trace, "child", true)
    }

    let consumed = handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(20), UInt64(5))))

    @Expect(!consumed)
    @Expect(trace.value, "hookchild")
}

@Test
func eventHandlerOrdinaryConsumptionStopsBeforeChild(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let handler = EventHandler(onEvent: {
        _ =>
        trace.value = trace.value + "hook"
        true
    }) {
        EventHandlerProbe(trace, "child", true)
    }

    let consumed = handler.handle(ctx, UiEvent.KeyDown(Key.Enter, false))

    @Expect(consumed)
    @Expect(trace.value, "hook")
}

@Test
func eventHandlerOrdinaryDeclineFallsThroughToChild(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let handler = EventHandler(onEvent: {
        _ =>
        trace.value = trace.value + "hook"
        false
    }) {
        EventHandlerProbe(trace, "child", true)
    }

    let consumed = handler.handle(ctx, UiEvent.KeyDown(Key.Enter, false))

    @Expect(consumed)
    @Expect(trace.value, "hookchild")
}

@Test
func frameHandlerRequestsEveryFrameAndCannotBeConsumedByChild(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let handler = FrameHandler(onFrame: {
        _ => trace.value = trace.value + "hook"
    }) {
        EventHandlerProbe(trace, "child", true)
    }

    let _ = ctx.takeFrameRequest()
    let firstConsumed = handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(20), UInt64(5))))
    @Expect(!firstConsumed)
    @Expect(ctx.takeFrameRequest())

    let secondConsumed = handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(40), UInt64(20))))
    @Expect(!secondConsumed)
    @Expect(ctx.takeFrameRequest())
    @Expect(trace.value, "hookchildhookchild")
}

@Test
func frameHandlerMayStopAfterBoundedFrameWorkCompletes(): Unit {
    let ctx = testContext()
    let active = State<Bool>(true)
    let trace = State<String>("")
    let handler = FrameHandler(onFrame: {
        _ =>
        trace.value = trace.value + "hook"
        active.value = false
    }, keepsAlive: {=> active.value}) {
        EventHandlerProbe(trace, "child", true)
    }

    let _ = ctx.takeFrameRequest()
    let consumed = handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(20), UInt64(5))))

    @Expect(!consumed)
    @Expect(!ctx.takeFrameRequest())
    @Expect(trace.value, "hookchild")
}

@Test
func frameHandlerOrdinaryEventsBypassHookAndReturnChildConsumption(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let handler = FrameHandler(onFrame: {
        _ => trace.value = trace.value + "hook"
    }) {
        EventHandlerProbe(trace, "child", true)
    }

    let consumed = handler.handle(ctx, UiEvent.KeyDown(Key.Enter, false))

    @Expect(consumed)
    @Expect(trace.value, "child")
}
