package chui.graphics

import std.collection.ArrayList

private class CommittedFrameResource {
    let id: FrameResourceId
    let descriptorFingerprint: String

    init(descriptor: FrameResourceDescriptor) {
        this.id = descriptor.id
        this.descriptorFingerprint = frameResourceDescriptorFingerprint(descriptor)
    }
}

private class CommittedFramePass {
    let id: FramePassId
    let stableInputCode: Int64
    let outputFingerprint: String

    init(id: FramePassId, stableInputCode: Int64, outputFingerprint: String) {
        this.id = id
        this.stableInputCode = stableInputCode
        this.outputFingerprint = outputFingerprint
    }
}

/** State is replaced only after an executor commits a whole frame. */
protected class FrameGraphCompilerState {
    public let surfaceKey: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    private let resources = ArrayList<CommittedFrameResource>()
    private let passes = ArrayList<CommittedFramePass>()

    public init() {
        this.surfaceKey = ""
        this.surfaceGeneration = 0
        this.frameId = 0
    }

    init(
        surfaceKey: String,
        surfaceGeneration: Int64,
        frameId: Int64,
        resourceValues: Array<FrameResourceDescriptor>,
        passIds: Array<FramePassId>,
        passStableCodes: Array<Int64>,
        passOutputFingerprints: Array<String>
    ) {
        if (passIds.size != passStableCodes.size ||
            passIds.size != passOutputFingerprints.size) {
            throw IllegalArgumentException("committed frame pass arrays must have equal lengths")
        }
        this.surfaceKey = surfaceKey
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
        for (value in resourceValues) { resources.add(CommittedFrameResource(value)) }
        for (i in 0..passIds.size) {
            passes.add(CommittedFramePass(
                passIds[i], passStableCodes[i], passOutputFingerprints[i]))
        }
    }

    public func resourceCount(): Int64 { resources.size }
    public func passCount(): Int64 { passes.size }

    func latestGeneration(key: String): Int64 {
        var latest: Int64 = 0
        for (value in resources) {
            if (value.id.key == key && value.id.generation > latest) {
                latest = value.id.generation
            }
        }
        latest
    }

    func containsResourceIdentity(id: FrameResourceId): Bool {
        for (value in resources) {
            if (value.id == id) { return true }
        }
        false
    }

    func resourceMatches(descriptor: FrameResourceDescriptor): Bool {
        let fingerprint = frameResourceDescriptorFingerprint(descriptor)
        for (value in resources) {
            if (value.id == descriptor.id) {
                return value.descriptorFingerprint == fingerprint
            }
        }
        false
    }

    func passMatches(
        id: FramePassId,
        stableInputCode: Int64,
        outputFingerprint: String
    ): Bool {
        if (stableInputCode <= 0) { return false }
        for (value in passes) {
            if (value.id == id) {
                return value.stableInputCode == stableInputCode &&
                    value.outputFingerprint == outputFingerprint
            }
        }
        false
    }
}

/** One pass after validation, stable scheduling and damage propagation. */
protected class CompiledFramePass {
    public let descriptor: FramePassDescriptor
    public let damage: DamageRegion
    public let culled: Bool
    public let outputCode: Int64
    /** Exact canonical identity used for correctness; `outputCode` is trace display only. */
    public let outputFingerprint: String

    init(
        descriptor: FramePassDescriptor,
        damage: DamageRegion,
        culled: Bool,
        outputCode: Int64,
        outputFingerprint: String
    ) {
        this.descriptor = descriptor
        this.damage = damage
        this.culled = culled
        this.outputCode = outputCode
        this.outputFingerprint = outputFingerprint
    }
}

/** Adjacent compatible passes form one executor call while retaining member order. */
protected class CompiledFramePassGroup {
    private let members = ArrayList<CompiledFramePass>()
    private var combinedDamage: DamageRegion

    init(first: CompiledFramePass) {
        members.add(first)
        combinedDamage = first.damage
    }

    func append(value: CompiledFramePass, maximumRectangles: Int64): Unit {
        members.add(value)
        combinedDamage = combineFrameDamage(combinedDamage, value.damage, maximumRectangles)
    }

    public func passCount(): Int64 { members.size }
    public func passAt(index: Int64): CompiledFramePass { members[index] }
    public func damage(): DamageRegion { combinedDamage }
}

protected class CompiledFrameGraph {
    public let source: FrameGraph
    public let scheduleHash: String
    public let trace: String
    public let redrawMode: FrameRedrawMode
    public let presentMode: FramePresentMode
    public let presentStrategy: FramePresentStrategy
    public let fallbackReason: String
    public let scheduleCacheHit: Bool
    public let declaredResourceBytes: Int64
    public let executedPassCount: Int64
    public let culledPassCount: Int64
    public let mergedPassCount: Int64
    public let nextState: FrameGraphCompilerState
    private let scheduledPasses = ArrayList<CompiledFramePass>()
    private let executionGroups = ArrayList<CompiledFramePassGroup>()

    init(
        source: FrameGraph,
        scheduleHash: String,
        trace: String,
        redrawMode: FrameRedrawMode,
        presentMode: FramePresentMode,
        presentStrategy: FramePresentStrategy,
        fallbackReason: String,
        scheduleCacheHit: Bool,
        declaredResourceBytes: Int64,
        scheduled: Array<CompiledFramePass>,
        groups: Array<CompiledFramePassGroup>,
        executedPassCount: Int64,
        culledPassCount: Int64,
        mergedPassCount: Int64,
        nextState: FrameGraphCompilerState
    ) {
        this.source = source
        this.scheduleHash = scheduleHash
        this.trace = trace
        this.redrawMode = redrawMode
        this.presentMode = presentMode
        this.presentStrategy = presentStrategy
        this.fallbackReason = fallbackReason
        this.scheduleCacheHit = scheduleCacheHit
        this.declaredResourceBytes = declaredResourceBytes
        for (value in scheduled) { scheduledPasses.add(value) }
        for (value in groups) { executionGroups.add(value) }
        this.executedPassCount = executedPassCount
        this.culledPassCount = culledPassCount
        this.mergedPassCount = mergedPassCount
        this.nextState = nextState
    }

    public func scheduledPassCount(): Int64 { scheduledPasses.size }
    public func scheduledPassAt(index: Int64): CompiledFramePass { scheduledPasses[index] }
    public func executionGroupCount(): Int64 { executionGroups.size }
    public func executionGroupAt(index: Int64): CompiledFramePassGroup { executionGroups[index] }
}

/** A compiler rejection never carries a partial plan. */
protected class FrameCompileResult {
    public let ok: Bool
    public let code: String
    private let compiled: ?CompiledFrameGraph

