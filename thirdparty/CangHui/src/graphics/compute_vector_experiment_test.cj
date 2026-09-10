package chui.graphics

private func computeVectorTestAdapter(compute!: Bool = true): GraphicsAdapterCapabilities {
    let values = if (compute) {
        [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture,
            GraphicsCapability.ComputePipeline,
            GraphicsCapability.StorageBuffer
        ]
    } else {
        [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture
        ]
    }
    GraphicsAdapterCapabilities(
        "compute-vector-test", "adapter", GraphicsBackend.Vulkan,
        if (compute) { GraphicsProfile.Compute3D } else { GraphicsProfile.Core3D },
        GraphicsLimits(8192, 4, 8, 4), capabilities: values)
}

private func computeVectorRectangleScene(
    width!: Int64 = 4,
    height!: Int64 = 4,
    tileSize!: Int64 = 2
): ComputeVectorScene {
    ComputeVectorScene(
        "rectangle", width, height,
        [ComputeVectorPath("rect", [
            ComputeVectorPoint(0.0, 0.0),
            ComputeVectorPoint(Float32(width), 0.0),
            ComputeVectorPoint(Float32(width), Float32(height)),
            ComputeVectorPoint(0.0, Float32(height))
        ])],
        tileSize: tileSize)
}

private func computeVectorTestPack(): PortableGpuPipelinePack {
    PortableGpuPipelinePack(
        "compute-vector",
        PortableGpuPackTarget(
            "compute-vector-test", "adapter", GraphicsBackend.Vulkan,
            GraphicsProfile.Compute3D, 1, "spirv.v1", "chui.bind-layout.v1",
            GraphicsLimits(4096, 2, 4, 2),
            [GraphicsCapability.ComputePipeline, GraphicsCapability.StorageBuffer],
            1048576),
        [PortableGpuPipelineArtifact(
            CANGHUI_COMPUTE_VECTOR_PIPELINE_ID,
            GraphicsBackend.Vulkan,
            PortableGpuPipelineStage.Compute,
            "main",
            [UInt8(7), UInt8(8), UInt8(9)])],
        [PortableGpuPassRequirement(
            "compute-vector.rasterize",
            [PortableGpuPipelineUse(
                CANGHUI_COMPUTE_VECTOR_PIPELINE_ID, PortableGpuPipelineStage.Compute)],
            1048576)])
}

private class RecordingComputeVectorGpuProvider <: ComputeVectorGpuProvider {
    private let result: ComputeVectorProviderResult
    private let proofMode: String
    private var calls: Int64 = 0

    init(result: ComputeVectorProviderResult, proofMode!: String = "valid") {
        this.result = result
        this.proofMode = proofMode
    }

    public func identity(): String { "recording-compute-provider" }

    public func snapshot(): PortableGpuDeviceSnapshot {
        PortableGpuDeviceSnapshot(
            "recording-compute-device", computeVectorTestAdapter(), 1,
            "spirv.v1", "chui.bind-layout.v1", FrameGraphExecutorCapabilities())
    }

    public func execute(
        graph: FrameGraph,
        wire: ComputeVectorPackedWire,
        pack: PortableGpuPipelinePack
    ): ComputeVectorProviderResult {
        calls += 1
        if (!result.ok || proofMode == "missing") { return result }
        let snapshot = snapshot()
        let proof = ComputeVectorGpuCommandProof(
            "dispatch-${graph.frameId}", snapshot.identity,
            if (proofMode == "stale-device") { 2 } else { snapshot.capabilityGeneration },
            snapshot.adapter.backend, graph.surfaceKey, graph.surfaceGeneration, graph.frameId,
            "compute-vector.rasterize", (graph.surfaceWidth + 7) / 8,
            (graph.surfaceHeight + 7) / 8, proofMode != "incomplete",
            if (proofMode == "wrong-pipeline") {
                PortableGpuPipelineArtifact(
                    CANGHUI_COMPUTE_VECTOR_PIPELINE_ID, GraphicsBackend.Vulkan,
                    PortableGpuPipelineStage.Compute, "main", [UInt8(99)])
            } else {
                pack.artifactAt(0)
            },
            wire)
        ComputeVectorProviderResult(result.ok, result.code, result.coverage, commandProof: Some(proof))
    }

