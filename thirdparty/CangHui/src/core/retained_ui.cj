package chui.core

import std.collection.{ArrayList, HashMap, HashSet}
import std.sync.AtomicInt64
import sdl.{Rect, Size, UiEvent}

private let RETAINED_UI_PHASE_COUNT: Int64 = 6
private let RETAINED_UI_MAX_DAMAGE_RECTS: Int64 = 64
private let retainedStateIdentityCounter = AtomicInt64(1)
private let retainedRuntimeIdentityCounter = AtomicInt64(1)

/** Internal phase vocabulary; it does not change Widget's public immediate-mode contract. */
protected enum RetainedUiPhase <: Equatable<RetainedUiPhase> {
    | Build
    | Measure
    | Layout
    | Paint
    | Semantics
    | HitTest

    public operator func ==(other: RetainedUiPhase): Bool {
        retainedUiPhaseIndex(this) == retainedUiPhaseIndex(other)
    }

    public operator func !=(other: RetainedUiPhase): Bool { !(this == other) }
}

private func retainedUiPhaseIndex(value: RetainedUiPhase): Int64 {
    match (value) {
        case RetainedUiPhase.Build => 0
        case RetainedUiPhase.Measure => 1
        case RetainedUiPhase.Layout => 2
        case RetainedUiPhase.Paint => 3
        case RetainedUiPhase.Semantics => 4
        case RetainedUiPhase.HitTest => 5
    }
}

protected enum RetainedUiDamageKind <: Equatable<RetainedUiDamageKind> {
    | Empty
    | Bounded
    | Full

    public operator func ==(other: RetainedUiDamageKind): Bool {
        retainedUiDamageKindCode(this) == retainedUiDamageKindCode(other)
    }

    public operator func !=(other: RetainedUiDamageKind): Bool { !(this == other) }
}

private func retainedUiDamageKindCode(value: RetainedUiDamageKind): Int64 {
    match (value) {
        case RetainedUiDamageKind.Empty => 0
        case RetainedUiDamageKind.Bounded => 1
        case RetainedUiDamageKind.Full => 2
    }
}

/** A provider-free damage result; Desktop converts these logical rectangles to FrameGraph damage. */
protected class RetainedUiDamage {
    public let kind: RetainedUiDamageKind
    public let reason: String
    private let rectangles: Array<Rect>

    init(kind: RetainedUiDamageKind, reason: String, rectangles: Array<Rect>) {
        this.kind = kind
        this.reason = reason
        this.rectangles = rectangles
    }

    public func rectangleCount(): Int64 { rectangles.size }
    public func rectangleAt(index: Int64): Rect { rectangles[index] }
}

/**
 * Complete proof required before one node may emit bounded pixels. `bounds` is the node's
 * logical paint extent before effect expansion; `clip` is the effective ancestor clip. A
 * transform/ancestor code is deliberately opaque and must be stable across both frames.
 */
protected class RetainedPaintProof {
    public let bounds: Rect
    public let clip: ?Rect
    public let transformCode: Int64
    public let effectRadius: Float32
    public let ancestorContextCode: Int64
    public let proven: Bool

    public init(
        bounds: Rect,
        clip!: ?Rect = None,
        transformCode!: Int64 = 0,
        effectRadius!: Float32 = 0.0,
        ancestorContextCode!: Int64 = 0,
        proven!: Bool = false
    ) {
        this.bounds = bounds
        this.clip = clip
        this.transformCode = transformCode
        this.effectRadius = effectRadius
        this.ancestorContextCode = ancestorContextCode
        this.proven = proven && retainedRectIsFinitePositive(bounds) &&
            effectRadius >= 0.0 && effectRadius == effectRadius
    }
}

/**
 * Internal opt-in for widgets whose preferred size can be reused across declarative rebuilds.
 * The identity must include the widget kind and every non-State measurement input; the retained
 * runtime adds the offered Size. Ordinary Widget implementations remain conservative.
 */
internal interface RetainedMeasureOutputProvider {
    func retainedMeasureInputIdentity(ctx: UiContext): String
}

/**
 * Internal opt-in for a subtree that can prove the complete pixel extent of its next paint.
 * Returning None keeps full-root damage. A proof may overestimate but must never omit pixels.
 */
internal interface RetainedPaintProofProvider {
    func retainedPaintProof(ctx: UiContext, frame: Rect): ?RetainedPaintProof
}

/** Decision returned before a phase. A caller may skip work only when `canReuse` is true. */
protected class RetainedPhaseDecision {
    public let nodeId: String
    public let phase: RetainedUiPhase
    public let generation: UInt64
    public let canReuse: Bool

    init(nodeId: String, phase: RetainedUiPhase, generation: UInt64, canReuse: Bool) {
        this.nodeId = nodeId
        this.phase = phase
        this.generation = generation
        this.canReuse = canReuse
    }
}

private class RetainedStateDependency {
    let key: String
    let stateId: Int64
    let nodeId: String
    let phase: RetainedUiPhase