    private init(ok: Bool, code: String, compiled: ?CompiledFrameGraph) {
        this.ok = ok
        this.code = code
        this.compiled = compiled
    }

    static func accepted(value: CompiledFrameGraph): FrameCompileResult {
        FrameCompileResult(true, "accepted", Some(value))
    }

    static func rejected(code: String): FrameCompileResult {
        FrameCompileResult(false, code, None)
    }

    public func graph(): ?CompiledFrameGraph { compiled }
}

private class FrameGraphValidation {
    let ok: Bool
    let code: String
    let producers: Array<Int64>
    let edgeFrom: Array<Int64>
    let edgeTo: Array<Int64>
    let declaredResourceBytes: Int64

    init(
        ok: Bool,
        code: String,
        producers: Array<Int64>,
        edgeFrom: Array<Int64>,
        edgeTo: Array<Int64>,
        declaredResourceBytes: Int64
    ) {
        this.ok = ok
        this.code = code
        this.producers = producers
        this.edgeFrom = edgeFrom
        this.edgeTo = edgeTo
        this.declaredResourceBytes = declaredResourceBytes
    }

    static func rejected(code: String): FrameGraphValidation {
        FrameGraphValidation(false, code, [], [], [], 0)
    }
}

protected class FrameGraphScheduleResolution {
    let order: Array<Int64>
    let hit: Bool

    init(order: Array<Int64>, hit: Bool) {
        this.order = order
        this.hit = hit
    }
}

/**
 * One-entry owner-thread cache for immutable graph topology. Validation still runs on
 * every frame, so state generations, capabilities, resource budgets and dynamic damage
 * can never be hidden by a hit. Only the stable topological ordering is reused.
 */
protected class FrameGraphScheduleCache {
    private var key = ""
    private var order: Array<Int64> = []
    private var hits: Int64 = 0
    private var misses: Int64 = 0

    func resolve(
        graph: FrameGraph,
        edgeFrom: Array<Int64>,
        edgeTo: Array<Int64>
    ): FrameGraphScheduleResolution {
        let nextKey = frameGraphTopologyKey(graph)
        if (!key.isEmpty() && key == nextKey && order.size == graph.passCount()) {
            hits += 1
            return FrameGraphScheduleResolution(order, true)
        }
        let nextOrder = stableTopologicalFrameOrder(graph.passCount(), edgeFrom, edgeTo)
        key = nextKey
        order = nextOrder
        misses += 1
        FrameGraphScheduleResolution(nextOrder, false)
    }

    public func hitCount(): Int64 { hits }
    public func missCount(): Int64 { misses }

    public func clear(): Unit {
        key = ""
        order = []
    }
}

/** Pure compile: it does not begin an executor and cannot mutate committed state. */
protected func compileFrameGraph(
    graph: FrameGraph,
    state: FrameGraphCompilerState,
    capabilities: FrameGraphExecutorCapabilities,
    scheduleCache!: ?FrameGraphScheduleCache = None
): FrameCompileResult {
    let validation = validateFrameGraph(graph, state, capabilities)
    if (!validation.ok) { return FrameCompileResult.rejected(validation.code) }

    let schedule = match (scheduleCache) {
        case Some(value) => value.resolve(graph, validation.edgeFrom, validation.edgeTo)
        case None => FrameGraphScheduleResolution(
            stableTopologicalFrameOrder(
                graph.passCount(), validation.edgeFrom, validation.edgeTo),
            false)
    }
    let order = schedule.order
    if (order.size != graph.passCount()) {
        return FrameCompileResult.rejected("dependency-cycle")
    }
    for (i in 0..order.size) {
        if (graph.passAt(order[i]).kind == FramePassKind.Present && i != order.size - 1) {
            return FrameCompileResult.rejected("present-not-terminal")
        }
    }

    let sameSurfaceGeneration = state.surfaceKey == graph.surfaceKey &&
        state.surfaceGeneration == graph.surfaceGeneration && state.frameId > 0
    let rootDamage = if (sameSurfaceGeneration) { graph.frameDamage } else { DamageRegion.full() }
    let resourceDamage = Array<DamageRegion>(graph.resourceCount(), {_ => DamageRegion.empty()})
    let scheduled = ArrayList<CompiledFramePass>()
    let compiledByDeclaration = Array<?CompiledFramePass>(graph.passCount(), {_ => None})

    for (scheduledIndex in 0..order.size) {
        let passIndex = order[scheduledIndex]
        let pass = graph.passAt(passIndex)
        var damage = damageForFramePass(
            rootDamage, pass.bounds, graph.limits.maxDamageRectangles)
        damage = combineFrameDamage(
            damage,
            damageForFramePass(
                pass.declaredDamage, pass.bounds, graph.limits.maxDamageRectangles),
            graph.limits.maxDamageRectangles)

        for (i in 0..pass.readCount()) {
            let resourceIndex = findFrameResourceIndex(graph, pass.readAt(i))
            if (resourceIndex >= 0) {
                damage = combineFrameDamage(
                    damage, resourceDamage[resourceIndex], graph.limits.maxDamageRectangles)
            }
        }

        let outputFingerprint = framePassOutputFingerprint(graph, pass)
        let outputCode = frameGraphStableCode(outputFingerprint)
        let mayCull = (pass.canCull || pass.kind == FramePassKind.Present) &&
            framePassOutputsCommitted(graph, state, pass)
        var culled = false
        if (damage.kind == FrameDamageKind.Empty && mayCull &&
            state.passMatches(pass.id, pass.stableInputCode, outputFingerprint)) {
            culled = true
        } else if (damage.kind == FrameDamageKind.Empty) {
            damage = match (pass.bounds) {
                case Some(value) => DamageRegion.bounded([value])
                case None => DamageRegion.full()
            }
        }

        if (!culled && pass.effectRadius > 0) {
            damage = expandFrameDamage(
                damage, pass.effectRadius, graph.surfaceWidth, graph.surfaceHeight,
                graph.limits.maxDamageRectangles)
        }

        let compiled = CompiledFramePass(
            pass, damage, culled, outputCode, outputFingerprint)
        scheduled.add(compiled)
        compiledByDeclaration[passIndex] = Some(compiled)
        for (i in 0..pass.writeCount()) {
            let resourceIndex = findFrameResourceIndex(graph, pass.writeAt(i))
            if (resourceIndex >= 0) {
                resourceDamage[resourceIndex] = if (culled) { DamageRegion.empty() } else { damage }
            }
        }
    }

    let groups = buildFrameExecutionGroups(
        graph, scheduled.toArray(), graph.limits.maxDamageRectangles)
    var executedPassCount: Int64 = 0
    var culledPassCount: Int64 = 0
    for (value in scheduled) {
        if (value.culled) { culledPassCount += 1 } else { executedPassCount += 1 }
    }
    let mergedPassCount = executedPassCount - Int64(groups.size)
    let aggregateDamage = aggregateExecutedFrameDamage(
        scheduled.toArray(), graph.limits.maxDamageRectangles)
    let redraw = frameRedrawModeForDamage(aggregateDamage, capabilities)
    let hasPresent = containsExecutedPresent(scheduled.toArray())
    let present = framePresentModeFor(redraw, hasPresent, capabilities)
    let presentStrategy = framePresentStrategyFor(
        aggregateDamage, redraw, present, hasPresent, capabilities)
    let fallback = frameFallbackReason(redraw, present, aggregateDamage, hasPresent, capabilities)
    let nextState = nextFrameGraphCompilerState(graph, compiledByDeclaration)
    let canonical = renderFrameGraphCanonical(
        graph, scheduled.toArray(), groups, validation.declaredResourceBytes,
        mergedPassCount, redraw, present, fallback)
    let scheduleHash = frameGraphStableHash(canonical)
    let trace = renderCompiledFrameGraphTrace(
        graph, scheduled.toArray(), scheduleHash, validation.declaredResourceBytes,
        executedPassCount, culledPassCount, mergedPassCount, redraw, present, fallback)
    if (Int64(trace.toArray().size) > graph.limits.maxTraceBytes) {
        return FrameCompileResult.rejected("trace-over-cap")
    }

    FrameCompileResult.accepted(CompiledFrameGraph(
        graph, scheduleHash, trace, redraw, present, presentStrategy, fallback,
        schedule.hit,
        validation.declaredResourceBytes, scheduled.toArray(), groups,
        executedPassCount, culledPassCount, mergedPassCount, nextState))
}

