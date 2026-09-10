package chui.core

import sdl.{Color, Rect, Renderer, Size, SurfaceStyle, UiEvent}

private class RetainedMeasureCounter {
    var calls: Int64 = 0
}

private class RetainedGenericMeasureLeaf <: Widget {
    private let counter: RetainedMeasureCounter

    init(counter: RetainedMeasureCounter) { this.counter = counter }

    public func measure(_: UiContext, available: Size): Size {
        counter.calls += 1
        available
    }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

private class RetainedStatePaintLeaf <: Widget {
    private let value: State<Int64>

    init(value: State<Int64>) { this.value = value }

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit { let _ = value.value }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

private class UntrustedOffsetMaterial <: MaterialProvider {
    public func resolve(theme: Theme, _: SurfaceState): SurfaceMaterial {
        SurfaceMaterial(
            SurfaceStyle(
                Color.rgb(30, 40, 50),
                shadow: Color.rgba(0, 0, 0, 180),
                shadowOffsetY: 500.0),
            theme.text)
    }
}

private func beginRetainedWidgetNode(
    runtime: RetainedUiRuntime,
    child: Widget
): RetainedWidgetNode {
    runtime.declareNode("node", "@root", 7)
    let _ = runtime.beginPhase("node", RetainedUiPhase.Build, 7)
    runtime.endPhase()
    RetainedWidgetNode("node", retainedProviderAdapter(child), runtime)
}

private func executeRetainedTestPhase(
    runtime: RetainedUiRuntime,
    state: State<Int64>,
    phase: RetainedUiPhase,
    dependencyPhase: RetainedUiPhase,
    inputCode!: Int64 = 1,
    reuse!: Bool = false
): RetainedPhaseDecision {
    let decision = runtime.beginPhase("node", phase, inputCode)
    if (reuse) {
        @Expect(decision.canReuse)
        runtime.endPhase(executed: false)
    } else {
        if (phase == dependencyPhase) { let _ = state.value }
        runtime.endPhase()
    }
    decision
}

private func executeRetainedTestNode(
    runtime: RetainedUiRuntime,
    state: State<Int64>,
    dependencyPhase: RetainedUiPhase,
    proof: RetainedPaintProof,
    isolated!: Bool = false,
    reuseClean!: Bool = false,
    reuseDependency!: Bool = false,
    layoutInput!: Int64 = 1
): Unit {
    runtime.declareNode("node", "@root", 7, layoutIsolated: isolated)
    let phases = [
        RetainedUiPhase.Build,
        RetainedUiPhase.Measure,
        RetainedUiPhase.Layout,
        RetainedUiPhase.Paint,
        RetainedUiPhase.Semantics,
        RetainedUiPhase.HitTest
    ]
    for (phase in phases) {
        let input = if (phase == RetainedUiPhase.Layout) { layoutInput } else { Int64(1) }
        let shouldReuse = reuseClean &&
            (reuseDependency || !retainedTestPhaseInvalidated(dependencyPhase, phase))
        let _ = executeRetainedTestPhase(
            runtime, state, phase, dependencyPhase,
            inputCode: input, reuse: shouldReuse)
        if (phase == RetainedUiPhase.Layout) { runtime.recordPaintProof("node", proof) }
    }
}

private func retainedTestPhaseInvalidated(
    dependency: RetainedUiPhase,
    phase: RetainedUiPhase
): Bool {
    match (dependency) {
        case RetainedUiPhase.Build => true
        case RetainedUiPhase.Measure => phase != RetainedUiPhase.Build
        case RetainedUiPhase.Layout => phase != RetainedUiPhase.Build &&
            phase != RetainedUiPhase.Measure
        case RetainedUiPhase.Paint => phase == RetainedUiPhase.Paint
        case RetainedUiPhase.Semantics => phase == RetainedUiPhase.Semantics
        case RetainedUiPhase.HitTest => phase == RetainedUiPhase.HitTest
    }
}

@Test
func retainedUiTracksPaintStateAndEmitsOnlyProvenBoundedDamage(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(
        Rect(10.0, 20.0, 30.0, 40.0),
        clip: Some(Rect(0.0, 0.0, 100.0, 100.0)),
        effectRadius: 2.0,
        ancestorContextCode: 9,
        proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Full)
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Paint), UInt64(1))

    state.value = 2
    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Paint, proof, reuseClean: true)
    let damage = runtime.finishFrame()
    @Expect(damage.kind == RetainedUiDamageKind.Bounded)
    @Expect(damage.rectangleCount(), 1)
    @Expect(damage.rectangleAt(0).x, 8.0)
    @Expect(damage.rectangleAt(0).y, 18.0)
    @Expect(damage.rectangleAt(0).w, 34.0)
    @Expect(damage.rectangleAt(0).h, 44.0)
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Build), UInt64(1))
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Paint), UInt64(2))
}