    init(key: String, stateId: Int64, nodeId: String, phase: RetainedUiPhase) {
        this.key = key
        this.stateId = stateId
        this.nodeId = nodeId
        this.phase = phase
    }
}

private class RetainedActivePhase {
    let nodeId: String
    let phase: RetainedUiPhase
    let inputCode: Int64
    let dirtyRevisionAtBegin: UInt64
    let reusable: Bool

    init(
        nodeId: String,
        phase: RetainedUiPhase,
        inputCode: Int64,
        dirtyRevisionAtBegin: UInt64,
        reusable: Bool
    ) {
        this.nodeId = nodeId
        this.phase = phase
        this.inputCode = inputCode
        this.dirtyRevisionAtBegin = dirtyRevisionAtBegin
        this.reusable = reusable
    }
}

private class RetainedUiNodeRecord {
    let id: String
    var parentId: String
    var structureCode: Int64
    var layoutIsolated: Bool
    var pendingParentId: String
    var pendingStructureCode: Int64
    var pendingLayoutIsolated: Bool
    let phaseGenerations = Array<UInt64>(RETAINED_UI_PHASE_COUNT, {_ => UInt64(0)})
    let phaseInputs = Array<Int64>(RETAINED_UI_PHASE_COUNT, {_ => Int64(0)})
    let phaseComplete = Array<Bool>(RETAINED_UI_PHASE_COUNT, {_ => false})
    let dirtyRevisions = Array<UInt64>(RETAINED_UI_PHASE_COUNT, {_ => UInt64(1)})
    let cleanRevisions = Array<UInt64>(RETAINED_UI_PHASE_COUNT, {_ => UInt64(0)})
    let executed = Array<Bool>(RETAINED_UI_PHASE_COUNT, {_ => false})
    let executedInputs = Array<Int64>(RETAINED_UI_PHASE_COUNT, {_ => Int64(0)})
    let executedDirtyRevisions = Array<UInt64>(RETAINED_UI_PHASE_COUNT, {_ => UInt64(0)})
    var paintProof: ?RetainedPaintProof = None
    var pendingPaintProof: ?RetainedPaintProof = None
    var measureOutput: ?Size = None
    var pendingMeasureOutput: ?Size = None
    var measureAvailable: ?Size = None
    var pendingMeasureAvailable: ?Size = None
    var measureIdentity: ?String = None
    var pendingMeasureIdentity: ?String = None

    init(id: String, parentId: String, structureCode: Int64, layoutIsolated: Bool) {
        this.id = id
        this.parentId = parentId
        this.structureCode = structureCode
        this.layoutIsolated = layoutIsolated
        this.pendingParentId = parentId
        this.pendingStructureCode = structureCode
        this.pendingLayoutIsolated = layoutIsolated
    }

    func phaseDirty(index: Int64): Bool {
        dirtyRevisions[index] != cleanRevisions[index]
    }

    func resetTransaction(): Unit {
        pendingParentId = parentId
        pendingStructureCode = structureCode
        pendingLayoutIsolated = layoutIsolated
        pendingPaintProof = None
        pendingMeasureOutput = None
        pendingMeasureAvailable = None
        pendingMeasureIdentity = None
        for (i in 0..RETAINED_UI_PHASE_COUNT) {
            executed[i] = false
            executedInputs[i] = 0
            executedDirtyRevisions[i] = UInt64(0)
        }
    }
}

// State is owner-thread state. This registry follows that existing contract and never turns State
// into a cross-thread primitive; Desktop workers still have to post through UiOwnerQueue.
private let retainedStateRuntimes = HashMap<Int64, ArrayList<RetainedUiRuntime>>()
private var activeRetainedUiRuntime: ?RetainedUiRuntime = None

internal func allocateRetainedStateIdentity(): Int64 {
    retainedStateIdentityCounter.fetchAdd(1)
}

internal func recordRetainedStateRead(stateId: Int64): Unit {
    match (activeRetainedUiRuntime) {
        case Some(runtime) => runtime.recordStateRead(stateId)
        case None => ()
    }
}

internal func notifyRetainedStateWrite(stateId: Int64): Unit {
    match (retainedStateRuntimes.get(stateId)) {
        case Some(values) =>
            // A runtime can prune dependencies only at frame commit/cancel, never from this callback.
            for (runtime in values.toArray()) { runtime.invalidateState(stateId) }
        case None => ()
    }
}

/**
 * Transactional retained metadata for one StateStore. It never retains native handles or Widget
 * closures. Validation and dependency bookkeeping still run on a reuse hit; only a caller that got
 * `canReuse == true` may reuse its own immutable phase output.
 */