private func validateFrameGraph(
    graph: FrameGraph,
    state: FrameGraphCompilerState,
    capabilities: FrameGraphExecutorCapabilities
): FrameGraphValidation {
    if (graph.resourceCount() > graph.limits.maxResources) {
        return FrameGraphValidation.rejected("resource-count-over-cap")
    }
    if (graph.passCount() > graph.limits.maxPasses) {
        return FrameGraphValidation.rejected("pass-count-over-cap")
    }
    if (!frameDamageWithinSurface(
        graph.frameDamage, graph.surfaceWidth, graph.surfaceHeight,
        graph.limits.maxDamageRectangles)) {
        return FrameGraphValidation.rejected("invalid-frame-damage")
    }

    let sameSurface = state.surfaceKey == graph.surfaceKey && state.frameId > 0
    if (sameSurface && graph.surfaceGeneration < state.surfaceGeneration) {
        return FrameGraphValidation.rejected("stale-surface-generation")
    }
    if (sameSurface && graph.surfaceGeneration == state.surfaceGeneration &&
        graph.frameId <= state.frameId) {
        return FrameGraphValidation.rejected("stale-frame")
    }
    let compareCommittedResources = sameSurface && graph.surfaceGeneration == state.surfaceGeneration

    var declaredResourceBytes: Int64 = 0
    for (i in 0..graph.resourceCount()) {
        let resource = graph.resourceAt(i)
        if (!capabilities.supportsExtendedDynamicRange &&
            resource.dynamicRange != FrameDynamicRange.Sdr) {
            return FrameGraphValidation.rejected("unsupported-dynamic-range")
        }
        if (resource.declaredBytes > graph.limits.maxDeclaredResourceBytes - declaredResourceBytes) {
            return FrameGraphValidation.rejected("resource-bytes-over-cap")
        }
        declaredResourceBytes += resource.declaredBytes
        if (declaredResourceBytes > capabilities.maxDeclaredResourceBytes) {
            return FrameGraphValidation.rejected("executor-resource-bytes-over-cap")
        }
        if (compareCommittedResources &&
            resource.id.generation < state.latestGeneration(resource.id.key)) {
            return FrameGraphValidation.rejected("stale-resource-generation")
        }
        if (compareCommittedResources && state.containsResourceIdentity(resource.id) &&
            !state.resourceMatches(resource)) {
            return FrameGraphValidation.rejected("resource-descriptor-drift")
        }
        for (j in 0..i) {
            let earlier = graph.resourceAt(j)
            if (resource.id == earlier.id) {
                return FrameGraphValidation.rejected("duplicate-resource")
            }
            if (resource.id.key == earlier.id.key &&
                resource.id.generation <= earlier.id.generation) {
                return FrameGraphValidation.rejected("stale-resource-generation")
            }
        }
    }

    let producers = Array<Int64>(graph.resourceCount(), {_ => -1})
    var dependencyReferences: Int64 = 0
    var presentCount: Int64 = 0
    for (i in 0..graph.passCount()) {
        let pass = graph.passAt(i)
        if (pass.kind == FramePassKind.Present) {
            presentCount += 1
            if (presentCount > 1) {
                return FrameGraphValidation.rejected("multiple-present-passes")
            }
        }
        if (pass.declarationOrder != i) {
            return FrameGraphValidation.rejected("unstable-declaration-order")
        }
        for (j in 0..i) {
            if (pass.id == graph.passAt(j).id) {
                return FrameGraphValidation.rejected("duplicate-pass")
            }
        }
        if (!capabilities.supportsExtendedDynamicRange &&
            pass.dynamicRange != FrameDynamicRange.Sdr) {
            return FrameGraphValidation.rejected("unsupported-dynamic-range")
        }
        if (!framePassModeValid(pass, capabilities)) {
            return FrameGraphValidation.rejected(framePassModeError(pass, capabilities))
        }
        if (!frameOptionalRectWithinSurface(pass.bounds, graph.surfaceWidth, graph.surfaceHeight) ||
            !frameDamageWithinSurface(
                pass.declaredDamage, graph.surfaceWidth, graph.surfaceHeight,
                graph.limits.maxDamageRectangles)) {
            return FrameGraphValidation.rejected("invalid-pass-region")
        }
        if (pass.readCount() > graph.limits.maxDependencies - dependencyReferences) {
            return FrameGraphValidation.rejected("dependency-count-over-cap")
        }
        dependencyReferences += pass.readCount()
        if (pass.writeCount() > graph.limits.maxDependencies - dependencyReferences) {
            return FrameGraphValidation.rejected("dependency-count-over-cap")
        }
        dependencyReferences += pass.writeCount()
        if (pass.dependencyCount() > graph.limits.maxDependencies - dependencyReferences) {
            return FrameGraphValidation.rejected("dependency-count-over-cap")
        }
        dependencyReferences += pass.dependencyCount()

        for (r in 0..pass.readCount()) {
            let id = pass.readAt(r)
            if (findFrameResourceIndex(graph, id) < 0) {
                return FrameGraphValidation.rejected("unknown-resource")
            }
            for (earlierRead in 0..r) {
                if (id == pass.readAt(earlierRead)) {
                    return FrameGraphValidation.rejected("duplicate-resource-access")
                }
            }
        }
        for (w in 0..pass.writeCount()) {
            let id = pass.writeAt(w)
            let resourceIndex = findFrameResourceIndex(graph, id)
            if (resourceIndex < 0) {
                return FrameGraphValidation.rejected("unknown-resource")
            }
            for (earlierWrite in 0..w) {
                if (id == pass.writeAt(earlierWrite)) {
                    return FrameGraphValidation.rejected("duplicate-resource-access")
                }
            }
            for (r in 0..pass.readCount()) {
                if (id == pass.readAt(r)) {
                    return FrameGraphValidation.rejected("read-write-same-resource")
                }
            }
            if (producers[resourceIndex] >= 0) {
                return FrameGraphValidation.rejected("double-producer")
            }
            producers[resourceIndex] = i
        }
        for (d in 0..pass.dependencyCount()) {
            for (earlierDependency in 0..d) {
                if (pass.dependencyAt(d) == pass.dependencyAt(earlierDependency)) {
                    return FrameGraphValidation.rejected("duplicate-pass-dependency")
                }
            }
        }
    }

    let edgeFrom = ArrayList<Int64>()
    let edgeTo = ArrayList<Int64>()
    for (i in 0..graph.passCount()) {
        let pass = graph.passAt(i)
        for (r in 0..pass.readCount()) {
            let resourceIndex = findFrameResourceIndex(graph, pass.readAt(r))
            let producer = producers[resourceIndex]
            if (producer >= 0) {
                addFrameGraphEdge(edgeFrom, edgeTo, producer, i)
            } else {
                let resource = graph.resourceAt(resourceIndex)
                let committed = compareCommittedResources && state.resourceMatches(resource)
                if (resource.lifetime != FrameResourceLifetime.Imported && !committed) {
                    return FrameGraphValidation.rejected("use-before-create")
                }
            }
        }
        for (d in 0..pass.dependencyCount()) {
            let dependency = findFramePassIndex(graph, pass.dependencyAt(d))
            if (dependency < 0) {
                return FrameGraphValidation.rejected("unknown-pass-dependency")
            }
            addFrameGraphEdge(edgeFrom, edgeTo, dependency, i)
        }
    }
    for (i in 0..graph.resourceCount()) {
        let resource = graph.resourceAt(i)
        if (producers[i] < 0 && resource.lifetime != FrameResourceLifetime.Imported &&
            !(compareCommittedResources && state.resourceMatches(resource))) {
            return FrameGraphValidation.rejected("use-before-create")
        }
    }
    if (edgeFrom.size > graph.limits.maxDependencies) {
        return FrameGraphValidation.rejected("dependency-count-over-cap")
    }
    FrameGraphValidation(
        true, "accepted", producers, edgeFrom.toArray(), edgeTo.toArray(), declaredResourceBytes)
}

