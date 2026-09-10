package chui.desktop

import chui.core.{Button, ControlSemantics, SemanticActionKind, SemanticActionRequest, SemanticActionSource,
    SemanticRuntime, State, StateStore, Theme, UiContext, VStack, Widget, buildRoot,
    withActiveSemanticRuntime}
import chui.controls.{CalendarDate, DatePicker, TimeOfDay, TimePicker}
import chui.text.{TextArea, TextField}
import sdl.{Key, Rect, Renderer, Size, UiEvent}

private class SemanticRouterWidget <: Widget {
    var activations: Int64 = 0
    var increments: Int64 = 0

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit {}
    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (!ctx.hasFocus("save")) { return false }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) => activations += 1; true
            case UiEvent.KeyDown(Key.Right, _) => increments += 1; true
            case _ => false
        }
    }
    public func focusableId(): ?String { Some("save") }
}

private class SemanticRouterFallbackCounter {
    var calls: Int64 = 0

    func accept(_: SemanticActionRequest): Bool {
        calls += 1
        true
    }
}

@Test
func semanticActionRouterInvokesTheRevisionBoundControlWithoutCoordinates(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.adoptFocusRing(["save"])
    let widget = SemanticRouterWidget()
    let router = DesktopSemanticActionRouter(ctx)
    router.bind(widget)
    let runtime = SemanticRuntime("main", handler: {request => router.dispatch(request)})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics(
        "button", actionOwner: "save",
        typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate,
            SemanticActionKind.Increment]))
    let snapshot = runtime.commitFrame()

    let focused = runtime.dispatch(SemanticActionRequest(
        "main", snapshot.revision, "save", SemanticActionKind.Focus,
        SemanticActionSource.Accessibility))
    let activated = runtime.dispatch(SemanticActionRequest(
        "main", snapshot.revision, "save", SemanticActionKind.Activate,
        SemanticActionSource.Keyboard))
    let incremented = runtime.dispatch(SemanticActionRequest(
        "main", snapshot.revision, "save", SemanticActionKind.Increment,
        SemanticActionSource.Gamepad))

    @Expect(focused.ok)
    @Expect(activated.ok)
    @Expect(incremented.ok)
    @Expect(ctx.hasFocus("save"))
    @Expect(widget.activations, Int64(1))
    @Expect(widget.increments, Int64(1))
}

@Test
func semanticActionRouterFallsBackWithoutForgingAnUnknownFocusTarget(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.adoptFocusRing([])
    let widget = SemanticRouterWidget()
    let fallback = SemanticRouterFallbackCounter()
    let router = DesktopSemanticActionRouter(ctx, fallback: {request => fallback.accept(request)})
    router.bind(widget)

    @Expect(router.dispatch(SemanticActionRequest(
        "main", UInt64(1), "unknown", SemanticActionKind.Activate,
        SemanticActionSource.Accessibility)))
    @Expect(fallback.calls, Int64(1))
    @Expect(!ctx.hasFocus("unknown"))
    @Expect(widget.activations, Int64(0))
}

@Test
func semanticStockActionsDispatchOnlyThroughSupportedControlContracts(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let clicks = State<Int64>(0)
    let text = State<String>("hello")
    let date = State<CalendarDate>(CalendarDate(2026, 8, 30))
    let time = State<TimeOfDay>(TimeOfDay(9, 30))
    let root = buildRoot({=>
        VStack {
            Button("Run", {=> clicks.value += 1}).key("stock.button")
            TextField(text, key: "stock.text")
            TextArea(State<String>("notes"), key: "stock.area")
            DatePicker(date, key: "stock.date")
            TimePicker(time, key: "stock.time")
        }
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 360.0, 220.0))

    let router = DesktopSemanticActionRouter(ctx)
    router.bind(root)
    let runtime = SemanticRuntime("stock", handler: {request => router.dispatch(request)})
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()

    let button = tree.node("stock.button").getOrThrow()
    let field = tree.node("stock.text").getOrThrow()
    let area = tree.node("stock.area").getOrThrow()
    let dateNode = tree.node("stock.date").getOrThrow()
    let timeNode = tree.node("stock.time").getOrThrow()
    @Expect(button.actions.size, 2)
    @Expect(field.actions.size, 1)
    @Expect(area.actions.size, 1)
    @Expect(dateNode.actions.size, 2)
    @Expect(timeNode.actions.size, 2)

    @Expect(runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.button", SemanticActionKind.Activate,
        SemanticActionSource.Accessibility)).ok)
    @Expect(clicks.value, Int64(1))
    @Expect(runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.text", SemanticActionKind.Focus,
        SemanticActionSource.Keyboard)).ok)
    let forgedEdit = runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.text", SemanticActionKind.Activate,
        SemanticActionSource.Keyboard))
    @Expect(!forgedEdit.ok)
    @Expect(forgedEdit.code, "action-not-supported")
    @Expect(runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.area", SemanticActionKind.Focus,
        SemanticActionSource.Keyboard)).ok)
    @Expect(runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.date", SemanticActionKind.Activate,
        SemanticActionSource.Accessibility)).ok)
    @Expect(runtime.dispatch(SemanticActionRequest(
        "stock", tree.revision, "stock.time", SemanticActionKind.Activate,
        SemanticActionSource.Accessibility)).ok)
}