    func callCount(): Int64 { calls }
}

@Test
func computeVectorExperimentNamesAndCandidateLanguageStayHonest(): Unit {
    @Expect(CANGHUI_COMPUTE_VECTOR_PROTOCOL, "canghui.compute-vector.v0-experiment")
    @Expect(computeVectorFillRuleName(ComputeVectorFillRule.EvenOdd), "even-odd")
    @Expect(computeVectorPlanModeName(ComputeVectorPlanMode.ComputeCandidate), "compute-candidate")
    @Expect(computeVectorActualExecutionName(ComputeVectorActualExecution.ProviderGpu), "provider-gpu")

    let first = computeVectorRectangleScene()
    let second = computeVectorRectangleScene()
    @Expect(first.cacheKey, second.cacheKey)
    @Expect(first.totalPoints, 4)

    let plan = planComputeVector(first, computeVectorTestAdapter())
    @Expect(plan.isComputeCandidate())
    @Expect(plan.code, "compute-candidate")
    let notExecuted = verifyComputeVectorCoverage(
        plan, renderComputeVectorCpuOracle(first), renderComputeVectorCpuOracle(first),
        ComputeVectorActualExecution.NotExecuted)
    @Expect(!notExecuted.gpuActuallyExecuted())
    @Expect(!notExecuted.accepted())
    @Expect(notExecuted.code, "not-executed")
}

@Test
func computeVectorLoweringProducesBoundedSegmentsAndRayCorrectTileBins(): Unit {
    let scene = computeVectorRectangleScene()
    let result = lowerComputeVectorScene(scene)
    @Expect(result.ok)
    let lowered = result.lowered().getOrThrow()
    @Expect(lowered.segmentCount(), 4)
    @Expect(lowered.tileColumns, 2)
    @Expect(lowered.tileRows, 2)
    @Expect(lowered.tileCount(), 4)
    @Expect(lowered.tileReferenceCount > 4)
    @Expect(lowered.tileAt(0, 0).segmentReferenceCount() > 0)

    let overflow = lowerComputeVectorScene(
        scene, limits: ComputeVectorLimits(maxTileReferences: 1))
    @Expect(!overflow.ok)
    @Expect(overflow.code, "tile-reference-overflow")
}

@Test
func computeVectorPackedWireCarriesExactSegmentsTilesReferencesAndRules(): Unit {
    let scene = computeVectorRectangleScene()
    let lowered = lowerComputeVectorScene(scene).lowered().getOrThrow()
    let first = packComputeVectorLoweredScene(lowered)
    let second = packComputeVectorLoweredScene(lowered)
    @Expect(first.protocol, CANGHUI_COMPUTE_VECTOR_WIRE_PROTOCOL)
    @Expect(first.schemaVersion, 1)
    @Expect(first.sourceIdentity, scene.exactIdentity())
    @Expect(first.segmentCount, lowered.segmentCount())
    @Expect(first.tileCount, lowered.tileCount())
    @Expect(first.referenceCount, lowered.tileReferenceCount)
    @Expect(first.pathCount, lowered.pathCount())
    @Expect(first.segmentOffset < first.tileOffset)
    @Expect(first.tileOffset < first.referenceOffset)
    @Expect(first.referenceOffset < first.fillRuleOffset)
    @Expect(first.fillRuleOffset < first.byteCount())
    @Expect(first.exactlyMatches(second))

    let changed = ComputeVectorScene(
        "rectangle", 4, 4,
        [ComputeVectorPath("rect", [
            ComputeVectorPoint(0.0, 0.0), ComputeVectorPoint(3.5, 0.0),
            ComputeVectorPoint(3.5, 4.0), ComputeVectorPoint(0.0, 4.0)
        ], fillRule: ComputeVectorFillRule.EvenOdd)], tileSize: 2)
    let changedWire = packComputeVectorLoweredScene(
        lowerComputeVectorScene(changed).lowered().getOrThrow())
    @Expect(!first.exactlyMatches(changedWire))
}

