package chui.graphics

import std.collection.ArrayList
import std.env.getVariable
import sdl.{Color, Renderer}
import sdl.system.PerformanceClock

private class SdlExecutorTestCounter {
    var value: Int64 = 0
}

private class SdlExecutorTestTransient <: Resource {
    private let failClose: Bool
    private var closed = false
    var closeCount: Int64 = 0

    init(failClose!: Bool = false) {
        this.failClose = failClose
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        closeCount += 1
        if (failClose) { throw Exception("configured transient close failure") }
    }
}

private func sdlExecutorOutputId(transient!: Bool = false): FrameResourceId {
    FrameResourceId(if (transient) { "frame.transient" } else { "frame.surface" }, 1)
}

private func sdlExecutorRasterGraph(
    transient!: Bool = false,
    frameId!: Int64 = 1,
    width!: Int64 = 64,
    height!: Int64 = 48,
    frameDamage!: DamageRegion = DamageRegion.full(),
    passDamage!: DamageRegion = DamageRegion.full()
): FrameGraph {
    let output = sdlExecutorOutputId(transient: transient)
    let lifetime = if (transient) {
        FrameResourceLifetime.Transient
    } else {
        FrameResourceLifetime.Persistent
    }
    FrameGraph(
        "sdl.test",
        1,
        frameId,
        width,
        height,
        [FrameResourceDescriptor(output, FrameResourceKind.Surface, lifetime)],
        [
            FramePassDescriptor(
                FramePassId("ui.main"),
                0,
                FramePassKind.Ui2D,
                writes: [output],
                bounds: Some(FrameDamageRect(0, 0, width, height)),
                declaredDamage: passDamage),
            FramePassDescriptor(
                FramePassId("present.main"),
                1,
                FramePassKind.Present,
                reads: [output])
        ],
        frameDamage: frameDamage)
}

private func sdlExecutorSceneBarrierGraph(mode: FrameExternalMode): FrameGraph {
    let output = FrameResourceId("scene.surface", 1)
    FrameGraph(
        "sdl.scene",
        1,
        1,
        80,
        60,
        [FrameResourceDescriptor(
            output,
            FrameResourceKind.ExternalSurface,
            FrameResourceLifetime.Persistent)],
        [
            FramePassDescriptor(
                FramePassId("scene.main"),
                0,
                FramePassKind.ExternalScene3D,
                writes: [output],
                declaredDamage: DamageRegion.full(),
                externalMode: mode),
            FramePassDescriptor(
                FramePassId("present.main"),
                1,
                FramePassKind.Present,
                reads: [output])
        ],
        frameDamage: DamageRegion.full())
}

private func sdlExecutorSharedImportUiGraph(): FrameGraph {
    let source = FrameResourceId("scene.shared", 1)
    let target = FrameResourceId("scene.target", 1)
    FrameGraph(
        "sdl.shared-scene",
        1,
        1,
        80,
        60,
        [
            FrameResourceDescriptor(source, FrameResourceKind.Texture, FrameResourceLifetime.Imported,
                declaredBytes: 80 * 60 * 4),
            FrameResourceDescriptor(target, FrameResourceKind.Surface, FrameResourceLifetime.Persistent)
        ],
        [
            FramePassDescriptor(
                FramePassId("scene.acquire"), 0, FramePassKind.ExternalScene3D,
                reads: [source], externalMode: FrameExternalMode.SharedTexture),
            FramePassDescriptor(
                FramePassId("ui.main"), 1, FramePassKind.Ui2D,
                reads: [source], writes: [target], dependsOn: [FramePassId("scene.acquire")]),
            FramePassDescriptor(
                FramePassId("present.main"), 2, FramePassKind.Present, reads: [target])
        ])
}

private func compiledSdlExecutorGraph(
    graph: FrameGraph,
    executor: SdlFrameGraphExecutor
): CompiledFrameGraph {
    let result = compileFrameGraph(graph, FrameGraphCompilerState(), executor.capabilities())
    if (!result.ok) { throw Exception("test graph did not compile: ${result.code}") }
    match (result.graph()) {
        case Some(value) => value
        case None => throw Exception("test compiler returned no plan")
    }
}