private func framePassModeValid(
    pass: FramePassDescriptor,
    capabilities: FrameGraphExecutorCapabilities
): Bool {
    if (pass.kind == FramePassKind.ExternalScene3D) {
        if (pass.externalMode == FrameExternalMode.NoExternalSurface) { return false }
        if (pass.externalMode == FrameExternalMode.SharedTexture &&
            !capabilities.supportsSharedTexture) { return false }
    } else if (pass.externalMode != FrameExternalMode.NoExternalSurface) {
        return false
    }
    if (pass.kind == FramePassKind.Present) {
        return pass.readCount() > 0 && pass.writeCount() == 0
    }
    if (pass.kind == FramePassKind.ExternalScene3D) {
        return pass.readCount() + pass.writeCount() > 0
    }
    pass.writeCount() > 0
}

private func framePassModeError(
    pass: FramePassDescriptor,
    capabilities: FrameGraphExecutorCapabilities
): String {
    if (pass.externalMode == FrameExternalMode.SharedTexture &&
        !capabilities.supportsSharedTexture) {
        return "unsupported-shared-texture"
    }
    "invalid-pass-mode"
}

private func addFrameGraphEdge(
    edgeFrom: ArrayList<Int64>,
    edgeTo: ArrayList<Int64>,
    from: Int64,
    to: Int64
): Unit {
    for (i in 0..edgeFrom.size) {
        if (edgeFrom[i] == from && edgeTo[i] == to) { return }
    }
    edgeFrom.add(from)
    edgeTo.add(to)
}

private func stableTopologicalFrameOrder(
    passCount: Int64,
    edgeFrom: Array<Int64>,
    edgeTo: Array<Int64>
): Array<Int64> {
    let indegree = Array<Int64>(passCount, {_ => 0})
    for (i in 0..edgeTo.size) { indegree[edgeTo[i]] += 1 }
    let selected = Array<Bool>(passCount, {_ => false})
    let order = ArrayList<Int64>()
    for (_ in 0..passCount) {
        var candidate: Int64 = -1
        for (i in 0..passCount) {
            if (!selected[i] && indegree[i] == 0) {
                candidate = i
                break
            }
        }
        if (candidate < 0) { break }
        selected[candidate] = true
        order.add(candidate)
        for (i in 0..edgeFrom.size) {
            if (edgeFrom[i] == candidate) { indegree[edgeTo[i]] -= 1 }
        }
    }
    order.toArray()
}

/**
 * Exact identity of inputs that can change dependency ordering. Frame id, State input
 * codes and damage are intentionally absent: they affect culling/damage below the
 * topology stage and are always recomputed after a cache hit.
 */
private func frameGraphTopologyKey(graph: FrameGraph): String {
    let out = StringBuilder()
    out.append(CANGHUI_FRAME_GRAPH_PROTOCOL)
    out.append("|surface=")
    out.append(graph.surfaceKey)
    out.append("@")
    out.append(graph.surfaceGeneration.toString())
    out.append("|size=")
    out.append(graph.surfaceWidth.toString())
    out.append("x")
    out.append(graph.surfaceHeight.toString())
    out.append("|resources=")
    out.append(graph.resourceCount().toString())
    for (i in 0..graph.resourceCount()) {
        out.append("|r:")
        out.append(frameResourceDescriptorFingerprint(graph.resourceAt(i)))
    }
    out.append("|passes=")
    out.append(graph.passCount().toString())
    for (i in 0..graph.passCount()) {
        out.append("|p:")
        out.append(framePassOutputFingerprint(graph, graph.passAt(i)))
    }
    out.append("|dependency-cap=")
    out.append(graph.limits.maxDependencies.toString())
    out.toString()
}

