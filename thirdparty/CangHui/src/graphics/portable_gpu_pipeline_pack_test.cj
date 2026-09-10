package chui.graphics

private func portableTestAdapter(
    backend!: GraphicsBackend = GraphicsBackend.Metal,
    compute!: Bool = false
): GraphicsAdapterCapabilities {
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
        "portable-test", "adapter", backend,
        if (compute) { GraphicsProfile.Compute3D } else { GraphicsProfile.Core3D },
        GraphicsLimits(8192, 4, 8, 4), capabilities: values)
}

private func portableTestSnapshot(
    backend!: GraphicsBackend = GraphicsBackend.Metal,
    generation!: Int64 = 7,
    formatAbi!: String = "metal-lib.v3",
    layoutAbi!: String = "chui.bind-layout.v1",
    compute!: Bool = false,
    maximumBytes!: Int64 = 64
): PortableGpuDeviceSnapshot {
    PortableGpuDeviceSnapshot(
        "recording-portable-gpu", portableTestAdapter(backend: backend, compute: compute),
        generation, formatAbi, layoutAbi,
        FrameGraphExecutorCapabilities(
            supportsBoundedRedraw: true,
            supportsExtendedDynamicRange: true,
            maxDeclaredResourceBytes: maximumBytes))
}

private func portableTestTarget(
    backend!: GraphicsBackend = GraphicsBackend.Metal,
    generation!: Int64 = 7,
    compute!: Bool = false,
    maximumBytes!: Int64 = 64
): PortableGpuPackTarget {
    PortableGpuPackTarget(
        "portable-test", "adapter", backend,
        if (compute) { GraphicsProfile.Compute3D } else { GraphicsProfile.Core3D },
        generation, if (backend == GraphicsBackend.Metal) { "metal-lib.v3" } else { "spirv.v1" },
        "chui.bind-layout.v1", GraphicsLimits(4096, 2, 4, 2),
        if (compute) {
            [GraphicsCapability.ComputePipeline, GraphicsCapability.StorageBuffer]
        } else {
            [GraphicsCapability.RenderPipeline]
        },
        maximumBytes)
}

private func portableTestArtifact(
    id: String,
    backend!: GraphicsBackend = GraphicsBackend.Metal,
    stage!: PortableGpuPipelineStage = PortableGpuPipelineStage.Vertex,
    seed!: UInt8 = UInt8(1),
    layoutAbi!: String = "chui.bind-layout.v1",
    entryPoint!: String = "main"
): PortableGpuPipelineArtifact {
    PortableGpuPipelineArtifact(
        id, backend, stage, entryPoint, [seed, seed + UInt8(1), seed + UInt8(2)],
        layoutAbi: layoutAbi)
}

private func portableTestRequirements(): Array<PortableGpuPassRequirement> {
    [
        PortableGpuPassRequirement("portable.draw", [
            PortableGpuPipelineUse("basic.vertex", PortableGpuPipelineStage.Vertex),
            PortableGpuPipelineUse("basic.fragment", PortableGpuPipelineStage.Fragment)
        ], 12),
        PortableGpuPassRequirement("portable.present", [], 8)
    ]
}

