package chui.core

import sdl.{Rect, Renderer, Size, UiEvent}

private class SemanticActionCounter {
    var count: Int64 = 0

    func handle(_: SemanticActionRequest): Bool {
        count += 1
        true
    }
}

private class PasswordSemanticWidget <: Widget {
    private var frame = Rect.zero()

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }
    public func draw(ctx: UiContext): Unit {
        recordControlSemantics(ctx, frame, "TextField",
            ControlSemantics("password", value: "never-in-probe", actionOwner: "secret"))
    }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func semanticRuntimeCollectsWithoutProbeAndRedactsPassword(): Unit {
    let runtime = SemanticRuntime("main")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, { =>
        recordControlSemantics(Rect(1.0, 2.0, 30.0, 20.0), "TextField",
            ControlSemantics("password", value: "do-not-export", actionOwner: "login.password"))
    })
    let tree = runtime.commitFrame()

    @Expect(tree.revision, UInt64(1))
    @Expect(tree.nodes.size, 1)
    @Expect(tree.nodes[0].id, "login.password")
    @Expect(tree.nodes[0].value, "")
    @Expect(tree.nodes[0].actions.size, 2)
}

@Test
func semanticRuntimeDiffIsWindowAndRevisionBound(): Unit {
    let runtime = SemanticRuntime("settings")
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", label: "Save", actionOwner: "save"))
    let first = runtime.commitFrame()
    runtime.beginFrame()
    runtime.record(Rect(1.0, 0.0, 0.0, 0.0), "Button",
        ControlSemantics("button", label: "Save", actionOwner: "save"))
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", label: "Close", actionOwner: "close"))
    let second = runtime.commitFrame()
    let diff = runtime.diff(first)

    @Expect(second.revision, UInt64(2))
    @Expect(diff.changed, ["save"])
    @Expect(diff.added, ["close"])
    @Expect(diff.removed.isEmpty())
}

@Test
func semanticRuntimeTypedDispatchFailsClosed(): Unit {
    let counter = SemanticActionCounter()
    let runtime = SemanticRuntime("main", handler: {request => counter.handle(request)})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "run"))
    runtime.commitFrame()

    let stale = runtime.dispatch(SemanticActionRequest("main", UInt64(0), "run",
        SemanticActionKind.Activate, SemanticActionSource.Keyboard))
    let wrongWindow = runtime.dispatch(SemanticActionRequest("other", UInt64(1), "run",
        SemanticActionKind.Activate, SemanticActionSource.Keyboard))
    let agent = runtime.dispatch(SemanticActionRequest("main", UInt64(1), "run",
        SemanticActionKind.Activate, SemanticActionSource.Agent))
    let handled = runtime.dispatch(SemanticActionRequest("main", UInt64(1), "run",
        SemanticActionKind.Activate, SemanticActionSource.Accessibility))

    @Expect(stale.code, "stale-revision")
    @Expect(wrongWindow.code, "window-mismatch")
    @Expect(agent.code, "source-not-allowed")
    @Expect(handled.ok)
    @Expect(counter.count, Int64(1))
}

@Test
func semanticRuntimeVoiceAndAgentRequireExplicitOptIn(): Unit {
    let counter = SemanticActionCounter()
    let runtime = SemanticRuntime("main", policy: SemanticInteractionPolicy(voice: true, agent: true),
        handler: {request => counter.handle(request)})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "run"))
    runtime.commitFrame()

    @Expect(runtime.dispatch(SemanticActionRequest("main", UInt64(1), "run",
        SemanticActionKind.Activate, SemanticActionSource.Voice)).ok)
    @Expect(runtime.dispatch(SemanticActionRequest("main", UInt64(1), "run",
        SemanticActionKind.Activate, SemanticActionSource.Agent)).ok)
    @Expect(counter.count, Int64(2))
}

@Test
func semanticRuntimeOwnsActionArraysAcrossInputAndSnapshotBoundaries(): Unit {
    let declared = [SemanticActionKind.Activate]
    let semantics = ControlSemantics(
        "button", actionOwner: "owned", typedActions: declared)
    declared[0] = SemanticActionKind.Dismiss

    let runtime = SemanticRuntime("owned-window")
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", semantics)
    let first = runtime.commitFrame()
    @Expect(semanticActionName(first.nodes[0].actions[0]), "activate")

    first.nodes[0].actions[0] = SemanticActionKind.Dismiss
    first.nodes[0] = SemanticNode(
        "forged", Rect.zero(), "Button", "button",
        actions: [SemanticActionKind.Dismiss])
    let second = runtime.snapshot()
    @Expect(second.nodes[0].id, "owned")
    @Expect(semanticActionName(second.nodes[0].actions[0]), "activate")
}