private func findFrameResourceIndex(graph: FrameGraph, id: FrameResourceId): Int64 {
    for (i in 0..graph.resourceCount()) {
        if (graph.resourceAt(i).id == id) { return i }
    }
    -1
}

private func findFramePassIndex(graph: FrameGraph, id: FramePassId): Int64 {
    for (i in 0..graph.passCount()) {
        if (graph.passAt(i).id == id) { return i }
    }
    -1
}

private func frameDamageWithinSurface(
    damage: DamageRegion,
    width: Int64,
    height: Int64,
    maximumRectangles: Int64
): Bool {
    if (damage.rectangleCount() > maximumRectangles) { return false }
    if (damage.kind != FrameDamageKind.Bounded) {
        return damage.rectangleCount() == 0
    }
    if (damage.rectangleCount() == 0) { return false }
    for (i in 0..damage.rectangleCount()) {
        if (!frameRectWithinSurface(damage.rectangleAt(i), width, height)) { return false }
    }
    true
}

private func frameOptionalRectWithinSurface(
    value: ?FrameDamageRect,
    width: Int64,
    height: Int64
): Bool {
    match (value) {
        case Some(rect) => frameRectWithinSurface(rect, width, height)
        case None => true
    }
}

private func frameRectWithinSurface(rect: FrameDamageRect, width: Int64, height: Int64): Bool {
    rect.right() <= width && rect.bottom() <= height
}

private func damageForFramePass(
    damage: DamageRegion,
    bounds: ?FrameDamageRect,
    maximumRectangles: Int64
): DamageRegion {
    if (damage.kind == FrameDamageKind.Empty || damage.kind == FrameDamageKind.Full) {
        return damage
    }
    match (bounds) {
        case None => DamageRegion.full()
        case Some(passBounds) =>
            let values = ArrayList<FrameDamageRect>()
            for (i in 0..damage.rectangleCount()) {
                match (intersectFrameRect(damage.rectangleAt(i), passBounds)) {
                    case Some(value) => values.add(value)
                    case None => ()
                }
            }
            if (values.size == 0) { return DamageRegion.empty() }
            if (values.size > maximumRectangles) { return DamageRegion.full() }
            DamageRegion.bounded(values.toArray())
    }
}

private func combineFrameDamage(
    first: DamageRegion,
    second: DamageRegion,
    maximumRectangles: Int64
): DamageRegion {
    if (first.kind == FrameDamageKind.Full || second.kind == FrameDamageKind.Full) {
        return DamageRegion.full()
    }
    if (first.kind == FrameDamageKind.Empty) { return copyFrameDamage(second) }
    if (second.kind == FrameDamageKind.Empty) { return copyFrameDamage(first) }
    if (first.rectangleCount() > maximumRectangles - second.rectangleCount()) {
        return DamageRegion.full()
    }
    let values = ArrayList<FrameDamageRect>()
    for (i in 0..first.rectangleCount()) { values.add(first.rectangleAt(i)) }
    for (i in 0..second.rectangleCount()) { values.add(second.rectangleAt(i)) }
    DamageRegion.bounded(values.toArray())
}

private func copyFrameDamage(value: DamageRegion): DamageRegion {
    if (value.kind == FrameDamageKind.Empty) { return DamageRegion.empty() }
    if (value.kind == FrameDamageKind.Full) { return DamageRegion.full() }
    let rectangles = ArrayList<FrameDamageRect>()
    for (i in 0..value.rectangleCount()) { rectangles.add(value.rectangleAt(i)) }
    DamageRegion.bounded(rectangles.toArray())
}

private func expandFrameDamage(
    damage: DamageRegion,
    radius: Int64,
    surfaceWidth: Int64,
    surfaceHeight: Int64,
    maximumRectangles: Int64
): DamageRegion {
    if (damage.kind != FrameDamageKind.Bounded || radius == 0) { return damage }
    if (damage.rectangleCount() > maximumRectangles) { return DamageRegion.full() }
    let values = ArrayList<FrameDamageRect>()
    for (i in 0..damage.rectangleCount()) {
        let rect = damage.rectangleAt(i)
        let left = max(Int64(0), rect.x - min(rect.x, radius))
        let top = max(Int64(0), rect.y - min(rect.y, radius))
        let right = min(surfaceWidth, saturatedFrameAdd(rect.right(), radius))
        let bottom = min(surfaceHeight, saturatedFrameAdd(rect.bottom(), radius))
        if (right > left && bottom > top) {
            values.add(FrameDamageRect(left, top, right - left, bottom - top))
        }
    }
    if (values.size == 0) { return DamageRegion.empty() }
    DamageRegion.bounded(values.toArray())
}

private func saturatedFrameAdd(value: Int64, added: Int64): Int64 {
    if (added > Int64.Max - value) { Int64.Max } else { value + added }
}

private func intersectFrameRect(first: FrameDamageRect, second: FrameDamageRect): ?FrameDamageRect {
    let left = max(first.x, second.x)
    let top = max(first.y, second.y)
    let right = min(first.right(), second.right())
    let bottom = min(first.bottom(), second.bottom())
    if (right <= left || bottom <= top) { return None }
    Some(FrameDamageRect(left, top, right - left, bottom - top))
}

private func framePassOutputFingerprint(graph: FrameGraph, pass: FramePassDescriptor): String {
    let out = StringBuilder()
    out.append(pass.id.key)
    out.append("|")
    out.append(framePassKindName(pass.kind))
    out.append("|")
    out.append(pass.declarationOrder.toString())
    out.append("|")
    out.append(pass.mergeKey)
    out.append("|")
    out.append(pass.effectRadius.toString())
    out.append("|")
    out.append(graphicsColorSpaceName(pass.colorSpace))
    out.append("|")
    out.append(graphicsAlphaModeName(pass.alphaMode))
    out.append("|")
    out.append(frameDynamicRangeName(pass.dynamicRange))
    out.append("|")
    out.append(frameExternalModeName(pass.externalMode))
    out.append("|canCull:")
    out.append(if (pass.canCull) { "true" } else { "false" })
    out.append("|canMerge:")
    out.append(if (pass.canMerge) { "true" } else { "false" })
    appendFrameBoundsCode(out, pass.bounds)
    for (i in 0..pass.readCount()) {
        appendFrameResourceDescriptorCode(out, graph, "|read:", pass.readAt(i))
    }
    for (i in 0..pass.writeCount()) {
        appendFrameResourceDescriptorCode(out, graph, "|write:", pass.writeAt(i))
    }
    for (i in 0..pass.dependencyCount()) {
        out.append("|depends:")
        out.append(pass.dependencyAt(i).key)
    }
    out.toString()
}