@Test
func sdlExecutorKeepsRuntimeBindingsOutOfTraceAndReportsFullPresent(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let calls = SdlExecutorTestCounter()
    let beforePresentCalls = SdlExecutorTestCounter()
    executor.setBeforePresent({ => beforePresentCalls.value += 1 })
    executor.bindPass(FramePassId("ui.main"), {context =>
        let _ = context.renderer
        calls.value += 1
        FramePassExecutionResult(true, "runtime-secret-action")
    })

    let capabilities = executor.capabilities()
    @Expect(!capabilities.supportsBoundedRedraw)
    @Expect(!capabilities.supportsPartialPresent)
    @Expect(!capabilities.supportsSharedTexture)
    @Expect(!capabilities.supportsExtendedDynamicRange)

    let receipt = FrameGraphRuntime().execute(sdlExecutorRasterGraph(), executor)
    @Expect(receipt.ok)
    @Expect(receipt.presentMode == FramePresentMode.Full)
    @Expect(receipt.presentStrategy == FramePresentStrategy.FullSurface)
    @Expect(!receipt.trace.contains("runtime-secret-action"))
    @Expect(calls.value, 1)
    @Expect(beforePresentCalls.value, 1)

    let provider = executor.lastReceipt()
    @Expect(provider.ok)
    @Expect(provider.presentMode == FramePresentMode.Full)
    @Expect(provider.presentStrategy == FramePresentStrategy.FullSurface)
    @Expect(!provider.deviceBacked)
    @Expect(provider.unifiedPixels)
    @Expect(!provider.legacyFallbackRequired)
    @Expect(!executor.markLegacyFallbackUsed())
    executor.close()
}

@Test
func sdlExecutorFullPromotionNeverReappliesPerPassBoundedClip(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let runtime = FrameGraphRuntime()
    let calls = SdlExecutorTestCounter()
    executor.bindPass(FramePassId("ui.main"), {context =>
        @Expect(context.renderer.currentClip().isNone())
        calls.value += 1
        FramePassExecutionResult(true, "accepted")
    })

    @Expect(runtime.execute(sdlExecutorRasterGraph(), executor).ok)
    let bounded = DamageRegion.bounded([FrameDamageRect(0, 0, 8, 8)])
    let promoted = runtime.execute(
        sdlExecutorRasterGraph(
            frameId: 2,
            frameDamage: bounded,
            passDamage: DamageRegion.empty()),
        executor)
    @Expect(promoted.ok)
    @Expect(promoted.redrawMode == FrameRedrawMode.Full)
    @Expect(promoted.presentMode == FramePresentMode.Full)
    @Expect(promoted.presentStrategy == FramePresentStrategy.UnsupportedFallback)
    @Expect(promoted.fallbackReason, "bounded-redraw-unsupported")
    @Expect(calls.value, 2)
    executor.close()
}

@Test
func sdlExecutorReusesAnImmutableBindingSnapshotUntilBindingsChange(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    executor.bindPass(FramePassId("ui.main"), {_ =>
        FramePassExecutionResult(true, "accepted")
    })
    let first = compiledSdlExecutorGraph(sdlExecutorRasterGraph(frameId: 1), executor)
    let firstSession = executor.begin(first)
    firstSession.rollback()
    @Expect(executor.bindingSnapshotBuildCount(), 1)

    let second = compiledSdlExecutorGraph(sdlExecutorRasterGraph(frameId: 2), executor)
    let secondSession = executor.begin(second)
    secondSession.rollback()
    @Expect(executor.bindingSnapshotBuildCount(), 1)

    executor.bindPass(FramePassId("ui.main"), {_ =>
        FramePassExecutionResult(true, "replacement")
    })
    let third = compiledSdlExecutorGraph(sdlExecutorRasterGraph(frameId: 3), executor)
    let thirdSession = executor.begin(third)
    thirdSession.rollback()
    @Expect(executor.bindingSnapshotBuildCount(), 2)
    executor.close()
}