@Test
func retainedUiPromotesUnisolatedLayoutDependencyToFullRootDamage(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(Rect(5.0, 5.0, 20.0, 20.0), proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Layout, proof)
    let _ = runtime.finishFrame()
    state.value = 2

    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Layout, proof, reuseClean: true)
    let damage = runtime.finishFrame()
    @Expect(damage.kind == RetainedUiDamageKind.Full)
    @Expect(damage.reason.contains("layout-unisolated"))
}

@Test
func retainedUiUnionsOldAndNewGeometryOnlyForAnIsolatedCompatibleProof(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let oldProof = RetainedPaintProof(
        Rect(5.0, 5.0, 20.0, 20.0), transformCode: 3,
        ancestorContextCode: 7, proven: true)
    let newProof = RetainedPaintProof(
        Rect(35.0, 5.0, 20.0, 20.0), transformCode: 3,
        ancestorContextCode: 7, proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Layout, oldProof, isolated: true)
    let _ = runtime.finishFrame()
    state.value = 2

    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Layout, newProof,
        isolated: true, reuseClean: true, layoutInput: 2)
    let damage = runtime.finishFrame()
    @Expect(damage.kind == RetainedUiDamageKind.Bounded)
    @Expect(damage.rectangleCount(), 2)
    @Expect(damage.rectangleAt(0).x, 5.0)
    @Expect(damage.rectangleAt(1).x, 35.0)
}

@Test
func retainedUiKeepsReusedStateDependenciesLiveAndFailsClosedOnUnknownPaint(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(Rect(0.0, 0.0, 10.0, 10.0), proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    let _ = runtime.finishFrame()

    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Paint, proof,
        reuseClean: true, reuseDependency: true)
    let clean = runtime.finishFrame()
    @Expect(clean.kind == RetainedUiDamageKind.Empty)

    // Paint was reused and not read again, but its State dependency must still invalidate it.
    state.value = 2
    runtime.beginFrame(1)
    executeRetainedTestNode(
        runtime, state, RetainedUiPhase.Paint,
        RetainedPaintProof(Rect(0.0, 0.0, 10.0, 10.0), proven: false),
        reuseClean: true)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Full)
}

@Test
func retainedUiCancelledFrameCannotCommitAReuseOrHideLaterDamage(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(Rect(1.0, 1.0, 10.0, 10.0), proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    let _ = runtime.finishFrame()

    runtime.beginFrame(1)
    runtime.declareNode("node", "@root", 7)
    let _ = runtime.beginPhase("node", RetainedUiPhase.Paint, 1)
    let _ = state.value
    runtime.endPhase()
    runtime.cancelFrame()

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    let damage = runtime.finishFrame()
    @Expect(damage.kind == RetainedUiDamageKind.Full)
    @Expect(damage.reason, "frame-cancelled")
}

@Test
func retainedUiReportsRemovedCommittedNodeBeforeFrameFinish(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(Rect(4.0, 6.0, 20.0, 12.0), proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    let _ = runtime.finishFrame()

    // The previously committed node is omitted from this frame. Desktop consumes damage before
    // finishFrame, so that pre-finish observation itself must already fail closed to Full.
    runtime.beginFrame(1)
    let beforeFinish = runtime.damage()
    @Expect(beforeFinish.kind == RetainedUiDamageKind.Full)
    @Expect(beforeFinish.reason, "node-removed")

    let committed = runtime.finishFrame()
    @Expect(committed.kind == RetainedUiDamageKind.Full)
    @Expect(committed.reason, "node-removed")
}

@Test
func retainedUiActuallyReusesAFrameworkProvenLabelMeasureOutput(): Unit {
    let runtime = RetainedUiRuntime()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let available = Size(180.0, 60.0)
    let frame = Rect(0.0, 0.0, 180.0, 60.0)

    runtime.beginFrame(1)
    let first = beginRetainedWidgetNode(runtime, Label("stable"))
    let firstSize = first.measure(ctx, available)
    first.layout(ctx, frame)
    first.draw(ctx)
    let _ = runtime.finishFrame()
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(1))
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Semantics), UInt64(1))

    runtime.beginFrame(1)
    let second = beginRetainedWidgetNode(runtime, Label("stable"))
    let secondSize = second.measure(ctx, available)
    second.layout(ctx, frame)
    second.draw(ctx)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Empty)
    @Expect(secondSize.w, firstSize.w)
    @Expect(secondSize.h, firstSize.h)
    // A reuse hit does not advance Measure, while production draw advances Semantics.
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(1))
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Semantics), UInt64(2))

    runtime.beginFrame(1)
    let changed = beginRetainedWidgetNode(runtime, Label("different measurement input"))
    let _ = changed.measure(ctx, available)
    changed.layout(ctx, frame)
    changed.draw(ctx)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Full)
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(2))
}