@Test
func computeVectorPlannerSeparatesComputeCandidateFromFallback(): Unit {
    let scene = computeVectorRectangleScene()
    let candidate = planComputeVector(scene, computeVectorTestAdapter())
    @Expect(candidate.mode == ComputeVectorPlanMode.ComputeCandidate)
    @Expect(candidate.segmentCount, 4)
    @Expect(candidate.tileReferenceCount > 0)

    let missing = planComputeVector(scene, computeVectorTestAdapter(compute: false))
    @Expect(missing.mode == ComputeVectorPlanMode.CpuFallback)
    @Expect(missing.code, "compute-capability-unavailable")

    let overflow = planComputeVector(
        scene, computeVectorTestAdapter(),
        limits: ComputeVectorLimits(maxTileReferences: 1))
    @Expect(overflow.mode == ComputeVectorPlanMode.CpuFallback)
    @Expect(overflow.code, "tile-reference-overflow")

    let unsafeFallback = planComputeVector(
        scene, computeVectorTestAdapter(compute: false),
        limits: ComputeVectorLimits(maxCpuSampleTests: 8))
    @Expect(unsafeFallback.mode == ComputeVectorPlanMode.Rejected)
    @Expect(unsafeFallback.code, "cpu-fallback-operation-limit-exceeded")

    let unsafeOverflowFallback = planComputeVector(
        scene, computeVectorTestAdapter(),
        limits: ComputeVectorLimits(maxTileReferences: 1, maxCpuSampleTests: 8))
    @Expect(unsafeOverflowFallback.mode == ComputeVectorPlanMode.Rejected)
    @Expect(unsafeOverflowFallback.code, "cpu-fallback-operation-limit-exceeded")
}

@Test
func computeVectorTiledConformanceMatchesIndependentOracleForKnownShapes(): Unit {
    let rectangle = computeVectorRectangleScene()
    let rectangleLowered = lowerComputeVectorScene(rectangle).lowered().getOrThrow()
    let rectangleOracle = renderComputeVectorCpuOracle(rectangle)
    let rectangleTiled = renderComputeVectorTiledConformance(rectangleLowered)
    @Expect(rectangleOracle.borrowedBytes(), rectangleTiled.borrowedBytes())
    @Expect(rectangleTiled.coverageAt(0, 0), UInt8(255))
    @Expect(rectangleTiled.coverageAt(3, 3), UInt8(255))

    let triangle = ComputeVectorScene(
        "triangle", 2, 2,
        [ComputeVectorPath("triangle", [
            ComputeVectorPoint(0.0, 0.0),
            ComputeVectorPoint(2.0, 0.0),
            ComputeVectorPoint(0.0, 2.0)
        ], fillRule: ComputeVectorFillRule.EvenOdd)], tileSize: 1)
    let triangleTiled = renderComputeVectorTiledConformance(
        lowerComputeVectorScene(triangle).lowered().getOrThrow())
    @Expect(renderComputeVectorCpuOracle(triangle).borrowedBytes(), triangleTiled.borrowedBytes())
    @Expect(triangleTiled.coverageAt(0, 0), UInt8(255))
    @Expect(triangleTiled.coverageAt(1, 1), UInt8(0))
    @Expect(triangleTiled.coverageAt(1, 0), UInt8(63))
}