protected class RetainedUiRuntime {
    private let identity = retainedRuntimeIdentityCounter.fetchAdd(1)
    private let nodes = HashMap<String, RetainedUiNodeRecord>()
    private let dependencies = HashMap<String, RetainedStateDependency>()
    private let visitedNodes = HashSet<String>()
    private let visitedDependencies = HashSet<String>()
    private let addedNodeIds = ArrayList<String>()
    private let addedDependencyKeys = ArrayList<String>()
    private let phases = ArrayList<RetainedActivePhase>()
    private let frameDamage = ArrayList<Rect>()
    private let pendingDamage = ArrayList<Rect>()
    private var frameFull = false
    private var frameReason = "none"
    private var pendingFull = true
    private var pendingReason = "initial-frame"
    private var frameActive = false
    private var hasCommittedFrame = false
    private var committedContextCode: Int64 = 0
    private var pendingContextCode: Int64 = 0
    private var previousActive: ?RetainedUiRuntime = None
    private var lastFrameCommitted = false
    private var last = RetainedUiDamage(
        RetainedUiDamageKind.Full, "initial-frame", [])

    public func isFrameActive(): Bool { frameActive }
    func runtimeIdentity(): Int64 { identity }

    func currentNodeId(): String {
        if (phases.isEmpty()) { return "" }
        phases[phases.size - 1].nodeId
    }

    public func beginFrame(contextCode: Int64): Unit {
        if (frameActive) { throw IllegalStateException("Retained UI frame is already active") }
        lastFrameCommitted = false
        frameActive = true
        pendingContextCode = contextCode
        visitedNodes.clear()
        visitedDependencies.clear()
        addedNodeIds.clear()
        addedDependencyKeys.clear()
        phases.clear()
        frameDamage.clear()
        for (value in pendingDamage) { frameDamage.add(value) }
        pendingDamage.clear()
        frameFull = pendingFull || !hasCommittedFrame
        frameReason = if (pendingFull) { pendingReason } else if (!hasCommittedFrame) {
            "initial-frame"
        } else {
            "none"
        }
        pendingFull = false
        pendingReason = "none"
        if (hasCommittedFrame && contextCode != committedContextCode) {
            forceFull("root-context-changed")
            invalidateEveryPhase()
        }
        for ((_, node) in nodes) { node.resetTransaction() }
        previousActive = activeRetainedUiRuntime
        activeRetainedUiRuntime = Some(this)
    }

    public func declareNode(
        id: String,
        parentId: String,
        structureCode: Int64,
        layoutIsolated!: Bool = false
    ): Unit {
        ensureFrame()
        if (id.isEmpty()) { throw IllegalArgumentException("Retained UI node id must not be empty") }
        if (visitedNodes.contains(id)) {
            throw IllegalStateException("Duplicate retained UI node id '${id}'")
        }
        visitedNodes.add(id)
        match (nodes.get(id)) {
            case Some(node) =>
                node.pendingParentId = parentId
                node.pendingStructureCode = structureCode
                node.pendingLayoutIsolated = layoutIsolated
                if (node.parentId != parentId || node.structureCode != structureCode ||
                    node.layoutIsolated != layoutIsolated) {
                    invalidateNode(node, RetainedUiPhase.Build, "node-structure-changed")
                }
            case None =>
                let node = RetainedUiNodeRecord(id, parentId, structureCode, layoutIsolated)
                let _ = nodes.add(id, node)
                addedNodeIds.add(id)
                forceFull("node-added")
        }
    }

    public func beginPhase(
        id: String,
        phase: RetainedUiPhase,
        inputCode: Int64
    ): RetainedPhaseDecision {
        ensureFrame()
        let node = requireNode(id)
        let index = retainedUiPhaseIndex(phase)
        if (node.phaseComplete[index] && node.phaseInputs[index] != inputCode) {
            invalidateNode(node, phase, "phase-input-changed")
        }
        let reusable = node.phaseComplete[index] && !node.phaseDirty(index) &&
            node.phaseInputs[index] == inputCode
        if (reusable) { retainPhaseDependencies(id, phase) }
        phases.add(RetainedActivePhase(
            id, phase, inputCode, node.dirtyRevisions[index], reusable))
        RetainedPhaseDecision(id, phase, node.phaseGenerations[index], reusable)
    }

    /** Ends the innermost phase. `executed=false` is accepted only for a proven reuse hit. */
    public func endPhase(executed!: Bool = true): Unit {
        ensureFrame()
        if (phases.isEmpty()) { throw IllegalStateException("Retained UI phase stack is empty") }
        let active = phases.remove(at: phases.size - 1)
        if (!executed && !active.reusable) {
            forceFull("unsafe-phase-skip")
            return
        }
        if (!executed) { return }
        let node = requireNode(active.nodeId)
        let index = retainedUiPhaseIndex(active.phase)
        node.executed[index] = true
        node.executedInputs[index] = active.inputCode
        node.executedDirtyRevisions[index] = active.dirtyRevisionAtBegin
    }

    /** Records a complete paint proof produced by layout/provider code for this frame. */
    public func recordPaintProof(id: String, proof: RetainedPaintProof): Unit {
        ensureFrame()
        let node = requireNode(id)
        node.pendingPaintProof = Some(proof)
        match (node.paintProof) {
            case Some(previous) => if (!sameRetainedPaintProof(previous, proof)) {
                if (node.layoutIsolated && compatibleRetainedPaintProof(previous, proof)) {
                    appendProofDamage(previous)
                    appendProofDamage(proof)
                } else {
                    forceFull("paint-geometry-uncertain")
                }
            }
            case None => if (hasCommittedFrame && pixelPhasesDirty(node)) {
                forceFull("paint-proof-missing")
            }
        }
    }