@Test
func semanticRuntimeLimitsFailClosedBeforeUnboundedObservation(): Unit {
    let runtime = SemanticRuntime("bounded", limits: SemanticRuntimeLimits(
        maxNodes: 1, maxDepth: 1, maxTextBytes: 32))
    runtime.beginFrame()
    runtime.pushParent("p")
    var depthRejected = false
    try { runtime.pushParent("too-deep") } catch (_: IllegalStateException) { depthRejected = true }
    @Expect(depthRejected)
    runtime.record(Rect.zero(), "B", ControlSemantics("button", label: "ok", actionOwner: "one"))
    var nodeRejected = false
    try {
        runtime.record(Rect.zero(), "B", ControlSemantics("button", actionOwner: "two"))
    } catch (_: IllegalStateException) {
        nodeRejected = true
    }
    @Expect(nodeRejected)
    runtime.popParent()
    runtime.cancelFrame()

    let textBounded = SemanticRuntime("text", limits: SemanticRuntimeLimits(maxTextBytes: 8))
    textBounded.beginFrame()
    var textRejected = false
    try {
        textBounded.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "x"))
    } catch (_: IllegalStateException) {
        textRejected = true
    }
    @Expect(textRejected)
    textBounded.cancelFrame()
}

@Test
func passwordControlSemanticsNeverExportValueToProbe(): Unit {
    let report = ComponentProbe("test.password-redaction", width: 100.0, height: 40.0).run("") {
        emit(PasswordSemanticWidget())
    }
    @Expect(report.contains("\"role\":\"password\""))
    @Expect(!report.contains("never-in-probe"))
}

@Test
func semanticOrderFollowsFocusTraversalAcrossZIndexPaintOrder(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=>
        ZStack {
            Keyed("first-scope") {
                Button("First", {=> ()}).key("focus.first")
            }.zIndex(20)
            Keyed("second-scope") {
                Button("Second", {=> ()}).key("focus.second")
            }.zIndex(-20)
        }
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 240.0, 80.0))

    let runtime = SemanticRuntime("z-order")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()
    let first = tree.node("focus.first").getOrThrow()
    let second = tree.node("focus.second").getOrThrow()

    // The second control paints first because its zIndex is lower, while Tab still enters the
    // declaration-first control. Semantic order must describe that actual focus traversal.
    @Expect(first.order < second.order)
    ctx.focusNext()
    @Expect(ctx.hasFocus("focus.first"))
    ctx.focusNext()
    @Expect(ctx.hasFocus("focus.second"))

    // Root and Keyed builders create real group parents rather than a rectangle-derived flat list.
    @Expect(first.parentId != "")
    @Expect(second.parentId != "")
    @Expect(first.parentId != second.parentId)
    @Expect(tree.node(first.parentId).getOrThrow().role, "group")
    @Expect(tree.node(first.parentId).getOrThrow().parentId, "@root")
    @Expect(tree.node(second.parentId).getOrThrow().parentId, "@root")
}

@Test
func semanticCompoundControlSuppressesNestedDecorativeActionNodes(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=>
        Button(onClick: {=> ()}) {
            Button("Nested", {=> ()}).key("nested.unreachable")
        }.key("outer.action").accessibilityLabel("Outer")
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 180.0, 44.0))

    let runtime = SemanticRuntime("nested-slot")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()

    @Expect(tree.node("outer.action").isSome())
    @Expect(tree.node("outer.action").getOrThrow().actions.size, 2)
    @Expect(tree.node("nested.unreachable").isNone())
}

@Test
func semanticDecorativeSurfacePreservesKeyedInteractiveChild(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=>
        Surface {
            Keyed("surface-child") {
                Button("Inside", {=> ()}).key("surface.button")
            }
        }
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 180.0, 44.0))

    let runtime = SemanticRuntime("decorative-surface")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()
    let node = tree.node("surface.button").getOrThrow()

    @Expect(node.actions.size, 2)
    @Expect(tree.node(node.parentId).getOrThrow().role, "group")
}