@Test
func retainedUiNeverSkipsAnUnprovenGenericWidgetMeasure(): Unit {
    let runtime = RetainedUiRuntime()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let counter = RetainedMeasureCounter()
    let available = Size(80.0, 40.0)

    runtime.beginFrame(1)
    let first = beginRetainedWidgetNode(runtime, RetainedGenericMeasureLeaf(counter))
    let _ = first.measure(ctx, available)
    let _ = runtime.finishFrame()

    runtime.beginFrame(1)
    let second = beginRetainedWidgetNode(runtime, RetainedGenericMeasureLeaf(counter))
    let _ = second.measure(ctx, available)
    let _ = runtime.finishFrame()

    @Expect(counter.calls, Int64(2))
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(2))
}

@Test
func retainedUiCommitsAChangedExactOutputInsteadOfInvalidatingMeasureForever(): Unit {
    let runtime = RetainedUiRuntime()
    let available = Size(80.0, 40.0)

    runtime.beginFrame(1)
    runtime.declareNode("node", "@root", 7)
    runtime.prepareMeasureInput("node", available, Some("exact-input"))
    let first = runtime.beginPhase("node", RetainedUiPhase.Measure, 1)
    @Expect(!first.canReuse)
    runtime.recordMeasureOutput("node", available, Some("exact-input"), Size(20.0, 10.0))
    runtime.endPhase()
    let _ = runtime.finishFrame()

    // A provider may be explicitly invalidated by a non-State runtime fact while its declared
    // exact input identity remains stable. If the result changes, the current frame is Full, but
    // the new exact tuple must still commit so the node can settle on the following frame.
    runtime.invalidate("node", RetainedUiPhase.Measure, reason: "provider-invalidated")
    runtime.beginFrame(1)
    runtime.declareNode("node", "@root", 7)
    runtime.prepareMeasureInput("node", available, Some("exact-input"))
    let changed = runtime.beginPhase("node", RetainedUiPhase.Measure, 1)
    @Expect(!changed.canReuse)
    runtime.recordMeasureOutput("node", available, Some("exact-input"), Size(24.0, 12.0))
    runtime.endPhase()
    let changedDamage = runtime.finishFrame()
    @Expect(changedDamage.kind == RetainedUiDamageKind.Full)
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(2))

    runtime.beginFrame(1)
    runtime.declareNode("node", "@root", 7)
    runtime.prepareMeasureInput("node", available, Some("exact-input"))
    let settled = runtime.beginPhase("node", RetainedUiPhase.Measure, 1)
    @Expect(settled.canReuse)
    runtime.endPhase(executed: false)
    let cached = runtime.measureOutput("node", available, "exact-input").getOrThrow()
    @Expect(cached.w, 24.0)
    @Expect(cached.h, 12.0)
    let _ = runtime.finishFrame()
    @Expect(runtime.phaseGeneration("node", RetainedUiPhase.Measure), UInt64(2))
}

@Test
func retainedUiClearUnregistersEveryStateDependency(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let proof = RetainedPaintProof(Rect(0.0, 0.0, 10.0, 10.0), proven: true)

    runtime.beginFrame(1)
    executeRetainedTestNode(runtime, state, RetainedUiPhase.Paint, proof)
    let _ = runtime.finishFrame()

    // Window shutdown calls StateStore.clear(), which in turn clears this runtime. Once the
    // clearing frame settles, mutating an old State must not wake the abandoned window runtime.
    runtime.clear()
    runtime.beginFrame(1)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Full)
    state.value = 2
    runtime.beginFrame(1)
    let afterDetachedWrite = runtime.finishFrame()
    @Expect(afterDetachedWrite.kind == RetainedUiDamageKind.Empty)
}