    /**
     * Compares exact measurement inputs before the hash-backed phase ledger is consulted. Hashes
     * are scheduling hints only; an equality proof never depends on collision resistance.
     */
    public func prepareMeasureInput(id: String, available: Size, identity: ?String): Unit {
        ensureFrame()
        let node = requireNode(id)
        let index = retainedUiPhaseIndex(RetainedUiPhase.Measure)
        if (!node.phaseComplete[index]) { return }
        let availableMatches = match (node.measureAvailable) {
            case Some(value) => sameRetainedSize(value, available)
            case None => false
        }
        if (!availableMatches || !sameOptionalRetainedString(node.measureIdentity, identity)) {
            invalidateNode(node, RetainedUiPhase.Measure, "measure-input-changed")
        }
    }

    /** Stores an exact measurement input/output tuple for this transaction. */
    public func recordMeasureOutput(
        id: String,
        available: Size,
        identity: ?String,
        output: Size
    ): Unit {
        ensureFrame()
        let node = requireNode(id)
        let index = retainedUiPhaseIndex(RetainedUiPhase.Measure)
        if (node.phaseComplete[index]) {
            match (node.measureOutput) {
                case Some(previous) => if (!sameRetainedSize(previous, output)) {
                    // The exact inputs matched but the provider returned a different result. Keep
                    // this frame conservative, then commit the newly observed output. Re-dirtying
                    // Measure while it is executing would prevent that commit and make the node
                    // invalidate forever on every subsequent frame.
                    forceFull("measure-output-changed")
                    markDirtyRange(node, 2, RETAINED_UI_PHASE_COUNT)
                }
                case None => ()
            }
        }
        node.pendingMeasureOutput = Some(output)
        node.pendingMeasureAvailable = Some(available)
        node.pendingMeasureIdentity = identity
    }

    /** Returns the committed result only when its complete input tuple is exactly equal. */
    public func measureOutput(id: String, available: Size, identity: String): ?Size {
        ensureFrame()
        let node = requireNode(id)
        let inputMatches = match ((node.measureAvailable, node.measureIdentity)) {
            case (Some(previousAvailable), Some(previousIdentity)) =>
                sameRetainedSize(previousAvailable, available) && previousIdentity == identity
            case _ => false
        }
        if (inputMatches) { node.measureOutput } else { None }
    }

    /** Explicit invalidation seam for non-State runtime facts such as semantic/provider changes. */
    public func invalidate(id: String, phase: RetainedUiPhase, reason!: String = "explicit"): Unit {
        match (nodes.get(id)) {
            case Some(node) => invalidateNode(node, phase, reason)
            case None => requestFull(reason + "-unknown-node")
        }
    }

    public func damage(): RetainedUiDamage {
        ensureFrame()
        // Structural removal must be visible to the caller that chooses this frame's present
        // damage, not discovered only by finishFrame after pixels have already been submitted.
        // A removed subtree may reflow untracked siblings, so no bounded proof is attempted.
        for ((id, _) in nodes) {
            if (!visitedNodes.contains(id)) {
                forceFull("node-removed")
                break
            }
        }
        if (frameFull) {
            return RetainedUiDamage(RetainedUiDamageKind.Full, frameReason, [])
        }
        if (frameDamage.isEmpty()) {
            return RetainedUiDamage(RetainedUiDamageKind.Empty, "clean", [])
        }
        RetainedUiDamage(RetainedUiDamageKind.Bounded, "proven-node-damage", frameDamage.toArray())
    }

    public func finishFrame(): RetainedUiDamage {
        ensureFrame()
        if (!phases.isEmpty()) {
            cancelFrame()
            return RetainedUiDamage(RetainedUiDamageKind.Full, "unbalanced-phase-stack", [])
        }
        let result = damage()
        let removedNodes = ArrayList<String>()
        for ((id, _) in nodes) {
            if (!visitedNodes.contains(id)) { removedNodes.add(id) }
        }
        if (!removedNodes.isEmpty()) {
            // A removed subtree can reflow arbitrary untracked siblings. No local bound is claimed.
            requestFull("node-removed")
            for (id in removedNodes) { let _ = nodes.remove(id) }
        }
        pruneDependencies()
        for (id in visitedNodes) {
            match (nodes.get(id)) {
                case Some(node) => commitNode(node)
                case None => ()
            }
        }
        hasCommittedFrame = true
        committedContextCode = pendingContextCode
        last = if (frameFull) {
            RetainedUiDamage(RetainedUiDamageKind.Full, frameReason, [])
        } else {
            result
        }
        restoreActiveRuntime()
        frameActive = false
        lastFrameCommitted = true
        // A phase invalidated while it was executing was not clean at commit. Carry its old/new
        // paint proof into the next frame instead of allowing one clipped frame to hide the write.
        carryDirtyPixelsToNextFrame()
        last
    }