private func appendFrameBoundsCode(out: StringBuilder, bounds: ?FrameDamageRect): Unit {
    match (bounds) {
        case Some(value) =>
            out.append("|bounds:")
            out.append(value.x.toString())
            out.append(",")
            out.append(value.y.toString())
            out.append(",")
            out.append(value.width.toString())
            out.append(",")
            out.append(value.height.toString())
        case None => out.append("|bounds:none")
    }
}

private func appendFrameResourceIdCode(
    out: StringBuilder,
    prefix: String,
    id: FrameResourceId
): Unit {
    out.append(prefix)
    out.append(id.key)
    out.append("@")
    out.append(id.generation.toString())
}

private func appendFrameResourceDescriptorCode(
    out: StringBuilder,
    graph: FrameGraph,
    prefix: String,
    id: FrameResourceId
): Unit {
    appendFrameResourceIdCode(out, prefix, id)
    let index = findFrameResourceIndex(graph, id)
    if (index < 0) { return }
    let resource = graph.resourceAt(index)
    out.append(":")
    out.append(frameResourceKindName(resource.kind))
    out.append(":")
    out.append(frameResourceLifetimeName(resource.lifetime))
    out.append(":")
    out.append(resource.declaredBytes.toString())
    out.append(":")
    out.append(graphicsColorSpaceName(resource.colorSpace))
    out.append(":")
    out.append(graphicsAlphaModeName(resource.alphaMode))
    out.append(":")
    out.append(frameDynamicRangeName(resource.dynamicRange))
}

private func frameResourceDescriptorFingerprint(resource: FrameResourceDescriptor): String {
    let out = StringBuilder()
    appendFrameResourceIdCode(out, "", resource.id)
    out.append("|")
    out.append(frameResourceKindName(resource.kind))
    out.append("|")
    out.append(frameResourceLifetimeName(resource.lifetime))
    out.append("|")
    out.append(resource.declaredBytes.toString())
    out.append("|")
    out.append(graphicsColorSpaceName(resource.colorSpace))
    out.append("|")
    out.append(graphicsAlphaModeName(resource.alphaMode))
    out.append("|")
    out.append(frameDynamicRangeName(resource.dynamicRange))
    out.toString()
}

private func framePassOutputsCommitted(
    graph: FrameGraph,
    state: FrameGraphCompilerState,
    pass: FramePassDescriptor
): Bool {
    for (i in 0..pass.writeCount()) {
        let index = findFrameResourceIndex(graph, pass.writeAt(i))
        if (index < 0 ||
            graph.resourceAt(index).lifetime != FrameResourceLifetime.Persistent ||
            !state.resourceMatches(graph.resourceAt(index))) {
            return false
        }
    }
    true
}

private func buildFrameExecutionGroups(
    graph: FrameGraph,
    scheduled: Array<CompiledFramePass>,
    maximumRectangles: Int64
): Array<CompiledFramePassGroup> {
    let groups = ArrayList<CompiledFramePassGroup>()
    var previous: ?CompiledFramePass = None
    for (value in scheduled) {
        if (value.culled) {
            previous = None
            continue
        }
        var appended = false
        match (previous) {
            case Some(last) => if (groups.size > 0 && canMergeFramePasses(graph, last, value)) {
                groups[groups.size - 1].append(value, maximumRectangles)
                appended = true
            }
            case None => ()
        }
        if (!appended) { groups.add(CompiledFramePassGroup(value)) }
        previous = Some(value)
    }
    groups.toArray()
}

private func canMergeFramePasses(
    graph: FrameGraph,
    first: CompiledFramePass,
    second: CompiledFramePass
): Bool {
    let a = first.descriptor
    let b = second.descriptor
    if (!a.canMerge || !b.canMerge || a.mergeKey.isEmpty() || a.mergeKey != b.mergeKey ||
        a.kind != b.kind || (a.kind != FramePassKind.Ui2D && a.kind != FramePassKind.OffscreenComposition) ||
        a.effectRadius != b.effectRadius || a.colorSpace != b.colorSpace || a.alphaMode != b.alphaMode ||
        a.dynamicRange != b.dynamicRange ||
        a.externalMode != FrameExternalMode.NoExternalSurface ||
        b.externalMode != FrameExternalMode.NoExternalSurface ||
        a.writeCount() != 1 || b.writeCount() != 1 || !sameFrameBounds(a.bounds, b.bounds)) {
        return false
    }
    let firstTarget = a.writeAt(0)
    let secondTarget = b.writeAt(0)
    if (firstTarget.key != secondTarget.key ||
        secondTarget.generation <= firstTarget.generation ||
        !framePassReadsResource(b, firstTarget)) {
        return false
    }
    sameFrameTargetSemantics(graph, firstTarget, secondTarget)
}

private func framePassReadsResource(pass: FramePassDescriptor, id: FrameResourceId): Bool {
    for (i in 0..pass.readCount()) {
        if (pass.readAt(i) == id) { return true }
    }
    false
}

/**
 * Mergeable versions name one logical target and form an explicit producer/consumer chain. Their
 * execution-relevant descriptors must otherwise be identical; generation is the version edge.
 */
private func sameFrameTargetSemantics(
    graph: FrameGraph,
    first: FrameResourceId,
    second: FrameResourceId
): Bool {
    let firstIndex = findFrameResourceIndex(graph, first)
    let secondIndex = findFrameResourceIndex(graph, second)
    if (firstIndex < 0 || secondIndex < 0) { return false }
    let a = graph.resourceAt(firstIndex)
    let b = graph.resourceAt(secondIndex)
    a.kind == b.kind && a.lifetime == b.lifetime &&
        a.declaredBytes == b.declaredBytes && a.colorSpace == b.colorSpace &&
        a.alphaMode == b.alphaMode && a.dynamicRange == b.dynamicRange
}

private func sameFrameBounds(first: ?FrameDamageRect, second: ?FrameDamageRect): Bool {
    match ((first, second)) {
        case (Some(a), Some(b)) => a == b
        case (None, None) => true
        case _ => false
    }
}