@Test
func computeVectorTiledConformanceMatchesConcaveAndMultiplePaths(): Unit {
    let scene = ComputeVectorScene(
        "complex", 6, 6,
        [
            ComputeVectorPath("concave", [
                ComputeVectorPoint(0.0, 0.0),
                ComputeVectorPoint(5.0, 0.0),
                ComputeVectorPoint(5.0, 2.0),
                ComputeVectorPoint(2.0, 2.0),
                ComputeVectorPoint(2.0, 5.0),
                ComputeVectorPoint(0.0, 5.0)
            ], fillRule: ComputeVectorFillRule.NonZero),
            ComputeVectorPath("island", [
                ComputeVectorPoint(4.0, 4.0),
                ComputeVectorPoint(6.0, 4.0),
                ComputeVectorPoint(6.0, 6.0),
                ComputeVectorPoint(4.0, 6.0)
            ], fillRule: ComputeVectorFillRule.EvenOdd)
        ], tileSize: 2)
    let lowered = lowerComputeVectorScene(scene).lowered().getOrThrow()
    let oracle = renderComputeVectorCpuOracle(scene)
    let tiled = renderComputeVectorTiledConformance(lowered)
    @Expect(oracle.borrowedBytes(), tiled.borrowedBytes())
}

@Test
func computeVectorConformanceReceiptGatesMismatchesAndGpuClaims(): Unit {
    let scene = computeVectorRectangleScene(width: 2, height: 2, tileSize: 1)
    let plan = planComputeVector(scene, computeVectorTestAdapter())
    let expected = renderComputeVectorTiledConformance(
        lowerComputeVectorScene(scene).lowered().getOrThrow())
    let altered = expected.borrowedBytes()
    altered[0] = UInt8(0)
    let mismatchProvider = RecordingComputeVectorGpuProvider(
        ComputeVectorProviderResult(
            true, "native-finished", ComputeVectorCoverage(2, 2, altered)))
    let mismatch = executeComputeVectorGpuCandidate(
        scene, lowerComputeVectorScene(scene).lowered().getOrThrow(), plan,
        computeVectorTestPack(), GraphicsBackend.Vulkan, 1, 1, mismatchProvider)
    @Expect(mismatch.gpuActuallyExecuted())
    @Expect(!mismatch.conformancePassed)
    @Expect(!mismatch.accepted())
    @Expect(mismatch.mismatchCount, 1)
    @Expect(mismatch.code, "coverage-mismatch")

    let invalidClaim = verifyComputeVectorCoverage(
        plan, expected, expected, ComputeVectorActualExecution.ProviderGpu)
    @Expect(invalidClaim.actualExecution == ComputeVectorActualExecution.NotExecuted)
    @Expect(invalidClaim.code, "invalid-gpu-execution-claim")
}

@Test
func computeVectorProviderCallIsRequiredForActualGpuExecutionReceipt(): Unit {
    let scene = computeVectorRectangleScene()
    let lowered = lowerComputeVectorScene(scene).lowered().getOrThrow()
    let plan = planComputeVector(scene, computeVectorTestAdapter())
    let coverage = renderComputeVectorTiledConformance(lowered)
    let provider = RecordingComputeVectorGpuProvider(
        ComputeVectorProviderResult(true, "native-finished", coverage))
    let receipt = executeComputeVectorGpuCandidate(
        scene, lowered, plan, computeVectorTestPack(), GraphicsBackend.Vulkan,
        1, 1, provider)

    @Expect(provider.callCount(), 1)
    @Expect(receipt.gpuActuallyExecuted())
    @Expect(receipt.conformancePassed)
    @Expect(receipt.accepted())
    @Expect(receipt.code, "provider-gpu-conformant")
    @Expect(receipt.providerId, "recording-compute-provider")

    let failedProvider = RecordingComputeVectorGpuProvider(
        ComputeVectorProviderResult(false, "native-failed", coverage))
    let failed = executeComputeVectorGpuCandidate(
        scene, lowered, plan, computeVectorTestPack(), GraphicsBackend.Vulkan,
        1, 2, failedProvider)
    @Expect(!failed.gpuActuallyExecuted())
    @Expect(!failed.accepted())
    @Expect(failed.code.contains("provider-execution-failed"))

    for (mode in ["missing", "stale-device", "incomplete", "wrong-pipeline"]) {
        let unprovenProvider = RecordingComputeVectorGpuProvider(
            ComputeVectorProviderResult(true, "native-finished", coverage), proofMode: mode)
        let unproven = executeComputeVectorGpuCandidate(
            scene, lowered, plan, computeVectorTestPack(), GraphicsBackend.Vulkan,
            1, 3, unprovenProvider)
        @Expect(!unproven.gpuActuallyExecuted())
        @Expect(!unproven.accepted())
        @Expect(unproven.code.contains("provider-proof-rejected"))
    }
}