    public func cancelFrame(): Unit {
        if (!frameActive) { return }
        lastFrameCommitted = false
        for (key in addedDependencyKeys) { removeDependency(key) }
        for (id in addedNodeIds) { let _ = nodes.remove(id) }
        for ((_, node) in nodes) { markEveryPhaseDirty(node) }
        phases.clear()
        restoreActiveRuntime()
        frameActive = false
        requestFull("frame-cancelled")
        last = RetainedUiDamage(RetainedUiDamageKind.Full, "frame-cancelled", [])
    }

    public func lastDamage(): RetainedUiDamage { last }

    /** Lets StateStore align its remembered-state transaction with the retained present commit. */
    func lastFrameCommittedSuccessfully(): Bool { lastFrameCommitted }

    public func phaseGeneration(id: String, phase: RetainedUiPhase): UInt64 {
        match (nodes.get(id)) {
            case Some(node) => node.phaseGenerations[retainedUiPhaseIndex(phase)]
            case None => UInt64(0)
        }
    }

    public func clear(): Unit {
        if (frameActive) { cancelFrame() }
        lastFrameCommitted = false
        let keys = ArrayList<String>()
        for ((key, _) in dependencies) { keys.add(key) }
        for (key in keys) { removeDependency(key) }
        nodes.clear()
        pendingDamage.clear()
        requestFull("runtime-cleared")
        hasCommittedFrame = false
    }

    func recordStateRead(stateId: Int64): Unit {
        if (!frameActive || phases.isEmpty()) { return }
        // A draw runs Paint and Semantics together. Record every active scope instead of only the
        // innermost phase so a semantic read cannot accidentally disappear from pixel invalidation.
        for (active in phases) {
            let key = retainedDependencyKey(stateId, active.nodeId, active.phase)
            visitedDependencies.add(key)
            if (!dependencies.contains(key)) {
                let _ = dependencies.add(
                    key, RetainedStateDependency(key, stateId, active.nodeId, active.phase))
                addedDependencyKeys.add(key)
                registerRetainedRuntimeForState(stateId, this)
            }
        }
    }

    func invalidateState(stateId: Int64): Unit {
        for ((_, dependency) in dependencies) {
            if (dependency.stateId == stateId) {
                match (nodes.get(dependency.nodeId)) {
                    case Some(node) => invalidateNode(node, dependency.phase, "state-write")
                    case None => requestFull("state-write-unknown-node")
                }
            }
        }
    }

    private func invalidateNode(
        node: RetainedUiNodeRecord,
        phase: RetainedUiPhase,
        reason: String
    ): Unit {
        let start = retainedUiPhaseIndex(phase)
        match (phase) {
            case RetainedUiPhase.Build => markDirtyRange(node, 0, RETAINED_UI_PHASE_COUNT)
            case RetainedUiPhase.Measure => markDirtyRange(node, 1, RETAINED_UI_PHASE_COUNT)
            case RetainedUiPhase.Layout => markDirtyRange(node, 2, RETAINED_UI_PHASE_COUNT)
            case RetainedUiPhase.Paint => markDirtyRange(node, 3, 4)
            case RetainedUiPhase.Semantics => markDirtyRange(node, 4, 5)
            case RetainedUiPhase.HitTest => markDirtyRange(node, 5, 6)
        }
        if (start >= 4) { return }
        match (node.paintProof) {
            case Some(proof) where proof.proven =>
                if (phase == RetainedUiPhase.Paint || node.layoutIsolated) {
                    appendProofDamage(proof)
                } else {
                    requestFull(reason + "-layout-unisolated")
                }
            case _ => requestFull(reason + "-paint-unproven")
        }
    }

    private func markDirtyRange(node: RetainedUiNodeRecord, from: Int64, to: Int64): Unit {
        for (i in from..to) {
            node.dirtyRevisions[i] = nextRevision(node.dirtyRevisions[i])
        }
    }

    private func markEveryPhaseDirty(node: RetainedUiNodeRecord): Unit {
        markDirtyRange(node, 0, RETAINED_UI_PHASE_COUNT)
    }

    private func invalidateEveryPhase(): Unit {
        for ((_, node) in nodes) { markEveryPhaseDirty(node) }
    }

    private func commitNode(node: RetainedUiNodeRecord): Unit {
        node.parentId = node.pendingParentId
        node.structureCode = node.pendingStructureCode
        node.layoutIsolated = node.pendingLayoutIsolated
        for (i in 0..RETAINED_UI_PHASE_COUNT) {
            if (node.executed[i] &&
                node.executedDirtyRevisions[i] == node.dirtyRevisions[i]) {
                node.phaseInputs[i] = node.executedInputs[i]
                node.phaseComplete[i] = true
                node.cleanRevisions[i] = node.dirtyRevisions[i]
                node.phaseGenerations[i] = nextRevision(node.phaseGenerations[i])
            }
        }
        match (node.pendingPaintProof) {
            case Some(value) => node.paintProof = Some(value)
            case None => ()
        }
        let measureIndex = retainedUiPhaseIndex(RetainedUiPhase.Measure)
        if (node.executed[measureIndex] &&
            node.executedDirtyRevisions[measureIndex] == node.dirtyRevisions[measureIndex]) {
            match (node.pendingMeasureOutput) {
                case Some(value) =>
                    node.measureOutput = Some(value)
                    node.measureAvailable = node.pendingMeasureAvailable
                    node.measureIdentity = node.pendingMeasureIdentity
                case None =>
                    node.measureOutput = None
                    node.measureAvailable = None
                    node.measureIdentity = None
            }
        }
        node.resetTransaction()
    }

