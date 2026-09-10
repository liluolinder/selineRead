package chui.graphics

private func executorFrameGraph(frameId!: Int64 = 1): FrameGraph {
    let input = FrameResourceDescriptor(
        FrameResourceId("executor.input", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let temporary = FrameResourceDescriptor(
        FrameResourceId("executor.temporary", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Transient, declaredBytes: 4096)
    let output = FrameResourceDescriptor(
        FrameResourceId("executor.output", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let ui = FramePassDescriptor(
        FramePassId("ui.main"), 0, FramePassKind.Ui2D,
        reads: [input.id], writes: [temporary.id],
        bounds: Some(FrameDamageRect(0, 0, 64, 64)), stableInputCode: 51)
    let copy = FramePassDescriptor(
        FramePassId("copy.main"), 1, FramePassKind.CopyResolve,
        reads: [temporary.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 64, 64)), stableInputCode: 52)
    let present = FramePassDescriptor(
        FramePassId("present.main"), 2, FramePassKind.Present,
        reads: [output.id], stableInputCode: 53)
    FrameGraph("executor", 1, frameId, 64, 64,
        [input, temporary, output], [ui, copy, present])
}

@Test
func frameGraphRuntimeCommitsOnlyAfterAllGroupsAndReleasesTransientsOnce(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    let receipt = runtime.execute(executorFrameGraph(), executor)

    @Expect(receipt.ok)
    @Expect(receipt.code, "accepted")
    @Expect(receipt.completedPassCount, 3)
    @Expect(receipt.completedGroupCount, 3)
    @Expect(receipt.resourceCount, 3)
    @Expect(receipt.declaredResourceBytes, 4096)
    @Expect(executor.beginCount(), 1)
    @Expect(executor.executeGroupCount(), 3)
    @Expect(executor.commitCount(), 1)
    @Expect(executor.rollbackCount(), 0)
    @Expect(executor.transientAcquireCount(), 1)
    @Expect(executor.transientReleaseCount(), 1)
    @Expect(runtime.state().frameId, 1)
    @Expect(!receipt.trace.isEmpty())
    @Expect(receipt.trace.toArray().size <= executorFrameGraph().limits.maxTraceBytes)
    @Expect(!receipt.scheduleCacheHit)
    @Expect(runtime.scheduleCacheMissCount(), 1)
    @Expect(runtime.scheduleCacheHitCount(), 0)
}

@Test
func frameGraphRuntimeReusesOnlyTheImmutableScheduleAndStillRecompilesDynamicState(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = NullFrameGraphExecutor()
    let first = runtime.execute(executorFrameGraph(frameId: 1), executor)
    let second = runtime.execute(executorFrameGraph(frameId: 2), executor)

    @Expect(first.ok)
    @Expect(second.ok)
    @Expect(!first.scheduleCacheHit)
    @Expect(second.scheduleCacheHit)
    @Expect(runtime.scheduleCacheMissCount(), 1)
    @Expect(runtime.scheduleCacheHitCount(), 1)
    @Expect(!second.trace.contains("scheduleCacheHit"))
    // A hit owns order only: frame state and the frame-specific schedule receipt still advance.
    @Expect(runtime.state().frameId, 2)
    @Expect(first.scheduleHash != second.scheduleHash)

    let changedOutput = FrameResourceDescriptor(
        FrameResourceId("executor.changed", 1), FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let changedPass = FramePassDescriptor(
        FramePassId("changed.main"), 0, FramePassKind.Ui2D,
        writes: [changedOutput.id], bounds: Some(FrameDamageRect(0, 0, 64, 64)))
    let changed = runtime.execute(
        FrameGraph("executor", 1, 3, 64, 64, [changedOutput], [changedPass]), executor)
    @Expect(changed.ok)
    @Expect(!changed.scheduleCacheHit)
    @Expect(runtime.scheduleCacheMissCount(), 2)
}

@Test
func frameGraphRuntimeRollsBackPassFailureWithoutAdvancingState(): Unit {
    let runtime = FrameGraphRuntime()
    let failing = NullFrameGraphExecutor(failPassKey: "copy.main")
    let rejected = runtime.execute(executorFrameGraph(), failing)

    @Expect(!rejected.ok)
    @Expect(rejected.code, "executor-pass-failed")
    @Expect(rejected.completedPassCount, 1)
    @Expect(rejected.completedGroupCount, 1)
    @Expect(rejected.presentMode == FramePresentMode.NotPresented)
    @Expect(rejected.presentStrategy == FramePresentStrategy.NotPresented)
    @Expect(failing.beginCount(), 1)
    @Expect(failing.executeGroupCount(), 2)
    @Expect(failing.commitCount(), 0)
    @Expect(failing.rollbackCount(), 1)
    @Expect(failing.transientAcquireCount(), 1)
    @Expect(failing.transientReleaseCount(), 1)
    @Expect(runtime.state().frameId, 0)

    let recovery = NullFrameGraphExecutor()
    @Expect(runtime.execute(executorFrameGraph(), recovery).ok)
    @Expect(runtime.state().frameId, 1)
}

@Test
func frameGraphRuntimeRollsBackCommitFailureWithoutDoubleRelease(): Unit {
    let runtime = FrameGraphRuntime()
    let failing = NullFrameGraphExecutor(failCommit: true)
    let rejected = runtime.execute(executorFrameGraph(), failing)

    @Expect(!rejected.ok)
    @Expect(rejected.code, "executor-commit-failed")
    @Expect(rejected.completedPassCount, 3)
    @Expect(rejected.presentMode == FramePresentMode.NotPresented)
    @Expect(rejected.presentStrategy == FramePresentStrategy.NotPresented)
    @Expect(failing.commitCount(), 1)
    @Expect(failing.rollbackCount(), 1)
    @Expect(failing.transientAcquireCount(), 1)
    @Expect(failing.transientReleaseCount(), 1)
    @Expect(runtime.state().frameId, 0)
}

@Test
func frameGraphRuntimeNeverBeginsExecutorForCompilerRejection(): Unit {
    let output = FrameResourceDescriptor(
        FrameResourceId("invalid.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent)
    let invalid = FramePassDescriptor(
        FramePassId("invalid.pass"), 0, FramePassKind.OffscreenComposition,
        reads: [FrameResourceId("invalid.missing", 1)], writes: [output.id])
    let graph = FrameGraph("invalid", 1, 1, 32, 32, [output], [invalid])
    let executor = NullFrameGraphExecutor()
    let receipt = FrameGraphRuntime().execute(graph, executor)

    @Expect(!receipt.ok)
    @Expect(receipt.code, "unknown-resource")
    @Expect(executor.beginCount(), 0)
    @Expect(executor.executeGroupCount(), 0)
    @Expect(executor.commitCount(), 0)
    @Expect(executor.rollbackCount(), 0)
}

private class ThrowingFrameGraphExecutor <: FrameGraphExecutor {
    private var rollbacks: Int64 = 0

    public func capabilities(): FrameGraphExecutorCapabilities {
        FrameGraphExecutorCapabilities(supportsBoundedRedraw: true)
    }

    public func begin(_: CompiledFrameGraph): FrameGraphExecutionSession {
        ThrowingFrameGraphExecutionSession(this)
    }

    public func rollbackCount(): Int64 { rollbacks }
    func recordRollback(): Unit { rollbacks += 1 }
}

private class ThrowingFrameGraphExecutionSession <: FrameGraphExecutionSession {
    private let owner: ThrowingFrameGraphExecutor

    init(owner: ThrowingFrameGraphExecutor) { this.owner = owner }

    public func execute(_: CompiledFramePassGroup): FramePassExecutionResult {
        throw IllegalStateException("configured executor exception")
    }

    public func commit(): FrameSessionResult {
        FrameSessionResult(true, "accepted")
    }

    public func rollback(): Unit { owner.recordRollback() }
}

@Test
func frameGraphRuntimeRollsBackExecutorExceptionWithoutAdvancingState(): Unit {
    let runtime = FrameGraphRuntime()
    let executor = ThrowingFrameGraphExecutor()
    let receipt = runtime.execute(executorFrameGraph(), executor)

    @Expect(!receipt.ok)
    @Expect(receipt.code, "executor-exception")
    @Expect(receipt.completedPassCount, 0)
    @Expect(receipt.completedGroupCount, 0)
    @Expect(executor.rollbackCount(), 1)
    @Expect(runtime.state().frameId, 0)
}