@Test
func computeVectorLoweringAndOraclesRejectUnsafeBounds(): Unit {
    let scene = computeVectorRectangleScene()
    var oracleRejected = false
    try {
        let _ = renderComputeVectorCpuOracle(
            scene, limits: ComputeVectorLimits(maxCpuSampleTests: 8))
    } catch (_: IllegalArgumentException) {
        oracleRejected = true
    }
    @Expect(oracleRejected)

    var pointRejected = false
    try {
        let _ = ComputeVectorScene(
            "outside", 4, 4,
            [ComputeVectorPath("outside", [
                ComputeVectorPoint(0.0, 0.0),
                ComputeVectorPoint(5.0, 0.0),
                ComputeVectorPoint(0.0, 4.0)
            ])])
    } catch (_: IllegalArgumentException) {
        pointRejected = true
    }
    @Expect(pointRejected)
}

@Test
func computeVectorCandidateLowersThroughAotPackWithoutClaimingExecution(): Unit {
    let scene = computeVectorRectangleScene()
    let lowered = lowerComputeVectorScene(scene).lowered().getOrThrow()
    let plan = planComputeVector(scene, computeVectorTestAdapter())
    let graph = buildComputeVectorFrameGraph(
        scene, lowered, plan, computeVectorTestPack(), GraphicsBackend.Vulkan, 1, 1)
    @Expect(graph.resourceCount(), 3)
    @Expect(graph.passCount(), 1)
    @Expect(graph.passAt(0).kind == FramePassKind.OffscreenComposition)
    @Expect(graph.passAt(0).stableInputCode > 0)

    let compiled = compileFrameGraph(
        graph, FrameGraphCompilerState(), FrameGraphExecutorCapabilities())
    @Expect(compiled.ok)

    var missingPackRejected = false
    try {
        let wrongPack = PortableGpuPipelinePack(
            "wrong-pipeline",
            PortableGpuPackTarget(
                "compute-vector-test", "adapter", GraphicsBackend.Vulkan,
                GraphicsProfile.Compute3D, 1, "spirv.v1", "chui.bind-layout.v1",
                GraphicsLimits(4096, 2, 4, 2),
                [GraphicsCapability.ComputePipeline, GraphicsCapability.StorageBuffer], 1048576),
            [PortableGpuPipelineArtifact(
                "another.compute", GraphicsBackend.Vulkan, PortableGpuPipelineStage.Compute,
                "main", [UInt8(1)])],
            [PortableGpuPassRequirement(
                "compute-vector.rasterize",
                [PortableGpuPipelineUse("another.compute", PortableGpuPipelineStage.Compute)],
                1048576)])
        let _ = buildComputeVectorFrameGraph(
            scene, lowered, plan, wrongPack, GraphicsBackend.Vulkan, 1, 1)
    } catch (_: IllegalArgumentException) {
        missingPackRejected = true
    }
    @Expect(missingPackRejected)

    let otherScene = ComputeVectorScene(
        "other-rectangle", 4, 4,
        [ComputeVectorPath("rect", [
            ComputeVectorPoint(0.0, 0.0), ComputeVectorPoint(4.0, 0.0),
            ComputeVectorPoint(4.0, 4.0), ComputeVectorPoint(0.0, 4.0)
        ])], tileSize: 2)
    var exactIdentityRejected = false
    try {
        let _ = buildComputeVectorFrameGraph(
            otherScene, lowerComputeVectorScene(otherScene).lowered().getOrThrow(), plan,
            computeVectorTestPack(), GraphicsBackend.Vulkan, 1, 2)
    } catch (_: IllegalArgumentException) {
        exactIdentityRejected = true
    }
    @Expect(exactIdentityRejected)
}