    private func carryDirtyPixelsToNextFrame(): Unit {
        for ((_, node) in nodes) {
            if (!pixelPhasesDirty(node)) { continue }
            match (node.paintProof) {
                case Some(proof) where proof.proven =>
                    if (node.layoutIsolated || onlyPaintPhaseDirty(node)) {
                        appendPendingProofDamage(proof)
                    } else {
                        requestFull("dirty-phase-carried")
                    }
                case _ => requestFull("dirty-phase-unproven")
            }
        }
    }

    private func pruneDependencies(): Unit {
        let obsolete = ArrayList<String>()
        for ((key, _) in dependencies) {
            if (!visitedDependencies.contains(key)) { obsolete.add(key) }
        }
        for (key in obsolete) { removeDependency(key) }
    }

    private func retainPhaseDependencies(id: String, phase: RetainedUiPhase): Unit {
        for ((key, dependency) in dependencies) {
            if (dependency.nodeId == id && dependency.phase == phase) {
                visitedDependencies.add(key)
            }
        }
    }

    private func removeDependency(key: String): Unit {
        match (dependencies.remove(key)) {
            case Some(dependency) => if (!hasStateDependency(dependency.stateId)) {
                unregisterRetainedRuntimeForState(dependency.stateId, identity)
            }
            case None => ()
        }
    }

    private func hasStateDependency(stateId: Int64): Bool {
        for ((_, dependency) in dependencies) {
            if (dependency.stateId == stateId) { return true }
        }
        false
    }

    private func appendProofDamage(proof: RetainedPaintProof): Unit {
        match (retainedProofDamageRect(proof)) {
            case Some(value) => appendFrameDamage(value)
            case None => requestFull("paint-proof-outside-or-invalid")
        }
    }

    private func appendPendingProofDamage(proof: RetainedPaintProof): Unit {
        match (retainedProofDamageRect(proof)) {
            case Some(value) =>
                if (pendingDamage.size >= RETAINED_UI_MAX_DAMAGE_RECTS) {
                    requestFull("damage-rectangle-cap")
                } else if (!containsRetainedRect(pendingDamage, value)) {
                    pendingDamage.add(value)
                }
            case None => requestFull("paint-proof-outside-or-invalid")
        }
    }

    private func appendFrameDamage(value: Rect): Unit {
        if (frameActive) {
            if (frameDamage.size >= RETAINED_UI_MAX_DAMAGE_RECTS) {
                forceFull("damage-rectangle-cap")
            } else if (!containsRetainedRect(frameDamage, value)) {
                frameDamage.add(value)
            }
        } else if (pendingDamage.size >= RETAINED_UI_MAX_DAMAGE_RECTS) {
            requestFull("damage-rectangle-cap")
        } else if (!containsRetainedRect(pendingDamage, value)) {
            pendingDamage.add(value)
        }
    }

    private func forceFull(reason: String): Unit {
        frameFull = true
        if (frameReason == "none") { frameReason = reason }
        frameDamage.clear()
    }

    private func requestFull(reason: String): Unit {
        if (frameActive) {
            forceFull(reason)
        } else {
            pendingFull = true
            if (pendingReason == "none") { pendingReason = reason }
            pendingDamage.clear()
        }
    }

    private func requireNode(id: String): RetainedUiNodeRecord {
        match (nodes.get(id)) {
            case Some(node) => node
            case None => throw IllegalStateException("Retained UI node '${id}' was not declared")
        }
    }

    private func ensureFrame(): Unit {
        if (!frameActive) { throw IllegalStateException("Retained UI frame is not active") }
    }

    private func restoreActiveRuntime(): Unit {
        activeRetainedUiRuntime = previousActive
        previousActive = None
    }
}

private func retainedDependencyKey(
    stateId: Int64,
    nodeId: String,
    phase: RetainedUiPhase
): String {
    stateId.toString() + "|" + nodeId + "|" + retainedUiPhaseIndex(phase).toString()
}

private func registerRetainedRuntimeForState(
    stateId: Int64,
    runtime: RetainedUiRuntime
): Unit {
    match (retainedStateRuntimes.get(stateId)) {
        case Some(values) =>
            for (value in values) {
                if (value.runtimeIdentity() == runtime.runtimeIdentity()) { return }
            }
            values.add(runtime)
        case None =>
            let values = ArrayList<RetainedUiRuntime>()
            values.add(runtime)
            let _ = retainedStateRuntimes.add(stateId, values)
    }
}

