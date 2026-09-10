package chui.graphics

/** One atomic execution-group result. Codes are stable tokens, not exception text. */
protected struct FramePassExecutionResult {
    public let ok: Bool
    public let code: String

    public init(ok: Bool, code: String) {
        if (code.isEmpty()) {
            throw IllegalArgumentException("frame pass execution code must be present")
        }
        this.ok = ok
        this.code = code
    }
}

/** Final executor-session result. A failed commit must still permit one rollback call. */
protected struct FrameSessionResult {
    public let ok: Bool
    public let code: String

    public init(ok: Bool, code: String) {
        if (code.isEmpty()) {
            throw IllegalArgumentException("frame session code must be present")
        }
        this.ok = ok
        this.code = code
    }
}

/**
 * A provider-owned transaction. Implementations resolve runtime work by stable pass ID inside
 * `execute`; closures and native objects therefore stay outside graph descriptors and traces.
 */
protected interface FrameGraphExecutionSession {
    func execute(group: CompiledFramePassGroup): FramePassExecutionResult
    func commit(): FrameSessionResult
    func rollback(): Unit
}

/**
 * A live executor may own a `passId -> runtime binding` table without exposing it to the graph.
 * `begin` must clean up any provider allocation itself if it throws before returning a session.
 */
protected interface FrameGraphExecutor {
    func capabilities(): FrameGraphExecutorCapabilities
    func begin(graph: CompiledFrameGraph): FrameGraphExecutionSession
}

/** Final compile/execute truth. Planned counts never disguise partially completed work. */
protected class FrameExecutionReceipt {
    public let ok: Bool
    public let code: String
    public let scheduleHash: String
    public let trace: String
    public let completedPassCount: Int64
    public let culledPassCount: Int64
    public let mergedPassCount: Int64
    public let completedGroupCount: Int64
    public let resourceCount: Int64
    public let declaredResourceBytes: Int64
    public let redrawMode: FrameRedrawMode
    public let presentMode: FramePresentMode
    public let presentStrategy: FramePresentStrategy
    public let fallbackReason: String
    public let scheduleCacheHit: Bool

    init(
        ok: Bool,
        code: String,
        scheduleHash: String,
        trace: String,
        completedPassCount: Int64,
        culledPassCount: Int64,
        mergedPassCount: Int64,
        completedGroupCount: Int64,
        resourceCount: Int64,
        declaredResourceBytes: Int64,
        redrawMode: FrameRedrawMode,
        presentMode: FramePresentMode,
        presentStrategy: FramePresentStrategy,
        fallbackReason: String,
        scheduleCacheHit: Bool
    ) {
        this.ok = ok
        this.code = code
        this.scheduleHash = scheduleHash
        this.trace = trace
        this.completedPassCount = completedPassCount
        this.culledPassCount = culledPassCount
        this.mergedPassCount = mergedPassCount
        this.completedGroupCount = completedGroupCount
        this.resourceCount = resourceCount
        this.declaredResourceBytes = declaredResourceBytes
        this.redrawMode = redrawMode
        this.presentMode = presentMode
        this.presentStrategy = presentStrategy
        this.fallbackReason = fallbackReason
        this.scheduleCacheHit = scheduleCacheHit
    }
}

/**
 * Owns the last committed compiler state. Validation and executor failures leave it untouched.
 * Executor-visible native changes must remain staged until `FrameGraphExecutionSession.commit`.
 */
protected class FrameGraphRuntime {
    private var committedState = FrameGraphCompilerState()
    private let scheduleCache = FrameGraphScheduleCache()

    public func state(): FrameGraphCompilerState { committedState }
    public func scheduleCacheHitCount(): Int64 { scheduleCache.hitCount() }
    public func scheduleCacheMissCount(): Int64 { scheduleCache.missCount() }

    public func execute(graph: FrameGraph, executor: FrameGraphExecutor): FrameExecutionReceipt {
        let capabilityValue = try {
            executor.capabilities()
        } catch (_: Exception) {
            return rejectedBeforeCompile(graph, "executor-capabilities-failed")
        }
        let compiledResult = compileFrameGraph(
            graph, committedState, capabilityValue, scheduleCache: Some(scheduleCache))
        if (!compiledResult.ok) {
            return rejectedBeforeCompile(graph, compiledResult.code)
        }
        let compiled = match (compiledResult.graph()) {
            case Some(value) => value
            case None => return rejectedBeforeCompile(graph, "compiler-plan-missing")
        }

        var session: ?FrameGraphExecutionSession = None
        var completedPasses: Int64 = 0
        var completedGroups: Int64 = 0
        try {
            let active = executor.begin(compiled)
            session = Some(active)
            for (i in 0..compiled.executionGroupCount()) {
                let group = compiled.executionGroupAt(i)
                let result = active.execute(group)
                if (!result.ok) {
                    rollbackFrameSession(active)
                    session = None
                    return rejectedAfterCompile(
                        compiled, "executor-pass-failed", completedPasses, completedGroups)
                }
                completedPasses += group.passCount()
                completedGroups += 1
            }
            let committed = active.commit()
            if (!committed.ok) {
                rollbackFrameSession(active)
                session = None
                return rejectedAfterCompile(
                    compiled, "executor-commit-failed", completedPasses, completedGroups)
            }
            session = None
            committedState = compiled.nextState
            acceptedFrameExecution(compiled, completedPasses, completedGroups)
        } catch (_: Exception) {
            match (session) {
                case Some(active) => rollbackFrameSession(active)
                case None => ()
            }
            rejectedAfterCompile(compiled, "executor-exception", completedPasses, completedGroups)
        }
    }