private func aggregateExecutedFrameDamage(
    scheduled: Array<CompiledFramePass>,
    maximumRectangles: Int64
): DamageRegion {
    var damage = DamageRegion.empty()
    for (value in scheduled) {
        if (!value.culled && value.descriptor.kind != FramePassKind.Present) {
            damage = combineFrameDamage(damage, value.damage, maximumRectangles)
        }
    }
    damage
}

private func containsExecutedPresent(scheduled: Array<CompiledFramePass>): Bool {
    for (value in scheduled) {
        if (!value.culled && value.descriptor.kind == FramePassKind.Present) { return true }
    }
    false
}

private func frameRedrawModeForDamage(
    damage: DamageRegion,
    capabilities: FrameGraphExecutorCapabilities
): FrameRedrawMode {
    if (damage.kind == FrameDamageKind.Empty) { return FrameRedrawMode.Skipped }
    if (damage.kind == FrameDamageKind.Full || !capabilities.supportsBoundedRedraw) {
        return FrameRedrawMode.Full
    }
    FrameRedrawMode.Bounded
}

private func framePresentModeFor(
    redraw: FrameRedrawMode,
    hasPresent: Bool,
    capabilities: FrameGraphExecutorCapabilities
): FramePresentMode {
    if (!hasPresent || redraw == FrameRedrawMode.Skipped) { return FramePresentMode.NotPresented }
    if (redraw == FrameRedrawMode.Bounded && capabilities.supportsPartialPresent) {
        return FramePresentMode.Partial
    }
    FramePresentMode.Full
}

private func framePresentStrategyFor(
    damage: DamageRegion,
    redraw: FrameRedrawMode,
    present: FramePresentMode,
    hasPresent: Bool,
    capabilities: FrameGraphExecutorCapabilities
): FramePresentStrategy {
    if (!hasPresent || present == FramePresentMode.NotPresented) {
        return FramePresentStrategy.NotPresented
    }
    if (damage.kind == FrameDamageKind.Bounded &&
        redraw == FrameRedrawMode.Full && !capabilities.supportsBoundedRedraw) {
        return FramePresentStrategy.UnsupportedFallback
    }
    if (redraw == FrameRedrawMode.Bounded && present == FramePresentMode.Partial &&
        capabilities.supportsPartialPresent) {
        return FramePresentStrategy.IncrementalRegions
    }
    if (redraw == FrameRedrawMode.Bounded && present == FramePresentMode.Full) {
        return FramePresentStrategy.PreservedBufferBounded
    }
    FramePresentStrategy.FullSurface
}

private func frameFallbackReason(
    redraw: FrameRedrawMode,
    present: FramePresentMode,
    damage: DamageRegion,
    hasPresent: Bool,
    capabilities: FrameGraphExecutorCapabilities
): String {
    if (damage.kind == FrameDamageKind.Bounded && redraw == FrameRedrawMode.Full &&
        !capabilities.supportsBoundedRedraw) {
        return "bounded-redraw-unsupported"
    }
    if (hasPresent && redraw == FrameRedrawMode.Bounded && present == FramePresentMode.Full &&
        !capabilities.supportsPartialPresent) {
        return "partial-present-unsupported"
    }
    "none"
}

private func nextFrameGraphCompilerState(
    graph: FrameGraph,
    compiledByDeclaration: Array<?CompiledFramePass>
): FrameGraphCompilerState {
    let resourceValues = ArrayList<FrameResourceDescriptor>()
    for (i in 0..graph.resourceCount()) {
        let resource = graph.resourceAt(i)
        if (resource.lifetime == FrameResourceLifetime.Transient) { continue }
        var replaced = false
        for (j in 0..resourceValues.size) {
            if (resourceValues[j].id.key == resource.id.key) {
                if (resource.id.generation > resourceValues[j].id.generation) {
                    resourceValues[j] = resource
                }
                replaced = true
                break
            }
        }
        if (!replaced) { resourceValues.add(resource) }
    }
    let passIds = ArrayList<FramePassId>()
    let passStableCodes = ArrayList<Int64>()
    let passOutputFingerprints = ArrayList<String>()
    for (i in 0..graph.passCount()) {
        match (compiledByDeclaration[i]) {
            case Some(value) =>
                passIds.add(value.descriptor.id)
                passStableCodes.add(value.descriptor.stableInputCode)
                passOutputFingerprints.add(value.outputFingerprint)
            case None => ()
        }
    }
    FrameGraphCompilerState(
        graph.surfaceKey, graph.surfaceGeneration, graph.frameId,
        resourceValues.toArray(), passIds.toArray(),
        passStableCodes.toArray(), passOutputFingerprints.toArray())
}

private func renderFrameGraphCanonical(
    graph: FrameGraph,
    scheduled: Array<CompiledFramePass>,
    groups: Array<CompiledFramePassGroup>,
    declaredResourceBytes: Int64,
    mergedPassCount: Int64,
    redraw: FrameRedrawMode,
    present: FramePresentMode,
    fallback: String
): String {
    let out = StringBuilder()
    out.append(CANGHUI_FRAME_GRAPH_PROTOCOL)
    out.append("|surface=")
    out.append(graph.surfaceKey)
    out.append("@")
    out.append(graph.surfaceGeneration.toString())
    out.append("|frame=")
    out.append(graph.frameId.toString())
    out.append("|size=")
    out.append(graph.surfaceWidth.toString())
    out.append("x")
    out.append(graph.surfaceHeight.toString())
    out.append("|bytes=")
    out.append(declaredResourceBytes.toString())
    for (i in 0..graph.resourceCount()) {
        let resource = graph.resourceAt(i)
        out.append("|r:")
        out.append(resource.id.key)
        out.append("@")
        out.append(resource.id.generation.toString())
        out.append(":")
        out.append(frameResourceKindName(resource.kind))
        out.append(":")
        out.append(frameResourceLifetimeName(resource.lifetime))
        out.append(":")
        out.append(resource.declaredBytes.toString())
        out.append(":")
        out.append(graphicsColorSpaceName(resource.colorSpace))
        out.append(":")
        out.append(graphicsAlphaModeName(resource.alphaMode))
        out.append(":")
        out.append(frameDynamicRangeName(resource.dynamicRange))
    }
    for (value in scheduled) {
        let pass = value.descriptor
        out.append("|p:")
        out.append(pass.id.key)
        out.append(":")
        out.append(pass.declarationOrder.toString())
        out.append(":")
        out.append(framePassKindName(pass.kind))
        out.append(":")
        out.append(pass.stableInputCode.toString())
        out.append(":")
        out.append(value.outputCode.toString())
        out.append(":fingerprint=")
        out.append(value.outputFingerprint.toArray().size.toString())
        out.append("#")
        out.append(value.outputFingerprint)
        out.append(":")
        out.append(if (value.culled) { "c" } else { "e" })
        out.append(":external=")
        out.append(frameExternalModeName(pass.externalMode))
        out.append(":unified=")
        out.append(if (pass.externalMode == FrameExternalMode.SharedTexture) { "true" } else { "false" })
        for (i in 0..pass.readCount()) {
            appendFrameResourceIdCode(out, ":read=", pass.readAt(i))
        }
        for (i in 0..pass.writeCount()) {
            appendFrameResourceIdCode(out, ":write=", pass.writeAt(i))
        }
        for (i in 0..pass.dependencyCount()) {
            out.append(":depends=")
            out.append(pass.dependencyAt(i).key)
        }
        appendCanonicalFrameDamage(out, value.damage)
    }
    out.append("|merged=")
    out.append(mergedPassCount.toString())
    for (i in 0..groups.size) {
        let group = groups[i]
        out.append("|g:")
        out.append(i.toString())
        for (j in 0..group.passCount()) {
            out.append(":")
            out.append(group.passAt(j).descriptor.id.key)
        }
    }
    out.append("|redraw=")
    out.append(frameRedrawModeName(redraw))
    out.append("|present=")
    out.append(framePresentModeName(present))
    out.append("|fallback=")
    out.append(fallback)
    out.toString()
}