@Test
func sdlExecutorReleasesDeclaredTransientExactlyOnceOnCommit(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let resource = SdlExecutorTestTransient()
    let id = sdlExecutorOutputId(transient: true)
    executor.bindPass(FramePassId("ui.main"), {context =>
        context.manageTransient(id, resource)
        FramePassExecutionResult(true, "accepted")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorRasterGraph(transient: true), executor)
    @Expect(receipt.ok)
    @Expect(resource.closeCount, 1)
    @Expect(resource.isClosed())
    @Expect(executor.lastReceipt().managedTransientCount, 1)
    @Expect(executor.lastReceipt().releasedTransientCount, 1)
    @Expect(executor.lastReceipt().cleanupFailureCount, 0)
    executor.close()
}

@Test
func sdlExecutorRollsBackFailedPassAndReleasesTransientExactlyOnce(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let resource = SdlExecutorTestTransient()
    let id = sdlExecutorOutputId(transient: true)
    executor.bindPass(FramePassId("ui.main"), {context =>
        context.manageTransient(id, resource)
        FramePassExecutionResult(false, "configured-pass-failure")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorRasterGraph(transient: true), executor)
    @Expect(!receipt.ok)
    @Expect(receipt.code, "executor-pass-failed")
    @Expect(resource.closeCount, 1)
    @Expect(executor.lastReceipt().code, "configured-pass-failure")
    @Expect(executor.lastReceipt().presentMode == FramePresentMode.NotPresented)
    @Expect(executor.lastReceipt().presentStrategy == FramePresentStrategy.NotPresented)
    @Expect(executor.lastReceipt().releasedTransientCount, 1)
    @Expect(executor.lastReceipt().legacyFallbackRequired)
    executor.close()
}

@Test
func sdlExecutorDoesNotRetryThrowingTransientCloseAfterCommitFailure(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let resource = SdlExecutorTestTransient(failClose: true)
    let id = sdlExecutorOutputId(transient: true)
    executor.bindPass(FramePassId("ui.main"), {context =>
        context.manageTransient(id, resource)
        FramePassExecutionResult(true, "accepted")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorRasterGraph(transient: true), executor)
    @Expect(!receipt.ok)
    @Expect(receipt.code, "executor-commit-failed")
    @Expect(resource.closeCount, 1)
    @Expect(executor.lastReceipt().code, "transient-release-failed")
    @Expect(executor.lastReceipt().presentMode == FramePresentMode.NotPresented)
    @Expect(executor.lastReceipt().presentStrategy == FramePresentStrategy.NotPresented)
    @Expect(executor.lastReceipt().releasedTransientCount, 1)
    @Expect(executor.lastReceipt().cleanupFailureCount, 1)
    executor.close()
}

@Test
func sdlExecutorFreezesBindingsWhenSessionBegins(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let calls = SdlExecutorTestCounter()
    let compiled = compiledSdlExecutorGraph(sdlExecutorRasterGraph(), executor)
    let session = executor.begin(compiled)
    executor.bindPass(FramePassId("ui.main"), {_ =>
        calls.value += 1
        FramePassExecutionResult(true, "accepted")
    })

    var clearRejected = false
    try {
        executor.clearPassBindings()
    } catch (_: IllegalStateException) {
        clearRejected = true
    }
    @Expect(clearRejected)

    var colorRejected = false
    try {
        executor.setClearColor(Color.rgb(1, 2, 3))
    } catch (_: IllegalStateException) {
        colorRejected = true
    }
    @Expect(colorRejected)

    let result = session.execute(compiled.executionGroupAt(0))
    @Expect(!result.ok)
    @Expect(result.code, "missing-runtime-binding")
    session.rollback()
    session.rollback()
    @Expect(calls.value, 0)
    @Expect(executor.lastReceipt().legacyFallbackRequired)
    @Expect(executor.markLegacyFallbackUsed())
    let fallback = executor.lastReceipt()
    @Expect(fallback.ok)
    @Expect(fallback.code, "accepted-legacy-fallback")
    @Expect(fallback.redrawMode == FrameRedrawMode.Full)
    @Expect(fallback.presentMode == FramePresentMode.Full)
    @Expect(fallback.presentStrategy == FramePresentStrategy.UnsupportedFallback)
    @Expect(fallback.legacyFallbackUsed)
    @Expect(!executor.markLegacyFallbackUsed())
    executor.clearPassBindings()
    @Expect(executor.bindingCount(), 0)
    executor.close()
}

@Test
func sdlExecutorRejectsCloseWhileSessionOwnsResources(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let compiled = compiledSdlExecutorGraph(sdlExecutorRasterGraph(), executor)
    let session = executor.begin(compiled)

    var closeRejected = false
    try {
        executor.close()
    } catch (_: IllegalStateException) {
        closeRejected = true
    }
    @Expect(closeRejected)

    session.rollback()
    executor.close()
}

@Test
func sdlExecutorRecordsUpperFallbackWhenCompilerRejectedBeforeBegin(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    @Expect(executor.markLegacyFallbackUsed(frameId: 7, nativeChildBarrierCount: 1))
    let receipt = executor.lastReceipt()
    @Expect(receipt.ok)
    @Expect(receipt.code, "accepted-legacy-fallback")
    @Expect(receipt.frameId, 7)
    @Expect(receipt.redrawMode == FrameRedrawMode.Full)
    @Expect(receipt.presentMode == FramePresentMode.Full)
    @Expect(!receipt.unifiedPixels)
    @Expect(receipt.nativeChildBarrierCount, 1)
    @Expect(receipt.legacyFallbackRequired)
    @Expect(receipt.legacyFallbackUsed)
    executor.close()
}

@Test
func sdlExecutorMarksNativeChildSceneBarrierAsNonUnifiedPixels(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let calls = SdlExecutorTestCounter()
    executor.bindPass(FramePassId("scene.main"), {context =>
        @Expect(!context.unifiedPixels)
        calls.value += 1
        FramePassExecutionResult(true, "accepted")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorSceneBarrierGraph(FrameExternalMode.NativeChildSurfaceBarrier), executor)
    @Expect(receipt.ok)
    @Expect(receipt.presentMode == FramePresentMode.Full)
    @Expect(calls.value, 1)
    @Expect(!executor.lastReceipt().unifiedPixels)
    @Expect(executor.lastReceipt().nativeChildBarrierCount, 1)
    executor.close()
}

@Test
func sdlExecutorRejectsSharedTextureBeforeAnyRuntimeBinding(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless())
    let calls = SdlExecutorTestCounter()
    executor.bindPass(FramePassId("scene.main"), {_ =>
        calls.value += 1
        FramePassExecutionResult(true, "should-not-run")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorSceneBarrierGraph(FrameExternalMode.SharedTexture), executor)
    @Expect(!receipt.ok)
    @Expect(receipt.code, "unsupported-shared-texture")
    @Expect(calls.value, 0)
    executor.close()
}

@Test
func sdlExecutorAcceptsSharedAcquireOnlyAfterDeviceCapabilityProof(): Unit {
    let executor = SdlFrameGraphExecutor(
        Renderer.headless(), assumeDeviceBackedForConformance: true)
    let sharedCalls = SdlExecutorTestCounter()
    executor.bindPass(FramePassId("scene.acquire"), {context =>
        @Expect(context.unifiedPixels)
        sharedCalls.value += 1
        FramePassExecutionResult(true, "accepted")
    })
    executor.bindPass(FramePassId("ui.main"), {_ =>
        FramePassExecutionResult(true, "accepted")
    })
    @Expect(executor.capabilities().supportsSharedTexture)
    let receipt = FrameGraphRuntime().execute(sdlExecutorSharedImportUiGraph(), executor)
    @Expect(receipt.ok)
    @Expect(sharedCalls.value, Int64(1))
    @Expect(executor.lastReceipt().unifiedPixels)
    executor.close()
}

@Test
func sdlExecutorRejectsOversizedSurfaceBeforeInvokingRuntimeAction(): Unit {
    let executor = SdlFrameGraphExecutor(Renderer.headless(), maxSurfacePixels: 1024)
    let calls = SdlExecutorTestCounter()
    executor.bindPass(FramePassId("ui.main"), {_ =>
        calls.value += 1
        FramePassExecutionResult(true, "should-not-run")
    })

    let receipt = FrameGraphRuntime().execute(
        sdlExecutorRasterGraph(width: 64, height: 64), executor)
    @Expect(!receipt.ok)
    @Expect(receipt.code, "executor-pass-failed")
    @Expect(executor.lastReceipt().code, "surface-pixels-over-cap")
    @Expect(calls.value, 0)
    executor.close()
}

@Test
func sdlFramePhysicalPixelBudgetIncludesTheProviderScale(): Unit {
    @Expect(sdlFramePhysicalPixelCount(100, 50, 2.0), Int64(20000))
    @Expect(sdlFramePhysicalPixelCount(100, 50, 0.0), Int64(0))
    @Expect(sdlFramePhysicalPixelCount(Int64.Max, 2, 1.0), Int64.Max)
}

private class FrameGraphAbCounter {
    var value: Int64 = 0
}

private class FrameGraphAbLegacySession {
    private let renderer = Renderer.headless()
    private let counter = FrameGraphAbCounter()

    func run(iterations: Int64): UInt64 {
        let before = counter.value
        let started = PerformanceClock.ticksNanoseconds()
        for (_ in 0..iterations) {
            renderer.beginScene(64.0, 64.0, Color.rgb(0, 0, 0))
            counter.value += 1
            renderer.endScene()
            renderer.present()
        }
        let finished = PerformanceClock.ticksNanoseconds()
        @Expect(counter.value - before, iterations)
        if (finished > started) { finished - started } else { UInt64(0) }
    }
}

private class FrameGraphAbGraphSession <: Resource {
    private let counter = FrameGraphAbCounter()
    private let runtime = FrameGraphRuntime()
    private let executor = SdlFrameGraphExecutor(Renderer.headless())
    private var nextFrameId: Int64 = 1
    private var cacheHitsValue: Int64 = 0
    private var cacheMissesValue: Int64 = 0
    private var closed = false

    init() {
        executor.bindPass(FramePassId("ui.main"), {_ =>
            counter.value += 1
            FramePassExecutionResult(true, "accepted")
        })
    }

    func resetMeasuredCacheCounts(): Unit {
        cacheHitsValue = 0
        cacheMissesValue = 0
    }

    func cacheHits(): Int64 { cacheHitsValue }
    func cacheMisses(): Int64 { cacheMissesValue }

    func run(iterations: Int64): UInt64 {
        let before = counter.value
        let started = PerformanceClock.ticksNanoseconds()
        for (_ in 0..iterations) {
            let receipt = runtime.execute(frameGraphAbGraph(nextFrameId), executor)
            nextFrameId += 1
            if (!receipt.ok) {
                throw Exception("same-process FrameGraph A/B failed: ${receipt.code}")
            }
            if (receipt.scheduleCacheHit) { cacheHitsValue += 1 } else { cacheMissesValue += 1 }
        }
        let finished = PerformanceClock.ticksNanoseconds()
        @Expect(counter.value - before, iterations)
        if (finished > started) { finished - started } else { UInt64(0) }
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (!closed) {
            closed = true
            executor.close()
        }
    }
}

/**
 * Same-process raw scheduler A/B. Both lanes execute the same headless SDL scene lifecycle and one
 * frame action; the graph lane additionally compiles and executes its protected schedule. This is
 * scheduler-overhead evidence, not a speedup claim or a display/GPU benchmark.
 */
@Test
func sdlFrameGraphSameProcessAbPublishesRawSchedulerSamplesWithoutSpeedupClaim(): Unit {
    let samples: Int64 = 5
    let iterations: Int64 = 250
    let warmupIterations: Int64 = 32
    let legacy = ArrayList<UInt64>()
    let graph = ArrayList<UInt64>()
    let legacySession = FrameGraphAbLegacySession()
    try (graphSession = FrameGraphAbGraphSession()) {
        let _ = legacySession.run(warmupIterations)
        let _ = graphSession.run(warmupIterations)
        graphSession.resetMeasuredCacheCounts()
        for (sample in 0..samples) {
            if (sample % 2 == 0) {
                legacy.add(legacySession.run(iterations))
                graph.add(graphSession.run(iterations))
            } else {
                graph.add(graphSession.run(iterations))
                legacy.add(legacySession.run(iterations))
            }
        }
        @Expect(graphSession.cacheHits(), samples * iterations)
        @Expect(graphSession.cacheMisses(), Int64(0))
        println("@@FRAMEGRAPH_AB|cache|measured_hits=${graphSession.cacheHits()}|" +
            "measured_misses=${graphSession.cacheMisses()}|warmup_scope=same-runtime-executor")
    }
    @Expect(legacy.size, samples)
    @Expect(graph.size, samples)
    let benchmarkCommit = frameGraphAbMetadata("CANGHUI_BENCHMARK_COMMIT")
    let benchmarkToolchain = frameGraphAbMetadata("CANGHUI_BENCHMARK_TOOLCHAIN")
    println("@@FRAMEGRAPH_AB|environment|same-process|renderer=headless|executor=sdl-headless|" +
        "surface=64x64|warmup_iterations=${warmupIterations}|iterations=${iterations}|" +
        "samples=${samples}|legacy_mode=immediate-full-present|" +
        "framegraph_mode=validated-schedule-cache|comparison=equivalent-frame-lifecycle|" +
        "scope=scheduler-overhead-only|claim=no-speedup|commit=${benchmarkCommit}|" +
        "toolchain=${benchmarkToolchain}|mode=debug-test")
    for (i in 0..samples) {
        println("@@FRAMEGRAPH_AB|sample=${i}|legacy_ns=${legacy[i]}|framegraph_ns=${graph[i]}")
    }
    let legacyMin = minimumFrameGraphAbSample(legacy)
    let legacyMax = maximumFrameGraphAbSample(legacy)
    let graphMin = minimumFrameGraphAbSample(graph)
    let graphMax = maximumFrameGraphAbSample(graph)
    println("@@FRAMEGRAPH_AB|spread|legacy_min_ns=${legacyMin}|legacy_max_ns=${legacyMax}|" +
        "legacy_spread_ns=${legacyMax - legacyMin}|framegraph_min_ns=${graphMin}|" +
        "framegraph_max_ns=${graphMax}|framegraph_spread_ns=${graphMax - graphMin}|" +
        "claim=raw-samples-only")
}

private func minimumFrameGraphAbSample(values: ArrayList<UInt64>): UInt64 {
    var result = values[0]
    for (value in values) { result = min(result, value) }
    result
}

private func maximumFrameGraphAbSample(values: ArrayList<UInt64>): UInt64 {
    var result = values[0]
    for (value in values) { result = max(result, value) }
    result
}

private func frameGraphAbMetadata(name: String): String {
    match (getVariable(name)) {
        case Some(value) where !value.isEmpty() && value.toArray().size <= 128 =>
            value.replace("|", "_").replace("\n", "_").replace("\r", "_")
        case _ => "external-gate-unset"
    }
}

private func frameGraphAbGraph(frameId: Int64): FrameGraph {
    let target = FrameResourceId("surface", 1)
    let bounds = FrameDamageRect(0, 0, 64, 64)
    FrameGraph(
        "framegraph.ab",
        1,
        frameId,
        64,
        64,
        [FrameResourceDescriptor(
            target,
            FrameResourceKind.Surface,
            FrameResourceLifetime.Persistent,
            declaredBytes: 16384)],
        [
            FramePassDescriptor(
                FramePassId("ui.main"),
                0,
                FramePassKind.Ui2D,
                writes: [target],
                bounds: Some(bounds),
                stableInputCode: frameId),
            FramePassDescriptor(
                FramePassId("present"),
                1,
                FramePassKind.Present,
                reads: [target],
                bounds: Some(bounds),
                stableInputCode: frameId)
        ],
        frameDamage: DamageRegion.full())
}