private func portableTestPack(
    backend!: GraphicsBackend = GraphicsBackend.Metal,
    generation!: Int64 = 7,
    maximumBytes!: Int64 = 64
): PortableGpuPipelinePack {
    PortableGpuPipelinePack(
        "builtin", portableTestTarget(
            backend: backend, generation: generation, maximumBytes: maximumBytes),
        [
            portableTestArtifact("basic.vertex", backend: backend),
            portableTestArtifact(
                "basic.fragment", backend: backend,
                stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
        ],
        portableTestRequirements())
}

private func portableTestGraph(frameId!: Int64 = 1): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("portable.input", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported, declaredBytes: 4)
    let output = FrameResourceDescriptor(
        FrameResourceId("portable.output", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent, declaredBytes: 8)
    let draw = FramePassDescriptor(
        FramePassId("portable.draw"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [output.id], stableInputCode: 71)
    let present = FramePassDescriptor(
        FramePassId("portable.present"), 1, FramePassKind.Present,
        reads: [output.id], dependsOn: [draw.id], stableInputCode: 72)
    FrameGraph("portable", 1, frameId, 32, 32, [input, output], [draw, present])
}

private func portableCompile(graph: FrameGraph): CompiledFrameGraph {
    compileFrameGraph(
        graph, FrameGraphCompilerState(),
        FrameGraphExecutorCapabilities(
            supportsBoundedRedraw: true,
            supportsExtendedDynamicRange: true,
            maxDeclaredResourceBytes: 64)).graph().getOrThrow()
}

@Test
func portableGpuPipelineManifestIsOrderIndependentAndCacheKeyIsOnlyAHint(): Unit {
    let vertex = portableTestArtifact("basic.vertex")
    let fragment = portableTestArtifact(
        "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
    let first = PortableGpuPipelinePack(
        "builtin", portableTestTarget(), [vertex, fragment], portableTestRequirements())
    let second = PortableGpuPipelinePack(
        "builtin", portableTestTarget(), [fragment, vertex], [
            PortableGpuPassRequirement("portable.present", [], 8),
            PortableGpuPassRequirement("portable.draw", [
                PortableGpuPipelineUse("basic.vertex", PortableGpuPipelineStage.Vertex),
                PortableGpuPipelineUse("basic.fragment", PortableGpuPipelineStage.Fragment)
            ], 12)
        ])

    @Expect(first.manifest, second.manifest)
    @Expect(first.cacheKey, second.cacheKey)
    @Expect(first.totalBytes, 6)
    @Expect(first.manifest.contains("protocol=canghui.gpu-pipeline-pack.v2"))
    @Expect(first.manifest.contains("metal-lib.v3"))
    @Expect(first.manifest.contains("chui.bind-layout.v1"))
    @Expect(first.manifest.contains("pass=portable.draw,12"))
    @Expect(!first.manifest.contains("1,2,3"))
    @Expect(first.exactlyMatches(second))
}

@Test
func portableGpuArtifactsCopyPayloadAndUseExactContentEquality(): Unit {
    let payload = [UInt8(1), UInt8(2), UInt8(3)]
    let artifact = PortableGpuPipelineArtifact(
        "copy.vertex", GraphicsBackend.Metal, PortableGpuPipelineStage.Vertex, "main", payload)
    payload[0] = UInt8(99)
    let same = PortableGpuPipelineArtifact(
        "copy.vertex", GraphicsBackend.Metal, PortableGpuPipelineStage.Vertex, "main",
        [UInt8(1), UInt8(2), UInt8(3)])
    let changed = PortableGpuPipelineArtifact(
        "copy.vertex", GraphicsBackend.Metal, PortableGpuPipelineStage.Vertex, "main",
        [UInt8(99), UInt8(2), UInt8(3)])

    @Expect(artifact.exactlyMatches(same))
    @Expect(!artifact.exactlyMatches(changed))
    @Expect(artifact.borrowedBytes(), [UInt8(1), UInt8(2), UInt8(3)])
}

@Test
func portableGpuPipelinePackRejectsMissingPipelinesAndLayoutMismatch(): Unit {
    var missingRejected = false
    try {
        let _ = PortableGpuPipelinePack(
            "missing", portableTestTarget(), [portableTestArtifact("basic.vertex")],
            portableTestRequirements())
    } catch (_: IllegalArgumentException) {
        missingRejected = true
    }
    @Expect(missingRejected)

    var layoutRejected = false
    try {
        let _ = PortableGpuPipelinePack(
            "layout", portableTestTarget(), [
                portableTestArtifact("basic.vertex", layoutAbi: "wrong-layout"),
                portableTestArtifact(
                    "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
            ], portableTestRequirements())
    } catch (_: IllegalArgumentException) {
        layoutRejected = true
    }
    @Expect(layoutRejected)

    var ambiguousIdentityRejected = false
    try {
        let _ = PortableGpuPipelinePack(
            "ambiguous", portableTestTarget(), [
                portableTestArtifact("basic.vertex"),
                portableTestArtifact("basic.vertex", entryPoint: "alternate"),
                portableTestArtifact(
                    "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
            ], portableTestRequirements())
    } catch (_: IllegalArgumentException) {
        ambiguousIdentityRejected = true
    }
    @Expect(ambiguousIdentityRejected)

    var exactVariantRequired = false
    try {
        let _ = PortableGpuPipelinePack(
            "wrong-entry", portableTestTarget(), [
                portableTestArtifact("basic.vertex"),
                portableTestArtifact(
                    "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
            ], [
                PortableGpuPassRequirement("portable.draw", [
                    PortableGpuPipelineUse(
                        "basic.vertex", PortableGpuPipelineStage.Vertex,
                        entryPoint: "alternate"),
                    PortableGpuPipelineUse("basic.fragment", PortableGpuPipelineStage.Fragment)
                ], 12),
                PortableGpuPassRequirement("portable.present", [], 8)
            ])
    } catch (_: IllegalArgumentException) {
        exactVariantRequired = true
    }
    @Expect(exactVariantRequired)
}

private class RecordingPortableGpuDevice <: PortableGpuDevice {
    private let snapshotValue: PortableGpuDeviceSnapshot
    private let failPass: String
    private let failCommit: Bool
    private var begins: Int64 = 0
    private var executions: Int64 = 0
    private var commits: Int64 = 0
    private var rollbacks: Int64 = 0
    private var receivedExactPack = false
    private let expectedPack: ?PortableGpuPipelinePack

    init(
        snapshot!: PortableGpuDeviceSnapshot = portableTestSnapshot(),
        expectedPack!: ?PortableGpuPipelinePack = None,
        failPass!: String = "",
        failCommit!: Bool = false
    ) {
        this.snapshotValue = snapshot
        this.expectedPack = expectedPack
        this.failPass = failPass
        this.failCommit = failCommit
    }

    public func snapshot(): PortableGpuDeviceSnapshot { snapshotValue }

    public func begin(
        _: CompiledFrameGraph,
        pack: PortableGpuPipelinePack,
        expectedSnapshot: PortableGpuDeviceSnapshot
    ): PortableGpuExecutionSession {
        if (!portableGpuDeviceSnapshotsExactlyMatch(expectedSnapshot, snapshotValue)) {
            throw IllegalStateException("provider rejected stale portable GPU snapshot")
        }
        begins += 1
        receivedExactPack = match (expectedPack) {
            case Some(value) => pack.exactlyMatches(value)
            case None => true
        }
        RecordingPortableGpuSession(this)
    }

    func shouldFail(group: CompiledFramePassGroup): Bool {
        if (failPass.isEmpty()) { return false }
        for (i in 0..group.passCount()) {
            if (group.passAt(i).descriptor.id.key == failPass) { return true }
        }
        false
    }

    func recordExecution(): Unit { executions += 1 }
    func recordCommit(): Unit { commits += 1 }
    func recordRollback(): Unit { rollbacks += 1 }
    func commitFails(): Bool { failCommit }
    func beginCount(): Int64 { begins }
    func executionCount(): Int64 { executions }
    func commitCount(): Int64 { commits }
    func rollbackCount(): Int64 { rollbacks }
    func packWasExact(): Bool { receivedExactPack }
}

private class ChangingPortableGpuDevice <: PortableGpuDevice {
    private let initial: PortableGpuDeviceSnapshot
    private let changed: PortableGpuDeviceSnapshot
    private let changeAfter: Int64
    private var snapshots: Int64 = 0
    private var begins: Int64 = 0

    init(
        initial: PortableGpuDeviceSnapshot,
        changed: PortableGpuDeviceSnapshot,
        changeAfter: Int64
    ) {
        this.initial = initial
        this.changed = changed
        this.changeAfter = changeAfter
    }

    public func snapshot(): PortableGpuDeviceSnapshot {
        snapshots += 1
        if (snapshots > changeAfter) { changed } else { initial }
    }

    public func begin(
        _: CompiledFrameGraph,
        _: PortableGpuPipelinePack,
        expectedSnapshot: PortableGpuDeviceSnapshot
    ): PortableGpuExecutionSession {
        begins += 1
        if (!portableGpuDeviceSnapshotsExactlyMatch(expectedSnapshot, snapshot())) {
            throw IllegalStateException("provider rejected changed portable GPU snapshot")
        }
        RecordingPortableGpuSession(RecordingPortableGpuDevice())
    }

    func beginCount(): Int64 { begins }
}

private class RecordingPortableGpuSession <: PortableGpuExecutionSession {
    private let owner: RecordingPortableGpuDevice
    private var closed = false

    init(owner: RecordingPortableGpuDevice) { this.owner = owner }

    public func execute(group: CompiledFramePassGroup): FramePassExecutionResult {
        if (closed) { return FramePassExecutionResult(false, "session-closed") }
        owner.recordExecution()
        if (owner.shouldFail(group)) {
            return FramePassExecutionResult(false, "configured-pass-failure")
        }
        FramePassExecutionResult(true, "accepted")
    }

    public func commit(): FrameSessionResult {
        if (closed) { return FrameSessionResult(false, "session-closed") }
        owner.recordCommit()
        if (owner.commitFails()) {
            return FrameSessionResult(false, "configured-commit-failure")
        }
        closed = true
        FrameSessionResult(true, "accepted")
    }

    public func rollback(): Unit {
        if (closed) { return }
        closed = true
        owner.recordRollback()
    }
}

@Test
func portableGpuExecutorValidatesThenCommitsExactPackThroughFrameRuntime(): Unit {
    let pack = portableTestPack()
    let device = RecordingPortableGpuDevice(expectedPack: Some(pack))
    let executor = PortableGpuFrameGraphExecutor(device, pack)
    let runtime = FrameGraphRuntime()
    let receipt = runtime.execute(portableTestGraph(), executor)

    @Expect(receipt.ok)
    @Expect(runtime.state().frameId, 1)
    @Expect(device.beginCount(), 1)
    @Expect(device.executionCount(), 2)
    @Expect(device.commitCount(), 1)
    @Expect(device.rollbackCount(), 0)
    @Expect(device.packWasExact())
    @Expect(executor.pipelineCacheHint().contains("hint"))
    @Expect(executor.selectedBackend() == GraphicsBackend.Metal)
}

@Test
func portableGpuExecutorFailsBeforeBeginForStaleAbiCapabilityAndBudgets(): Unit {
    let graph = portableCompile(portableTestGraph())

    let stale = PortableGpuFrameGraphExecutor(
        RecordingPortableGpuDevice(snapshot: portableTestSnapshot(generation: 8)), portableTestPack())
    @Expect(stale.compatibility(graph).code, "stale-capability-generation")

    let wrongFormat = PortableGpuFrameGraphExecutor(
        RecordingPortableGpuDevice(snapshot: portableTestSnapshot(formatAbi: "metal-lib.v4")),
        portableTestPack())
    @Expect(wrongFormat.compatibility(graph).code, "artifact-format-abi-mismatch")

    let wrongLayout = PortableGpuFrameGraphExecutor(
        RecordingPortableGpuDevice(snapshot: portableTestSnapshot(layoutAbi: "layout.v2")),
        portableTestPack())
    @Expect(wrongLayout.compatibility(graph).code, "bind-layout-abi-mismatch")

    let overDeviceBudget = PortableGpuFrameGraphExecutor(
        RecordingPortableGpuDevice(snapshot: portableTestSnapshot(maximumBytes: 8)),
        portableTestPack())
    @Expect(overDeviceBudget.compatibility(graph).code, "frame-resource-budget-exceeded")

    let tooSmallPass = PortableGpuPipelinePack(
        "small-pass", portableTestTarget(), [
            portableTestArtifact("basic.vertex"),
            portableTestArtifact(
                "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
        ], [
            PortableGpuPassRequirement("portable.draw", [
                PortableGpuPipelineUse("basic.vertex", PortableGpuPipelineStage.Vertex),
                PortableGpuPipelineUse("basic.fragment", PortableGpuPipelineStage.Fragment)
            ], 11),
            PortableGpuPassRequirement("portable.present", [], 8)
        ])
    let passBudget = PortableGpuFrameGraphExecutor(RecordingPortableGpuDevice(), tooSmallPass)
    @Expect(passBudget.compatibility(graph).code, "pass-resource-budget-exceeded")
}

@Test
func portableGpuExecutorFailsClosedWhenPassRequirementIsMissing(): Unit {
    let incomplete = PortableGpuPipelinePack(
        "incomplete", portableTestTarget(), [
            portableTestArtifact("basic.vertex"),
            portableTestArtifact(
                "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
        ], [PortableGpuPassRequirement("portable.draw", [
            PortableGpuPipelineUse("basic.vertex", PortableGpuPipelineStage.Vertex),
            PortableGpuPipelineUse("basic.fragment", PortableGpuPipelineStage.Fragment)
        ], 12)])
    let device = RecordingPortableGpuDevice()
    let runtime = FrameGraphRuntime()
    let receipt = runtime.execute(
        portableTestGraph(), PortableGpuFrameGraphExecutor(device, incomplete))

    @Expect(!receipt.ok)
    @Expect(receipt.code, "executor-exception")
    @Expect(device.beginCount(), 0)
    @Expect(runtime.state().frameId, 0)
}

@Test
func portableGpuExecutorRejectsInvalidPassPipelineShapeAndSnapshotToctou(): Unit {
    let noDrawPipelines = PortableGpuPipelinePack(
        "empty-draw", portableTestTarget(), [
            portableTestArtifact("basic.vertex"),
            portableTestArtifact(
                "basic.fragment", stage: PortableGpuPipelineStage.Fragment, seed: UInt8(7))
        ], [
            PortableGpuPassRequirement("portable.draw", [], 12),
            PortableGpuPassRequirement("portable.present", [], 8)
        ])
    let emptyDevice = RecordingPortableGpuDevice()
    let emptyReceipt = PortableGpuFrameGraphExecutor(
        emptyDevice, noDrawPipelines).compatibility(portableCompile(portableTestGraph()))
    @Expect(!emptyReceipt.ok)
    @Expect(emptyReceipt.code, "pass-pipeline-requirement-invalid")
    @Expect(emptyDevice.beginCount(), 0)

    let changing = ChangingPortableGpuDevice(
        portableTestSnapshot(), portableTestSnapshot(generation: 8), 2)
    let runtimeReceipt = FrameGraphRuntime().execute(
        portableTestGraph(), PortableGpuFrameGraphExecutor(changing, portableTestPack()))
    @Expect(!runtimeReceipt.ok)
    @Expect(changing.beginCount(), 0)
}

@Test
func portableGpuExecutorPreservesRollbackForProviderFailures(): Unit {
    let passDevice = RecordingPortableGpuDevice(failPass: "portable.present")
    let passReceipt = FrameGraphRuntime().execute(
        portableTestGraph(), PortableGpuFrameGraphExecutor(passDevice, portableTestPack()))
    @Expect(!passReceipt.ok)
    @Expect(passDevice.rollbackCount(), 1)

    let commitDevice = RecordingPortableGpuDevice(failCommit: true)
    let commitReceipt = FrameGraphRuntime().execute(
        portableTestGraph(), PortableGpuFrameGraphExecutor(commitDevice, portableTestPack()))
    @Expect(!commitReceipt.ok)
    @Expect(commitDevice.commitCount(), 1)
    @Expect(commitDevice.rollbackCount(), 1)
}