private func unregisterRetainedRuntimeForState(stateId: Int64, runtimeId: Int64): Unit {
    match (retainedStateRuntimes.get(stateId)) {
        case Some(values) =>
            var i = values.size - 1
            while (i >= 0) {
                if (values[i].runtimeIdentity() == runtimeId) { values.remove(at: i) }
                i -= 1
            }
            if (values.isEmpty()) { let _ = retainedStateRuntimes.remove(stateId) }
        case None => ()
    }
}

private func pixelPhasesDirty(node: RetainedUiNodeRecord): Bool {
    node.phaseDirty(0) || node.phaseDirty(1) || node.phaseDirty(2) || node.phaseDirty(3)
}

private func onlyPaintPhaseDirty(node: RetainedUiNodeRecord): Bool {
    !node.phaseDirty(0) && !node.phaseDirty(1) && !node.phaseDirty(2) && node.phaseDirty(3)
}

private func sameRetainedPaintProof(
    first: RetainedPaintProof,
    second: RetainedPaintProof
): Bool {
    sameRetainedRect(first.bounds, second.bounds) &&
        sameOptionalRetainedRect(first.clip, second.clip) &&
        first.transformCode == second.transformCode &&
        first.effectRadius == second.effectRadius &&
        first.ancestorContextCode == second.ancestorContextCode &&
        first.proven == second.proven
}

private func compatibleRetainedPaintProof(
    first: RetainedPaintProof,
    second: RetainedPaintProof
): Bool {
    first.proven && second.proven &&
        sameOptionalRetainedRect(first.clip, second.clip) &&
        first.transformCode == second.transformCode &&
        first.effectRadius == second.effectRadius &&
        first.ancestorContextCode == second.ancestorContextCode
}

private func retainedProofDamageRect(proof: RetainedPaintProof): ?Rect {
    if (!proof.proven) { return None }
    let expanded = Rect(
        proof.bounds.x - proof.effectRadius,
        proof.bounds.y - proof.effectRadius,
        proof.bounds.w + proof.effectRadius * 2.0,
        proof.bounds.h + proof.effectRadius * 2.0)
    if (!retainedRectIsFinitePositive(expanded)) { return None }
    match (proof.clip) {
        case Some(clip) =>
            let clipped = expanded.intersection(clip)
            if (retainedRectIsFinitePositive(clipped)) { Some(clipped) } else { None }
        case None => Some(expanded)
    }
}

private func retainedRectIsFinitePositive(value: Rect): Bool {
    value.x == value.x && value.y == value.y && value.w == value.w && value.h == value.h &&
        value.w > 0.0 && value.h > 0.0 && value.right() == value.right() &&
        value.bottom() == value.bottom()
}

private func sameOptionalRetainedRect(first: ?Rect, second: ?Rect): Bool {
    match ((first, second)) {
        case (Some(a), Some(b)) => sameRetainedRect(a, b)
        case (None, None) => true
        case _ => false
    }
}

private func sameRetainedRect(first: Rect, second: Rect): Bool {
    first.x == second.x && first.y == second.y && first.w == second.w && first.h == second.h
}

private func sameRetainedSize(first: Size, second: Size): Bool {
    first.w == second.w && first.h == second.h
}

private func sameOptionalRetainedString(first: ?String, second: ?String): Bool {
    match ((first, second)) {
        case (Some(a), Some(b)) => a == b
        case (None, None) => true
        case _ => false
    }
}

private func containsRetainedRect(values: ArrayList<Rect>, target: Rect): Bool {
    for (value in values) {
        if (sameRetainedRect(value, target)) { return true }
    }
    false
}

protected func retainedUiStableCode(value: String): Int64 {
    var code: Int64 = 37
    for (byte in value.toArray()) {
        code = (code * 131 + Int64(byte)) % 2147483647
    }
    max(Int64(1), code)
}

/** Bounded combiner for protected retained-provider fingerprints. */
protected func retainedUiCombineCode(seed: Int64, value: Int64): Int64 {
    var left = seed % 2147483647
    var right = value % 2147483647
    if (left < 0) { left += 2147483647 }
    if (right < 0) { right += 2147483647 }
    max(Int64(1), (left * 131 + right) % 2147483647)
}

/** Exact-enough finite float fingerprint used only for invalidation, never serialization. */
protected func retainedUiFloatCode(value: Float32): Int64 {
    retainedFloatCode(value)
}

private func retainedFloatCode(value: Float32): Int64 {
    // Keep every sentinel inside the range that the later size/rectangle hash multipliers can
    // combine without overflowing Int64. The code is an invalidation fingerprint, not a numeric
    // serialization of the original coordinate.
    if (value != value) { return -2147483647 }
    if (value > 2147483.0) { return 2147483647 }
    if (value < -2147483.0) { return -2147483646 }
    Int64(value * 1000.0)
}

private func retainedSizeCode(value: Size): Int64 {
    retainedFloatCode(value.w) * 65537 + retainedFloatCode(value.h)
}