@Test
func clippedSurfacePaintStateProducesBoundedDamageAndUnclippedStaysFull(): Unit {
    let state = State<Int64>(1)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let available = Size(30.0, 40.0)
    let frame = Rect(10.0, 20.0, 30.0, 40.0)

    let boundedRuntime = RetainedUiRuntime()
    boundedRuntime.beginFrame(1)
    let firstSurface = Surface(clip: ClipPolicy.Shape) {=> emit(RetainedStatePaintLeaf(state)) }
    let first = beginRetainedWidgetNode(boundedRuntime, firstSurface)
    let _ = first.measure(ctx, available)
    first.layout(ctx, frame)
    first.draw(ctx)
    let _ = boundedRuntime.finishFrame()

    state.value = 2
    boundedRuntime.beginFrame(1)
    let secondSurface = Surface(clip: ClipPolicy.Shape) {=> emit(RetainedStatePaintLeaf(state)) }
    let second = beginRetainedWidgetNode(boundedRuntime, secondSurface)
    let _ = second.measure(ctx, available)
    second.layout(ctx, frame)
    second.draw(ctx)
    let bounded = boundedRuntime.finishFrame()
    @Expect(bounded.kind == RetainedUiDamageKind.Bounded)
    @Expect(bounded.rectangleCount(), Int64(1))
    // The built-in theme surface carries a 2 px shadow offset. Its conservative proof expands
    // symmetrically by the base clearance plus the real displacement.
    @Expect(bounded.rectangleAt(0).x, -8.0)
    @Expect(bounded.rectangleAt(0).y, 2.0)
    @Expect(bounded.rectangleAt(0).w, 66.0)
    @Expect(bounded.rectangleAt(0).h, 76.0)

    let unknownState = State<Int64>(1)
    let unknownRuntime = RetainedUiRuntime()
    unknownRuntime.beginFrame(1)
    let unknownFirstSurface = Surface(clip: ClipPolicy.Unclipped) {
        => emit(RetainedStatePaintLeaf(unknownState))
    }
    let unknownFirst = beginRetainedWidgetNode(unknownRuntime, unknownFirstSurface)
    let _ = unknownFirst.measure(ctx, available)
    unknownFirst.layout(ctx, frame)
    unknownFirst.draw(ctx)
    let _ = unknownRuntime.finishFrame()

    unknownState.value = 2
    unknownRuntime.beginFrame(1)
    let unknownSecondSurface = Surface(clip: ClipPolicy.Unclipped) {
        => emit(RetainedStatePaintLeaf(unknownState))
    }
    let unknownSecond = beginRetainedWidgetNode(unknownRuntime, unknownSecondSurface)
    let _ = unknownSecond.measure(ctx, available)
    unknownSecond.layout(ctx, frame)
    unknownSecond.draw(ctx)
    @Expect(unknownRuntime.finishFrame().kind == RetainedUiDamageKind.Full)
}

@Test
func surfaceRetainedProofAccountsForOffsetAndRejectsUnknownMaterialProvider(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(10.0, 20.0, 30.0, 40.0)
    let trusted = Surface(
        material: Materials.solid(SurfaceStyle(
            Color.rgb(20, 30, 40),
            shadow: Color.rgba(0, 0, 0, 180),
            shadowOffsetY: 100.0)),
        clip: ClipPolicy.Shape
    ) {=> Spacer()}
    let trustedProof = trusted.retainedPaintProof(ctx, frame).getOrThrow()
    @Expect(trustedProof.effectRadius, Float32(116.0))

    // The same pixels behind an arbitrary provider are not a proof: the provider may change its
    // extent without a State dependency or stable identity between layout and paint.
    let unknown = Surface(
        material: UntrustedOffsetMaterial(),
        clip: ClipPolicy.Shape
    ) {=> Spacer()}
    @Expect(unknown.retainedPaintProof(ctx, frame).isNone())
}

@Test
func surfaceMutationBetweenLayoutAndPaintRevokesEarlierBoundedProof(): Unit {
    let runtime = RetainedUiRuntime()
    let state = State<Int64>(1)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let available = Size(30.0, 40.0)
    let frame = Rect(10.0, 20.0, 30.0, 40.0)

    runtime.beginFrame(1)
    let firstSurface = Surface(clip: ClipPolicy.Shape) {=> emit(RetainedStatePaintLeaf(state)) }
    let first = beginRetainedWidgetNode(runtime, firstSurface)
    let _ = first.measure(ctx, available)
    first.layout(ctx, frame)
    first.draw(ctx)
    let _ = runtime.finishFrame()

    state.value = 2
    runtime.beginFrame(1)
    let changedSurface = Surface(clip: ClipPolicy.Shape) {=> emit(RetainedStatePaintLeaf(state)) }
    let changed = beginRetainedWidgetNode(runtime, changedSurface)
    let _ = changed.measure(ctx, available)
    changed.layout(ctx, frame)
    changedSurface.material(UntrustedOffsetMaterial())
    changed.draw(ctx)
    @Expect(runtime.finishFrame().kind == RetainedUiDamageKind.Full)
}