private func appendCanonicalFrameDamage(out: StringBuilder, damage: DamageRegion): Unit {
    out.append(":")
    out.append(frameDamageKindName(damage.kind))
    for (i in 0..damage.rectangleCount()) {
        let rect = damage.rectangleAt(i)
        out.append(":")
        out.append(rect.x.toString())
        out.append(",")
        out.append(rect.y.toString())
        out.append(",")
        out.append(rect.width.toString())
        out.append(",")
        out.append(rect.height.toString())
    }
}

private func frameGraphStableCode(value: String): Int64 {
    var code: Int64 = 0
    let bytes = value.toArray()
    for (i in 0..bytes.size) {
        code += Int64(bytes[i]) * ((i % 251) + 1)
    }
    code
}

private func frameGraphStableHash(value: String): String {
    let bytes = value.toArray()
    "fg-${frameGraphStableCode(value)}-${bytes.size}"
}

private func renderCompiledFrameGraphTrace(
    graph: FrameGraph,
    scheduled: Array<CompiledFramePass>,
    scheduleHash: String,
    declaredResourceBytes: Int64,
    executedPassCount: Int64,
    culledPassCount: Int64,
    mergedPassCount: Int64,
    redraw: FrameRedrawMode,
    present: FramePresentMode,
    fallback: String
): String {
    let out = StringBuilder()
    out.append("{\"protocol\":\"")
    out.append(CANGHUI_FRAME_GRAPH_PROTOCOL)
    out.append("\",\"surface\":\"")
    out.append(graph.surfaceKey)
    out.append("\",\"surfaceGeneration\":")
    out.append(graph.surfaceGeneration.toString())
    out.append(",\"frameId\":")
    out.append(graph.frameId.toString())
    out.append(",\"scheduleHash\":\"")
    out.append(scheduleHash)
    out.append("\",\"declaredResourceBytes\":")
    out.append(declaredResourceBytes.toString())
    out.append(",\"executedPassCount\":")
    out.append(executedPassCount.toString())
    out.append(",\"culledPassCount\":")
    out.append(culledPassCount.toString())
    out.append(",\"mergedPassCount\":")
    out.append(mergedPassCount.toString())
    out.append(",\"redrawMode\":\"")
    out.append(frameRedrawModeName(redraw))
    out.append("\",\"presentMode\":\"")
    out.append(framePresentModeName(present))
    out.append("\",\"fallbackReason\":\"")
    out.append(fallback)
    out.append("\",\"passes\":[")
    var first = true
    for (value in scheduled) {
        if (!first) { out.append(",") }
        first = false
        out.append("{\"id\":\"")
        out.append(value.descriptor.id.key)
        out.append("\",\"order\":")
        out.append(value.descriptor.declarationOrder.toString())
        out.append(",\"kind\":\"")
        out.append(framePassKindName(value.descriptor.kind))
        out.append("\",\"externalMode\":\"")
        out.append(frameExternalModeName(value.descriptor.externalMode))
        out.append("\",\"unifiedPixels\":")
        out.append(if (value.descriptor.externalMode == FrameExternalMode.SharedTexture) {
            "true"
        } else {
            "false"
        })
        out.append(",\"reads\":")
        appendFrameResourceIdJsonArray(out, value.descriptor, true)
        out.append(",\"writes\":")
        appendFrameResourceIdJsonArray(out, value.descriptor, false)
        out.append(",\"dependsOn\":")
        appendFramePassIdJsonArray(out, value.descriptor)
        out.append(",\"culled\":")
        out.append(if (value.culled) { "true" } else { "false" })
        out.append(",\"damage\":")
        appendFrameDamageJson(out, value.damage)
        out.append("}")
    }
    out.append("]}")
    out.toString()
}

private func appendFrameResourceIdJsonArray(
    out: StringBuilder,
    pass: FramePassDescriptor,
    reads: Bool
): Unit {
    out.append("[")
    let count = if (reads) { pass.readCount() } else { pass.writeCount() }
    for (i in 0..count) {
        if (i > 0) { out.append(",") }
        let id = if (reads) { pass.readAt(i) } else { pass.writeAt(i) }
        out.append("\"")
        out.append(id.key)
        out.append("@")
        out.append(id.generation.toString())
        out.append("\"")
    }
    out.append("]")
}

private func appendFramePassIdJsonArray(out: StringBuilder, pass: FramePassDescriptor): Unit {
    out.append("[")
    for (i in 0..pass.dependencyCount()) {
        if (i > 0) { out.append(",") }
        out.append("\"")
        out.append(pass.dependencyAt(i).key)
        out.append("\"")
    }
    out.append("]")
}

private func appendFrameDamageJson(out: StringBuilder, damage: DamageRegion): Unit {
    out.append("{\"kind\":\"")
    out.append(frameDamageKindName(damage.kind))
    out.append("\",\"rectangles\":[")
    var first = true
    for (i in 0..damage.rectangleCount()) {
        if (!first) { out.append(",") }
        first = false
        let rect = damage.rectangleAt(i)
        out.append("[")
        out.append(rect.x.toString())
        out.append(",")
        out.append(rect.y.toString())
        out.append(",")
        out.append(rect.width.toString())
        out.append(",")
        out.append(rect.height.toString())
        out.append("]")
    }
    out.append("]}")
}