private func retainedRectCode(value: Rect): Int64 {
    var code = retainedFloatCode(value.x)
    code = code * 131 + retainedFloatCode(value.y)
    code = code * 137 + retainedFloatCode(value.w)
    code * 139 + retainedFloatCode(value.h)
}

/**
 * Adapts only framework-owned widgets with a complete proof. The adapter classes are internal so
 * their necessarily-public interface members do not widen Label or Surface's public API.
 */
internal func retainedProviderAdapter(child: Widget): Widget {
    if ((child as RetainedMeasureOutputProvider).isSome() ||
        (child as RetainedPaintProofProvider).isSome()) {
        return child
    }
    match (child as Label) {
        case Some(value) => return RetainedLabelMeasureAdapter(child, value)
        case None => ()
    }
    match (child as Surface) {
        case Some(value) => RetainedSurfacePaintAdapter(child, value)
        case None => child
    }
}

private class RetainedLabelMeasureAdapter <: Widget & RetainedMeasureOutputProvider {
    private let child: Widget
    private let label: Label

    init(child: Widget, label: Label) {
        this.child = child
        this.label = label
    }

    public func retainedMeasureInputIdentity(ctx: UiContext): String {
        label.retainedMeasureInputIdentity(ctx)
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { child.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { child.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

private class RetainedSurfacePaintAdapter <: Widget & RetainedPaintProofProvider {
    private let child: Widget
    private let sourceSurface: Surface

    init(child: Widget, surface: Surface) {
        this.child = child
        this.sourceSurface = surface
    }

    public func retainedPaintProof(ctx: UiContext, frame: Rect): ?RetainedPaintProof {
        sourceSurface.retainedPaintProof(ctx, frame)
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { child.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { child.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

/**
 * Internal wrapper that attaches ordinary Widget callbacks to one stable retained node. It skips
 * measurement only for the narrow RetainedMeasureOutputProvider contract; generic rebuilt Widget
 * instances still execute every callback. Paint is bounded only when an explicit provider proves
 * the complete subtree extent, otherwise mutation uncertainty remains full-root damage.
 */
class RetainedWidgetNode <: Widget {
    private let id: String
    private let child: Widget
    private let runtime: RetainedUiRuntime
    private var layoutFrame: ?Rect = None

    init(id: String, child: Widget, runtime: RetainedUiRuntime) {
        this.id = id
        this.child = child
        this.runtime = runtime
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let provider = child as RetainedMeasureOutputProvider
        let identity = match (provider) {
            case Some(value) => Some(value.retainedMeasureInputIdentity(ctx))
            case None => None<String>
        }
        runtime.prepareMeasureInput(id, available, identity)
        let providerCode = match (identity) {
            case Some(value) => retainedUiStableCode(value)
            case None => Int64(-1)
        }
        let decision = runtime.beginPhase(id, RetainedUiPhase.Measure,
            retainedUiCombineCode(retainedSizeCode(available), providerCode))
        if (decision.canReuse) {
            match (identity) {
                case Some(value) => match (runtime.measureOutput(id, available, value)) {
                    case Some(output) =>
                        runtime.endPhase(executed: false)
                        return output
                    case None => ()
                }
                case None => ()
            }
        }
        try {
            let result = child.measure(ctx, available)
            runtime.recordMeasureOutput(id, available, identity, result)
            result
        } finally {
            runtime.endPhase()
        }
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let _ = runtime.beginPhase(id, RetainedUiPhase.Layout, retainedRectCode(rect))
        try {
            child.layout(ctx, rect)
            layoutFrame = Some(rect)
            refreshPaintProof(ctx, rect)
        } finally {
            runtime.endPhase()
        }
    }

    public func draw(ctx: UiContext): Unit {
        let _ = runtime.beginPhase(id, RetainedUiPhase.Paint, Int64(1))
        let _ = runtime.beginPhase(id, RetainedUiPhase.Semantics, Int64(1))
        try {
            child.draw(ctx)
            // Builder-style Surface properties are mutable. An event runs between layout and draw,
            // so refresh the proof after the pixels were actually emitted; a newly unknown painter,
            // clip or material then promotes this very frame to Full instead of hiding damage.
            match (layoutFrame) {
                case Some(frame) => refreshPaintProof(ctx, frame)
                case None => ()
            }
        } finally {
            runtime.endPhase()
            runtime.endPhase()
        }
    }

    private func refreshPaintProof(ctx: UiContext, frame: Rect): Unit {
        let proof = match (child as RetainedPaintProofProvider) {
            case Some(provider) => provider.retainedPaintProof(ctx, frame)
            case None => None<RetainedPaintProof>
        }
        match (proof) {
            case Some(value) => runtime.recordPaintProof(id, value)
            case None => runtime.recordPaintProof(id, RetainedPaintProof(frame, proven: false))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let _ = runtime.beginPhase(id, RetainedUiPhase.HitTest, Int64(1))
        try {
            child.handle(ctx, event)
        } finally {
            runtime.endPhase()
        }
    }

    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}