    private func rejectedBeforeCompile(graph: FrameGraph, code: String): FrameExecutionReceipt {
        FrameExecutionReceipt(
            false, code, "", "", 0, 0, 0, 0,
            graph.resourceCount(), 0,
            FrameRedrawMode.Skipped, FramePresentMode.NotPresented,
            FramePresentStrategy.NotPresented, code, false)
    }

    private func rejectedAfterCompile(
        graph: CompiledFrameGraph,
        code: String,
        completedPasses: Int64,
        completedGroups: Int64
    ): FrameExecutionReceipt {
        FrameExecutionReceipt(
            false, code, graph.scheduleHash, graph.trace,
            completedPasses, graph.culledPassCount, graph.mergedPassCount, completedGroups,
            graph.source.resourceCount(), graph.declaredResourceBytes,
            graph.redrawMode, FramePresentMode.NotPresented,
            FramePresentStrategy.NotPresented, code,
            graph.scheduleCacheHit)
    }

    private func acceptedFrameExecution(
        graph: CompiledFrameGraph,
        completedPasses: Int64,
        completedGroups: Int64
    ): FrameExecutionReceipt {
        FrameExecutionReceipt(
            true, "accepted", graph.scheduleHash, graph.trace,
            completedPasses, graph.culledPassCount, graph.mergedPassCount, completedGroups,
            graph.source.resourceCount(), graph.declaredResourceBytes,
            graph.redrawMode, graph.presentMode, graph.presentStrategy, graph.fallbackReason,
            graph.scheduleCacheHit)
    }
}

private func rollbackFrameSession(session: FrameGraphExecutionSession): Unit {
    try {
        session.rollback()
    } catch (_: Exception) {
        // The caller still preserves compiler state. Native recovery belongs to the provider's
        // legacy/full-redraw fallback and must remain visible in its own receipt.
    }
}

/** Deterministic transactional executor for compiler tests; it makes no renderer or FFI call. */
protected class NullFrameGraphExecutor <: FrameGraphExecutor {
    private let capabilityValue: FrameGraphExecutorCapabilities
    private let failPassKey: String
    private let failCommit: Bool
    private var begins: Int64 = 0
    private var groupExecutions: Int64 = 0
    private var commits: Int64 = 0
    private var rollbacks: Int64 = 0
    private var transientAcquires: Int64 = 0
    private var transientReleases: Int64 = 0

    public init(
        capabilities!: FrameGraphExecutorCapabilities = FrameGraphExecutorCapabilities(
            supportsBoundedRedraw: true),
        failPassKey!: String = "",
        failCommit!: Bool = false
    ) {
        if (!failPassKey.isEmpty()) {
            let _ = FramePassId(failPassKey)
        }
        this.capabilityValue = capabilities
        this.failPassKey = failPassKey
        this.failCommit = failCommit
    }

    public func capabilities(): FrameGraphExecutorCapabilities { capabilityValue }

    public func begin(graph: CompiledFrameGraph): FrameGraphExecutionSession {
        begins += 1
        var transientCount: Int64 = 0
        for (i in 0..graph.source.resourceCount()) {
            if (graph.source.resourceAt(i).lifetime == FrameResourceLifetime.Transient) {
                transientCount += 1
            }
        }
        transientAcquires += transientCount
        NullFrameGraphExecutionSession(this, transientCount)
    }

    public func beginCount(): Int64 { begins }
    public func executeGroupCount(): Int64 { groupExecutions }
    public func commitCount(): Int64 { commits }
    public func rollbackCount(): Int64 { rollbacks }
    public func transientAcquireCount(): Int64 { transientAcquires }
    public func transientReleaseCount(): Int64 { transientReleases }

    func shouldFail(group: CompiledFramePassGroup): Bool {
        if (failPassKey.isEmpty()) { return false }
        for (i in 0..group.passCount()) {
            if (group.passAt(i).descriptor.id.key == failPassKey) { return true }
        }
        false
    }

    func recordGroupExecution(): Unit { groupExecutions += 1 }
    func recordCommit(): Unit { commits += 1 }
    func recordRollback(): Unit { rollbacks += 1 }
    func shouldFailCommit(): Bool { failCommit }
    func releaseTransients(count: Int64): Unit { transientReleases += count }
}

private class NullFrameGraphExecutionSession <: FrameGraphExecutionSession {
    private let owner: NullFrameGraphExecutor
    private let transientCount: Int64
    private var closed = false

    init(owner: NullFrameGraphExecutor, transientCount: Int64) {
        this.owner = owner
        this.transientCount = transientCount
    }

    public func execute(group: CompiledFramePassGroup): FramePassExecutionResult {
        if (closed) { return FramePassExecutionResult(false, "session-closed") }
        owner.recordGroupExecution()
        if (owner.shouldFail(group)) {
            return FramePassExecutionResult(false, "configured-pass-failure")
        }
        FramePassExecutionResult(true, "accepted")
    }

    public func commit(): FrameSessionResult {
        if (closed) { return FrameSessionResult(false, "session-closed") }
        owner.recordCommit()
        if (owner.shouldFailCommit()) {
            return FrameSessionResult(false, "configured-commit-failure")
        }
        closeAndRelease()
        FrameSessionResult(true, "accepted")
    }

    public func rollback(): Unit {
        if (closed) { return }
        owner.recordRollback()
        closeAndRelease()
    }

    private func closeAndRelease(): Unit {
        if (closed) { return }
        closed = true
        owner.releaseTransients(transientCount)
    }
}
