package chui.graphics

private func frameTestCapabilities(
    bounded!: Bool = true,
    partial!: Bool = false,
    shared!: Bool = false,
    extended!: Bool = false
): FrameGraphExecutorCapabilities {
    FrameGraphExecutorCapabilities(
        supportsBoundedRedraw: bounded,
        supportsPartialPresent: partial,
        supportsSharedTexture: shared,
        supportsExtendedDynamicRange: extended)
}

private func requireCompiledFrame(result: FrameCompileResult): CompiledFrameGraph {
    @Expect(result.ok)
    match (result.graph()) {
        case Some(value) => value
        case None => throw IllegalStateException("expected compiled frame graph")
    }
}

private func compiledFramePass(graph: CompiledFrameGraph, id: String): CompiledFramePass {
    for (i in 0..graph.scheduledPassCount()) {
        let value = graph.scheduledPassAt(i)
        if (value.descriptor.id.key == id) { return value }
    }
    throw IllegalStateException("compiled pass not found")
}

private func deterministicFrameGraph(
    frameId!: Int64 = 1,
    damage!: DamageRegion = DamageRegion.full(),
    limits!: FrameGraphLimits = FrameGraphLimits()
): FrameGraph {
    let source = FrameResourceDescriptor(
        FrameResourceId("surface.main.input", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let output = FrameResourceDescriptor(
        FrameResourceId("surface.main.output", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let ui = FramePassDescriptor(
        FramePassId("ui.main"), 0, FramePassKind.Ui2D,
        reads: [source.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 100, 80)),
        stableInputCode: 11, canCull: true)
    let present = FramePassDescriptor(
        FramePassId("present.main"), 1, FramePassKind.Present,
        reads: [output.id], dependsOn: [ui.id], stableInputCode: 21)
    FrameGraph("main", 1, frameId, 100, 80, [source, output], [ui, present],
        frameDamage: damage, limits: limits)
}

@Test
func frameGraphCompilerIsDeterministicAndUsesStableTopologicalOrder(): Unit {
    let first = requireCompiledFrame(compileFrameGraph(
        deterministicFrameGraph(), FrameGraphCompilerState(), frameTestCapabilities()))
    let second = requireCompiledFrame(compileFrameGraph(
        deterministicFrameGraph(), FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(first.scheduleHash, second.scheduleHash)
    @Expect(first.trace, second.trace)
    @Expect(first.scheduledPassAt(0).descriptor.id.key, "ui.main")
    @Expect(first.scheduledPassAt(1).descriptor.id.key, "present.main")
    @Expect(first.presentMode == FramePresentMode.Full)
    @Expect(first.presentStrategy == FramePresentStrategy.FullSurface)
    @Expect(!first.scheduleCacheHit)
    @Expect(first.trace.contains("\"protocol\":\"canghui.frame-graph.v0\""))
    @Expect(first.trace.contains("\"externalMode\":\"none\",\"unifiedPixels\":false"))
    @Expect(first.trace.contains("\"reads\":[\"surface.main.input@1\"]"))
    @Expect(first.trace.contains("\"writes\":[\"surface.main.output@1\"]"))
    @Expect(first.trace.contains("\"dependsOn\":[\"ui.main\"]"))
    @Expect(!first.trace.contains("/Users/"))

    let a = FrameResourceDescriptor(
        FrameResourceId("target.a", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let b = FrameResourceDescriptor(
        FrameResourceId("target.b", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let c = FrameResourceDescriptor(
        FrameResourceId("target.c", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let late = FramePassDescriptor(
        FramePassId("pass.late"), 0, FramePassKind.OffscreenComposition,
        writes: [a.id], dependsOn: [FramePassId("pass.source")])
    let independent = FramePassDescriptor(
        FramePassId("pass.independent"), 1, FramePassKind.OffscreenComposition,
        writes: [b.id])
    let source = FramePassDescriptor(
        FramePassId("pass.source"), 2, FramePassKind.OffscreenComposition,
        writes: [c.id])
    let reordered = requireCompiledFrame(compileFrameGraph(
        FrameGraph("order", 1, 1, 32, 32, [a, b, c], [late, independent, source]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(reordered.scheduledPassAt(0).descriptor.id.key, "pass.independent")
    @Expect(reordered.scheduledPassAt(1).descriptor.id.key, "pass.source")
    @Expect(reordered.scheduledPassAt(2).descriptor.id.key, "pass.late")
}

@Test
func frameGraphCompilerRejectsResourceAndDependencyFaultsBeforeExecution(): Unit {
    let output = FrameResourceDescriptor(
        FrameResourceId("output.main", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let unknown = FramePassDescriptor(
        FramePassId("unknown.read"), 0, FramePassKind.OffscreenComposition,
        reads: [FrameResourceId("missing.input", 1)], writes: [output.id])
    let unknownResult = compileFrameGraph(
        FrameGraph("unknown", 1, 1, 32, 32, [output], [unknown]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!unknownResult.ok)
    @Expect(unknownResult.code, "unknown-resource")

    let pending = FrameResourceDescriptor(
        FrameResourceId("pending.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let useBefore = FramePassDescriptor(
        FramePassId("pending.read"), 0, FramePassKind.OffscreenComposition,
        reads: [pending.id], writes: [output.id])
    let useBeforeResult = compileFrameGraph(
        FrameGraph("pending", 1, 1, 32, 32, [pending, output], [useBefore]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!useBeforeResult.ok)
    @Expect(useBeforeResult.code, "use-before-create")

    let firstWriter = FramePassDescriptor(
        FramePassId("writer.first"), 0, FramePassKind.OffscreenComposition,
        writes: [output.id])
    let secondWriter = FramePassDescriptor(
        FramePassId("writer.second"), 1, FramePassKind.OffscreenComposition,
        writes: [output.id])
    let doubleResult = compileFrameGraph(
        FrameGraph("double", 1, 1, 32, 32, [output], [firstWriter, secondWriter]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!doubleResult.ok)
    @Expect(doubleResult.code, "double-producer")

    let resourceA = FrameResourceDescriptor(
        FrameResourceId("cycle.a", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Transient)
    let resourceB = FrameResourceDescriptor(
        FrameResourceId("cycle.b", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Transient)
    let passA = FramePassDescriptor(
        FramePassId("cycle.a"), 0, FramePassKind.OffscreenComposition,
        reads: [resourceB.id], writes: [resourceA.id])
    let passB = FramePassDescriptor(
        FramePassId("cycle.b"), 1, FramePassKind.OffscreenComposition,
        reads: [resourceA.id], writes: [resourceB.id])
    let cycleResult = compileFrameGraph(
        FrameGraph("cycle", 1, 1, 32, 32, [resourceA, resourceB], [passA, passB]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!cycleResult.ok)
    @Expect(cycleResult.code, "dependency-cycle")
}

@Test
func frameGraphCompilerRequiresAtMostOneTerminalPresentPass(): Unit {
    let first = FrameResourceDescriptor(
        FrameResourceId("present.first", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let second = FrameResourceDescriptor(
        FrameResourceId("present.second", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let draw = FramePassDescriptor(
        FramePassId("draw"), 0, FramePassKind.Ui2D, writes: [first.id])
    let present = FramePassDescriptor(
        FramePassId("present"), 1, FramePassKind.Present, reads: [first.id])
    let late = FramePassDescriptor(
        FramePassId("late"), 2, FramePassKind.OffscreenComposition,
        reads: [first.id], writes: [second.id])
    let nonTerminal = compileFrameGraph(
        FrameGraph("present-order", 1, 1, 32, 32, [first, second], [draw, present, late]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!nonTerminal.ok)
    @Expect(nonTerminal.code, "present-not-terminal")

    let duplicate = FramePassDescriptor(
        FramePassId("present.second"), 2, FramePassKind.Present, reads: [first.id])
    let multiple = compileFrameGraph(
        FrameGraph("present-count", 1, 1, 32, 32, [first], [draw, present, duplicate]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!multiple.ok)
    @Expect(multiple.code, "multiple-present-passes")
}

@Test
func frameGraphCompilerRejectsStaleUnsupportedInvalidAndOverCapInputs(): Unit {
    let staleState = FrameGraphCompilerState(
        "main", 1, 1, [FrameResourceDescriptor(
            FrameResourceId("surface.main", 2), FrameResourceKind.Surface,
            FrameResourceLifetime.Imported)], [], [], [])
    let staleResource = FrameResourceDescriptor(
        FrameResourceId("surface.main", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let stale = compileFrameGraph(
        FrameGraph("main", 1, 2, 32, 32, [staleResource], []),
        staleState, frameTestCapabilities())
    @Expect(!stale.ok)
    @Expect(stale.code, "stale-resource-generation")

    let external = FrameResourceDescriptor(
        FrameResourceId("scene.external", 1), FrameResourceKind.ExternalSurface,
        FrameResourceLifetime.Imported)
    let shared = FramePassDescriptor(
        FramePassId("scene.shared"), 0, FramePassKind.ExternalScene3D,
        reads: [external.id], externalMode: FrameExternalMode.SharedTexture)
    let unsupportedShared = compileFrameGraph(
        FrameGraph("shared", 1, 1, 32, 32, [external], [shared]),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!unsupportedShared.ok)
    @Expect(unsupportedShared.code, "unsupported-shared-texture")

    let supportedShared = requireCompiledFrame(compileFrameGraph(
        FrameGraph("shared", 1, 1, 32, 32, [external], [shared]),
        FrameGraphCompilerState(), frameTestCapabilities(shared: true)))
    @Expect(supportedShared.trace.contains(
        "\"externalMode\":\"shared-texture\",\"unifiedPixels\":true"))

    let nativeBarrier = FramePassDescriptor(
        FramePassId("scene.native"), 0, FramePassKind.ExternalScene3D,
        reads: [external.id], externalMode: FrameExternalMode.NativeChildSurfaceBarrier)
    let nativeCompiled = requireCompiledFrame(compileFrameGraph(
        FrameGraph("native", 1, 1, 32, 32, [external], [nativeBarrier]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(nativeCompiled.trace.contains(
        "\"externalMode\":\"native-child-surface-barrier\",\"unifiedPixels\":false"))

    let extended = FrameResourceDescriptor(
        FrameResourceId("surface.extended", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported, dynamicRange: FrameDynamicRange.ReservedExtended)
    let unsupportedRange = compileFrameGraph(
        FrameGraph("range", 1, 1, 32, 32, [extended], []),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!unsupportedRange.ok)
    @Expect(unsupportedRange.code, "unsupported-dynamic-range")

    let outside = FrameDamageRect(30, 30, 4, 4)
    let invalidRegion = compileFrameGraph(
        FrameGraph("region", 1, 1, 32, 32, [external], [],
            frameDamage: DamageRegion.bounded([outside])),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!invalidRegion.ok)
    @Expect(invalidRegion.code, "invalid-frame-damage")

    let overCount = compileFrameGraph(
        FrameGraph("cap", 1, 1, 32, 32, [external], [],
            limits: FrameGraphLimits(maxResources: 1, maxPasses: 1)),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(overCount.ok)
    let secondExternal = FrameResourceDescriptor(
        FrameResourceId("scene.external.second", 1), FrameResourceKind.ExternalSurface,
        FrameResourceLifetime.Imported)
    let overResourceCount = compileFrameGraph(
        FrameGraph("cap", 1, 1, 32, 32, [external, secondExternal], [],
            limits: FrameGraphLimits(maxResources: 1, maxPasses: 1)),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!overResourceCount.ok)
    @Expect(overResourceCount.code, "resource-count-over-cap")

    let traceOverCap = compileFrameGraph(
        deterministicFrameGraph(limits: FrameGraphLimits(maxTraceBytes: 32)),
        FrameGraphCompilerState(), frameTestCapabilities())
    @Expect(!traceOverCap.ok)
    @Expect(traceOverCap.code, "trace-over-cap")
}

private func twoRegionFrameGraph(frameId: Int64, damage: DamageRegion): FrameGraph {
    let leftInput = FrameResourceDescriptor(
        FrameResourceId("left.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported)
    let leftOutput = FrameResourceDescriptor(
        FrameResourceId("left.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let rightInput = FrameResourceDescriptor(
        FrameResourceId("right.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported)
    let rightOutput = FrameResourceDescriptor(
        FrameResourceId("right.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let left = FramePassDescriptor(
        FramePassId("ui.left"), 0, FramePassKind.Ui2D,
        reads: [leftInput.id], writes: [leftOutput.id],
        bounds: Some(FrameDamageRect(0, 0, 50, 50)),
        stableInputCode: 10, canCull: true)
    let right = FramePassDescriptor(
        FramePassId("ui.right"), 1, FramePassKind.Ui2D,
        reads: [rightInput.id], writes: [rightOutput.id],
        bounds: Some(FrameDamageRect(50, 0, 50, 50)),
        stableInputCode: 20, canCull: true)
    FrameGraph("regions", 1, frameId, 100, 50,
        [leftInput, leftOutput, rightInput, rightOutput], [left, right], frameDamage: damage)
}

@Test
func frameGraphCompilerCullsOnlyProvenUnchangedSiblingAndReportsBoundedRedraw(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    @Expect(runtime.execute(twoRegionFrameGraph(1, DamageRegion.full()), executor).ok)

    let next = requireCompiledFrame(compileFrameGraph(
        twoRegionFrameGraph(2, DamageRegion.bounded([FrameDamageRect(5, 5, 4, 4)])),
        runtime.state(), executor.capabilities()))
    @Expect(!compiledFramePass(next, "ui.left").culled)
    @Expect(compiledFramePass(next, "ui.left").damage.kind == FrameDamageKind.Bounded)
    @Expect(compiledFramePass(next, "ui.right").culled)
    @Expect(next.executedPassCount, 1)
    @Expect(next.culledPassCount, 1)
    @Expect(next.redrawMode == FrameRedrawMode.Bounded)
    @Expect(next.presentMode == FramePresentMode.NotPresented)
}

private func outputLifetimeFrameGraph(
    frameId: Int64,
    outputLifetime: FrameResourceLifetime,
    inputBytes!: Int64 = 0
): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("lifetime.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported, declaredBytes: inputBytes)
    let output = FrameResourceDescriptor(
        FrameResourceId("lifetime.output", 1), FrameResourceKind.Texture,
        outputLifetime)
    let pass = FramePassDescriptor(
        FramePassId("lifetime.pass"), 0, FramePassKind.OffscreenComposition,
        reads: [input.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 20, 20)),
        stableInputCode: 101, canCull: true)
    FrameGraph("lifetime", 1, frameId, 20, 20, [input, output], [pass],
        frameDamage: DamageRegion.empty())
}

@Test
func frameGraphCompilerDoesNotCullImportedOrUncommittedOutputs(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    @Expect(runtime.execute(
        outputLifetimeFrameGraph(1, FrameResourceLifetime.Persistent), executor).ok)

    let importedRuntime = FrameGraphRuntime()
    @Expect(importedRuntime.execute(
        outputLifetimeFrameGraph(1, FrameResourceLifetime.Imported), executor).ok)
    let imported = requireCompiledFrame(compileFrameGraph(
        outputLifetimeFrameGraph(2, FrameResourceLifetime.Imported),
        importedRuntime.state(), executor.capabilities()))
    @Expect(!compiledFramePass(imported, "lifetime.pass").culled)
    @Expect(compiledFramePass(imported, "lifetime.pass").damage.kind == FrameDamageKind.Bounded)

    let descriptorChanged = compileFrameGraph(
        outputLifetimeFrameGraph(2, FrameResourceLifetime.Persistent, inputBytes: 1),
        runtime.state(), executor.capabilities())
    @Expect(!descriptorChanged.ok)
    @Expect(descriptorChanged.code, "resource-descriptor-drift")

    let first = requireCompiledFrame(compileFrameGraph(
        outputLifetimeFrameGraph(1, FrameResourceLifetime.Persistent),
        FrameGraphCompilerState(), executor.capabilities()))
    let missingOutputState = FrameGraphCompilerState(
        "lifetime", 1, 1, [FrameResourceDescriptor(
            FrameResourceId("lifetime.input", 1), FrameResourceKind.Texture,
            FrameResourceLifetime.Imported)],
        [FramePassId("lifetime.pass")], [101],
        [compiledFramePass(first, "lifetime.pass").outputFingerprint])
    let missingOutput = requireCompiledFrame(compileFrameGraph(
        outputLifetimeFrameGraph(2, FrameResourceLifetime.Persistent),
        missingOutputState, executor.capabilities()))
    @Expect(!compiledFramePass(missingOutput, "lifetime.pass").culled)
}

private func collidingOutputFingerprintGraph(frameId: Int64, mergeKey: String): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("ui.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported)
    let output = FrameResourceDescriptor(
        FrameResourceId("ui.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let pass = FramePassDescriptor(
        FramePassId("ui.main"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 20, 20)),
        stableInputCode: 808, canCull: true, mergeKey: mergeKey)
    FrameGraph("fingerprint", 1, frameId, 20, 20, [input, output], [pass],
        frameDamage: DamageRegion.empty())
}

@Test
func frameGraphCullingUsesExactFingerprintEvenWhenDisplayCodesCollide(): Unit {
    let executor = NullFrameGraphExecutor()
    let az = requireCompiledFrame(compileFrameGraph(
        collidingOutputFingerprintGraph(1, "az"),
        FrameGraphCompilerState(), executor.capabilities()))
    let si = requireCompiledFrame(compileFrameGraph(
        collidingOutputFingerprintGraph(1, "si"),
        FrameGraphCompilerState(), executor.capabilities()))
    let azPass = compiledFramePass(az, "ui.main")
    let siPass = compiledFramePass(si, "ui.main")
    // The small numeric trace code intentionally remains non-authoritative and is easy to collide.
    @Expect(azPass.outputCode, siPass.outputCode)
    @Expect(azPass.outputFingerprint != siPass.outputFingerprint)

    let runtime = FrameGraphRuntime()
    @Expect(runtime.execute(collidingOutputFingerprintGraph(1, "az"), executor).ok)
    let changed = requireCompiledFrame(compileFrameGraph(
        collidingOutputFingerprintGraph(2, "si"), runtime.state(), executor.capabilities()))
    @Expect(!compiledFramePass(changed, "ui.main").culled)
}

private func effectFrameGraph(frameId: Int64, uiDamage: DamageRegion): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("effect.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported)
    let middle = FrameResourceDescriptor(
        FrameResourceId("effect.middle", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let output = FrameResourceDescriptor(
        FrameResourceId("effect.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let ui = FramePassDescriptor(
        FramePassId("effect.ui"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [middle.id],
        bounds: Some(FrameDamageRect(0, 0, 100, 100)), declaredDamage: uiDamage,
        stableInputCode: 31, canCull: true)
    let effect = FramePassDescriptor(
        FramePassId("effect.blur"), 1, FramePassKind.RendererEffect,
        reads: [middle.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 100, 100)), effectRadius: 5,
        stableInputCode: 32, canCull: true)
    FrameGraph("effect", 1, frameId, 100, 100, [input, middle, output], [ui, effect],
        frameDamage: DamageRegion.empty())
}

@Test
func frameGraphCompilerPropagatesAndExpandsEffectDamage(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    @Expect(runtime.execute(effectFrameGraph(1, DamageRegion.empty()), executor).ok)

    let second = requireCompiledFrame(compileFrameGraph(
        effectFrameGraph(2, DamageRegion.bounded([FrameDamageRect(10, 10, 2, 2)])),
        runtime.state(), executor.capabilities()))
    let effect = compiledFramePass(second, "effect.blur")
    @Expect(!effect.culled)
    @Expect(effect.damage.kind == FrameDamageKind.Bounded)
    @Expect(effect.damage.rectangleCount(), 1)
    @Expect(effect.damage.rectangleAt(0), FrameDamageRect(5, 5, 12, 12))
}

@Test
func frameGraphCompilerMergesOnlyAdjacentCompatiblePasses(): Unit {
    let input = FrameResourceDescriptor(
        FrameResourceId("merge.target", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let middle = FrameResourceDescriptor(
        FrameResourceId("merge.target", 2), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let output = FrameResourceDescriptor(
        FrameResourceId("merge.target", 3), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let bounds = Some(FrameDamageRect(0, 0, 40, 40))
    let first = FramePassDescriptor(
        FramePassId("merge.first"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [middle.id], bounds: bounds,
        stableInputCode: 41, canMerge: true, mergeKey: "merge.surface")
    let second = FramePassDescriptor(
        FramePassId("merge.second"), 1, FramePassKind.Ui2D,
        reads: [middle.id], writes: [output.id], bounds: bounds,
        stableInputCode: 42, canMerge: true, mergeKey: "merge.surface")
    let compiled = requireCompiledFrame(compileFrameGraph(
        FrameGraph("merge", 1, 1, 40, 40, [input, middle, output], [first, second]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(compiled.executionGroupCount(), 1)
    @Expect(compiled.executionGroupAt(0).passCount(), 2)
    @Expect(compiled.mergedPassCount, 1)

    let incompatible = FramePassDescriptor(
        FramePassId("merge.second"), 1, FramePassKind.Ui2D,
        reads: [middle.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 39, 40)),
        stableInputCode: 42, canMerge: true, mergeKey: "merge.surface")
    let split = requireCompiledFrame(compileFrameGraph(
        FrameGraph("merge", 1, 1, 40, 40, [input, middle, output], [first, incompatible]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(split.executionGroupCount(), 2)
    @Expect(split.mergedPassCount, 0)

    let disconnected = FramePassDescriptor(
        FramePassId("merge.second"), 1, FramePassKind.Ui2D,
        reads: [input.id], writes: [output.id], bounds: bounds,
        stableInputCode: 42, canMerge: true, mergeKey: "merge.surface")
    let disconnectedGraph = requireCompiledFrame(compileFrameGraph(
        FrameGraph("merge", 1, 1, 40, 40,
            [input, middle, output], [first, disconnected]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(disconnectedGraph.executionGroupCount(), 2)
    @Expect(disconnectedGraph.mergedPassCount, 0)

    let noMergeFirst = FramePassDescriptor(
        FramePassId("merge.first"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [middle.id], bounds: bounds,
        stableInputCode: 41, canMerge: false, mergeKey: "merge.surface")
    let noMerge = requireCompiledFrame(compileFrameGraph(
        FrameGraph("merge", 1, 1, 40, 40,
            [input, middle, output], [noMergeFirst, second]),
        FrameGraphCompilerState(), frameTestCapabilities()))
    @Expect(noMerge.executionGroupCount(), 2)
    @Expect(noMerge.mergedPassCount, 0)
    @Expect(compiled.scheduleHash != noMerge.scheduleHash)
}

private func mergeBarrierFrameGraph(frameId: Int64, targetGeneration: Int64): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("barrier.target", targetGeneration), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let middle = FrameResourceDescriptor(
        FrameResourceId("barrier.target", targetGeneration + 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let output = FrameResourceDescriptor(
        FrameResourceId("barrier.target", targetGeneration + 2), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let sideInput = FrameResourceDescriptor(
        FrameResourceId("barrier.side.input", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Imported)
    let sideOutput = FrameResourceDescriptor(
        FrameResourceId("barrier.side.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let bounds = Some(FrameDamageRect(0, 0, 40, 40))
    let first = FramePassDescriptor(
        FramePassId("barrier.first"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [middle.id], bounds: bounds,
        stableInputCode: 111, canCull: true, canMerge: true, mergeKey: "barrier.surface")
    let barrier = FramePassDescriptor(
        FramePassId("barrier.culled"), 1, FramePassKind.Ui2D,
        reads: [sideInput.id], writes: [sideOutput.id], bounds: bounds,
        stableInputCode: 112, canCull: true)
    let last = FramePassDescriptor(
        FramePassId("barrier.last"), 2, FramePassKind.Ui2D,
        reads: [middle.id], writes: [output.id], bounds: bounds,
        stableInputCode: 113, canCull: true, canMerge: true, mergeKey: "barrier.surface")
    FrameGraph("merge-barrier", 1, frameId, 40, 40,
        [input, middle, output, sideInput, sideOutput], [first, barrier, last],
        frameDamage: DamageRegion.empty())
}

@Test
func frameGraphCompilerNeverMergesAcrossCulledScheduleEntry(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    @Expect(runtime.execute(mergeBarrierFrameGraph(1, 1), executor).ok)

    let second = requireCompiledFrame(compileFrameGraph(
        mergeBarrierFrameGraph(2, 4), runtime.state(), executor.capabilities()))
    @Expect(compiledFramePass(second, "barrier.culled").culled)
    @Expect(!compiledFramePass(second, "barrier.first").culled)
    @Expect(!compiledFramePass(second, "barrier.last").culled)
    @Expect(second.executionGroupCount(), 2)
    @Expect(second.mergedPassCount, 0)
}

@Test
func frameGraphCompilerDistinguishesBoundedRedrawFromFullPresent(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor(capabilities: frameTestCapabilities())
    @Expect(runtime.execute(deterministicFrameGraph(), executor).ok)
    let bounded = requireCompiledFrame(compileFrameGraph(
        deterministicFrameGraph(
            frameId: 2,
            damage: DamageRegion.bounded([FrameDamageRect(1, 1, 3, 3)])),
        runtime.state(), executor.capabilities()))
    @Expect(bounded.redrawMode == FrameRedrawMode.Bounded)
    @Expect(bounded.presentMode == FramePresentMode.Full)
    @Expect(bounded.presentStrategy == FramePresentStrategy.PreservedBufferBounded)
    @Expect(bounded.fallbackReason, "partial-present-unsupported")

    let incremental = requireCompiledFrame(compileFrameGraph(
        deterministicFrameGraph(
            frameId: 2,
            damage: DamageRegion.bounded([FrameDamageRect(1, 1, 3, 3)])),
        runtime.state(), frameTestCapabilities(partial: true)))
    @Expect(incremental.redrawMode == FrameRedrawMode.Bounded)
    @Expect(incremental.presentMode == FramePresentMode.Partial)
    @Expect(incremental.presentStrategy == FramePresentStrategy.IncrementalRegions)

    let unsupported = requireCompiledFrame(compileFrameGraph(
        deterministicFrameGraph(
            frameId: 2,
            damage: DamageRegion.bounded([FrameDamageRect(1, 1, 3, 3)])),
        runtime.state(), frameTestCapabilities(bounded: false)))
    @Expect(unsupported.redrawMode == FrameRedrawMode.Full)
    @Expect(unsupported.presentMode == FramePresentMode.Full)
    @Expect(unsupported.presentStrategy == FramePresentStrategy.UnsupportedFallback)
}
