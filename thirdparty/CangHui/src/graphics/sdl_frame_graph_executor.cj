package chui.graphics

import std.collection.ArrayList
import sdl.{Color, Rect, Renderer, Texture}
import chui.framegraph_sdl.createFrameGraphCopyTargetTexture

private let SDL_FRAME_DEFAULT_MAX_SURFACE_PIXELS: Int64 = 16777216

/** Conservative physical allocation count kept inside the protected FrameGraph provider lane. */
protected func sdlFramePhysicalPixelCount(
    logicalWidth: Int64,
    logicalHeight: Int64,
    physicalPixelScale: Float32
): Int64 {
    if (logicalWidth <= 0 || logicalHeight <= 0 || physicalPixelScale <= 0.0) {
        return Int64(0)
    }
    let pixelWidthValue = max(Float32(1.0), Float32(logicalWidth) * physicalPixelScale) + Float32(0.5)
    let pixelHeightValue = max(Float32(1.0), Float32(logicalHeight) * physicalPixelScale) + Float32(0.5)
    if (pixelWidthValue > 2147483000.0 || pixelHeightValue > 2147483000.0) {
        return Int64.Max
    }
    let pixelWidth = Int64(pixelWidthValue)
    let pixelHeight = Int64(pixelHeightValue)
    if (pixelWidth > Int64.Max / pixelHeight) { return Int64.Max }
    pixelWidth * pixelHeight
}

/**
 * Runtime-only work for one compiled pass. The closure is held by the SDL executor and is never
 * copied into a descriptor, schedule hash or trace.
 */
private class SdlFramePassBinding {
    let id: FramePassId
    let action: (SdlFramePassContext) -> FramePassExecutionResult

    init(id: FramePassId, action: (SdlFramePassContext) -> FramePassExecutionResult) {
        this.id = id
        this.action = action
    }
}

private class SdlFramePassResultBox {
    var value = FramePassExecutionResult(true, "accepted")
}

/**
 * The live context seen by a pass binding. A binding may transfer ownership of one native resource
 * for each graph-declared transient ID; the session releases those resources in reverse order,
 * exactly once, on commit or rollback.
 */
protected class SdlFramePassContext {
    public let renderer: Renderer
    public let graph: CompiledFrameGraph
    public let pass: CompiledFramePass
    public let unifiedPixels: Bool
    private let manage: (FrameResourceId, Resource) -> Unit

    init(
        renderer: Renderer,
        graph: CompiledFrameGraph,
        pass: CompiledFramePass,
        unifiedPixels: Bool,
        manage: (FrameResourceId, Resource) -> Unit
    ) {
        this.renderer = renderer
        this.graph = graph
        this.pass = pass
        this.unifiedPixels = unifiedPixels
        this.manage = manage
    }

    /** Transfers one declared transient resource to the current frame transaction. */
    public func manageTransient(id: FrameResourceId, resource: Resource): Unit {
        manage(id, resource)
    }
}

/** Provider-local truth supplementing the provider-neutral `FrameExecutionReceipt`. */
protected class SdlFrameExecutorReceipt {
    public let ok: Bool
    public let code: String
    public let frameId: Int64
    public let redrawMode: FrameRedrawMode
    public let presentMode: FramePresentMode
    public let presentStrategy: FramePresentStrategy
    public let deviceBacked: Bool
    public let unifiedPixels: Bool
    public let nativeChildBarrierCount: Int64
    public let completedPassCount: Int64
    public let managedTransientCount: Int64
    public let releasedTransientCount: Int64
    public let cleanupFailureCount: Int64
    public let legacyFallbackUsed: Bool
    public let legacyFallbackRequired: Bool

    public init(
        ok: Bool,
        code: String,
        frameId: Int64,
        redrawMode: FrameRedrawMode,
        presentMode: FramePresentMode,
        presentStrategy: FramePresentStrategy,
        deviceBacked: Bool,
        unifiedPixels: Bool,
        nativeChildBarrierCount: Int64,
        completedPassCount: Int64,
        managedTransientCount: Int64,
        releasedTransientCount: Int64,
        cleanupFailureCount: Int64,
        legacyFallbackUsed: Bool,
        legacyFallbackRequired: Bool
    ) {
        this.ok = ok
        this.code = code
        this.frameId = frameId
        this.redrawMode = redrawMode
        this.presentMode = presentMode
        this.presentStrategy = presentStrategy
        this.deviceBacked = deviceBacked
        this.unifiedPixels = unifiedPixels
        this.nativeChildBarrierCount = nativeChildBarrierCount
        this.completedPassCount = completedPassCount
        this.managedTransientCount = managedTransientCount
        this.releasedTransientCount = releasedTransientCount
        this.cleanupFailureCount = cleanupFailureCount
        this.legacyFallbackUsed = legacyFallbackUsed
        this.legacyFallbackRequired = legacyFallbackRequired
    }
}

/**
 * SDL live executor.
 *
 * A device-backed session keeps the previous committed texture untouched while execution groups
 * draw into one transaction-owned staging texture. The previous frame is copied once only when a
 * bounded redraw needs it; later groups preserve the staging target. Only `commit` installs that
 * texture and calls SDL's full-surface present. SDL has no portable partial-present primitive, so
 * `supportsPartialPresent` is always false even when pass drawing is clipped to bounded damage.
 */
protected class SdlFrameGraphExecutor <: FrameGraphExecutor & Resource {
    private let renderer: Renderer
    private var clearColor: Color
    private let maxSurfacePixels: Int64
    private let maxDeclaredResourceBytes: Int64
    private let physicalPixelScale: Float32
    private let deviceBacked: Bool
    private let bindings = ArrayList<SdlFramePassBinding>()
    private var bindingSnapshot: Array<SdlFramePassBinding> = []
    private var bindingsDirty = true
    private var bindingSnapshotBuilds: Int64 = 0
    private var beforePresent: () -> Unit = { => () }
    private var committed: ?Texture = None
    private var committedSurfaceKey: String = ""
    private var committedSurfaceGeneration: Int64 = 0
    private var committedWidth: Int64 = 0
    private var committedHeight: Int64 = 0
    private var boundedAvailable: Bool
    private var sessionActive = false
    private var closed = false
    private var receipt = SdlFrameExecutorReceipt(
        true, "idle", 0, FrameRedrawMode.Skipped, FramePresentMode.NotPresented,
        FramePresentStrategy.NotPresented,
        false, true, 0, 0, 0, 0, 0, false, false)

    public init(
        renderer: Renderer,
        clearColor!: Color = Color.rgba(0, 0, 0, 0),
        physicalPixelScale!: Float32 = 1.0,
        maxSurfacePixels!: Int64 = SDL_FRAME_DEFAULT_MAX_SURFACE_PIXELS,
        maxDeclaredResourceBytes!: Int64 = 268435456,
        assumeDeviceBackedForConformance!: Bool = false
    ) {
        if (maxSurfacePixels <= 0) {
            throw IllegalArgumentException("SDL frame executor surface-pixel cap must be positive")
        }
        if (physicalPixelScale <= 0.0) {
            throw IllegalArgumentException("SDL frame executor physical-pixel scale must be positive")
        }
        // Reuse the contract constructor for the declared-byte hard-cap check.
        let _ = FrameGraphExecutorCapabilities(maxDeclaredResourceBytes: maxDeclaredResourceBytes)
        this.renderer = renderer
        this.clearColor = clearColor
        this.maxSurfacePixels = maxSurfacePixels
        this.maxDeclaredResourceBytes = maxDeclaredResourceBytes
        this.physicalPixelScale = physicalPixelScale
        this.deviceBacked = renderer.driverName() != "headless" || assumeDeviceBackedForConformance
        this.boundedAvailable = this.deviceBacked
        this.receipt = SdlFrameExecutorReceipt(
            true, "idle", 0, FrameRedrawMode.Skipped, FramePresentMode.NotPresented,
            FramePresentStrategy.NotPresented,
            this.deviceBacked, true, 0, 0, 0, 0, 0, false, false)
    }

    /** Replaces any earlier runtime action for the same stable pass ID. */
    public func bindPass(
        id: FramePassId,
        action: (SdlFramePassContext) -> FramePassExecutionResult
    ): Unit {
        ensureOpen()
        for (i in 0..bindings.size) {
            if (bindings[i].id == id) {
                bindings[i] = SdlFramePassBinding(id, action)
                bindingsDirty = true
                return
            }
        }
        bindings.add(SdlFramePassBinding(id, action))
        bindingsDirty = true
    }

    public func unbindPass(id: FramePassId): Bool {
        ensureOpen()
        for (i in 0..bindings.size) {
            if (bindings[i].id == id) {
                bindings.remove(at: i)
                bindingsDirty = true
                return true
            }
        }
        false
    }

    /** Replaces all runtime-only actions between sessions. */
    public func clearPassBindings(): Unit {
        ensureOpen()
        ensureNoActiveSession("clear SDL frame pass bindings")
        bindings.clear()
        bindingsDirty = true
    }

    /** Updates the background used by sessions begun after this call. */
    public func setClearColor(value: Color): Unit {
        ensureOpen()
        ensureNoActiveSession("change SDL frame clear color")
        clearColor = value
    }

    /** Installs one session-snapshotted hook after resolve/endScene and before full present. */
    public func setBeforePresent(action: () -> Unit): Unit {
        ensureOpen()
        ensureNoActiveSession("change SDL before-present hook")
        beforePresent = action
    }

    public func bindingCount(): Int64 { bindings.size }
    public func bindingSnapshotBuildCount(): Int64 { bindingSnapshotBuilds }
    public func lastReceipt(): SdlFrameExecutorReceipt { receipt }
    public func hasCommittedFrame(): Bool { committed.isSome() }
    public func isClosed(): Bool { closed }

    /**
     * Records that an upper layer actually replayed the required legacy renderer fallback. A
     * positive `frameId` also covers compiler rejection before this executor could open a session.
     */
    public func markLegacyFallbackUsed(
        frameId!: Int64 = 0,
        nativeChildBarrierCount!: Int64 = 0
    ): Bool {
        ensureOpen()
        ensureNoActiveSession("mark SDL legacy fallback")
        if (frameId < 0 || nativeChildBarrierCount < 0) {
            throw IllegalArgumentException("SDL legacy fallback identity must be non-negative")
        }
        if (receipt.legacyFallbackRequired && !receipt.legacyFallbackUsed &&
            (frameId == 0 || receipt.frameId == frameId)) {
            receipt = SdlFrameExecutorReceipt(
                true,
                "accepted-legacy-fallback",
                receipt.frameId,
                FrameRedrawMode.Full,
                FramePresentMode.Full,
                FramePresentStrategy.UnsupportedFallback,
                receipt.deviceBacked,
                receipt.unifiedPixels,
                receipt.nativeChildBarrierCount,
                receipt.completedPassCount,
                receipt.managedTransientCount,
                receipt.releasedTransientCount,
                receipt.cleanupFailureCount,
                true,
                receipt.legacyFallbackRequired)
            return true
        }
        if (frameId <= 0) { return false }
        receipt = SdlFrameExecutorReceipt(
            true,
            "accepted-legacy-fallback",
            frameId,
            FrameRedrawMode.Full,
            FramePresentMode.Full,
            FramePresentStrategy.UnsupportedFallback,
            deviceBacked,
            nativeChildBarrierCount == 0,
            nativeChildBarrierCount,
            0,
            0,
            0,
            0,
            true,
            true)
        true
    }

    public func capabilities(): FrameGraphExecutorCapabilities {
        FrameGraphExecutorCapabilities(
            supportsBoundedRedraw: boundedAvailable && !closed,
            supportsPartialPresent: false,
            supportsSharedTexture: deviceBacked && !closed,
            supportsExtendedDynamicRange: false,
            maxDeclaredResourceBytes: maxDeclaredResourceBytes)
    }

    public func begin(graph: CompiledFrameGraph): FrameGraphExecutionSession {
        ensureOpen()
        if (sessionActive) {
            throw IllegalStateException("SDL frame executor already owns an active session")
        }
        sessionActive = true
        SdlFrameGraphExecutionSession(
            this, renderer, graph, frozenBindings(), clearColor, beforePresent,
            maxSurfacePixels, physicalPixelScale, deviceBacked)
    }

    public func close(): Unit {
        if (closed) { return }
        ensureNoActiveSession("close SDL frame executor")
        closed = true
        boundedAvailable = false
        closeCommitted()
    }

    func committedFor(graph: CompiledFrameGraph): ?Texture {
        if (committedSurfaceKey == graph.source.surfaceKey &&
            committedSurfaceGeneration == graph.source.surfaceGeneration &&
            committedWidth == graph.source.surfaceWidth && committedHeight == graph.source.surfaceHeight) {
            committed
        } else {
            None<Texture>
        }
    }

    func installCommitted(graph: CompiledFrameGraph, texture: Texture): Unit {
        closeCommitted()
        committed = Some(texture)
        committedSurfaceKey = graph.source.surfaceKey
        committedSurfaceGeneration = graph.source.surfaceGeneration
        committedWidth = graph.source.surfaceWidth
        committedHeight = graph.source.surfaceHeight
        boundedAvailable = deviceBacked
    }

    func discardCommittedAndBounded(): Unit {
        closeCommitted()
        boundedAvailable = false
    }

    func disableBounded(): Unit { boundedAvailable = false }

    func finishSession(value: SdlFrameExecutorReceipt): Unit {
        receipt = value
        sessionActive = false
    }

    private func closeCommitted(): Unit {
        match (committed) {
            case Some(texture) => texture.close()
            case None => ()
        }
        committed = None
        committedSurfaceKey = ""
        committedSurfaceGeneration = 0
        committedWidth = 0
        committedHeight = 0
    }

    private func ensureOpen(): Unit {
        if (closed) { throw IllegalStateException("SDL frame executor is closed") }
    }

    private func frozenBindings(): Array<SdlFramePassBinding> {
        if (bindingsDirty) {
            bindingSnapshot = bindings.toArray()
            bindingsDirty = false
            bindingSnapshotBuilds += 1
        }
        bindingSnapshot
    }

    private func ensureNoActiveSession(operation: String): Unit {
        if (sessionActive) {
            throw IllegalStateException("Cannot ${operation} while an SDL frame session is active")
        }
    }
}

private class SdlManagedFrameTransient {
    let id: FrameResourceId
    private let resource: Resource
    private var released = false

    init(id: FrameResourceId, resource: Resource) {
        this.id = id
        this.resource = resource
    }

    func isReleased(): Bool { released }

    /** Returns false only when the one permitted close attempt throws. */
    func release(): Bool {
        if (released) { return true }
        released = true
        try {
            resource.close()
            true
        } catch (_: Exception) {
            false
        }
    }
}

private class SdlFrameGraphExecutionSession <: FrameGraphExecutionSession {
    private let owner: SdlFrameGraphExecutor
    private let renderer: Renderer
    private let graph: CompiledFrameGraph
    private let bindings: Array<SdlFramePassBinding>
    private let clearColor: Color
    private let beforePresent: () -> Unit
    private let maxSurfacePixels: Int64
    private let deviceBacked: Bool
    private let transients = ArrayList<SdlManagedFrameTransient>()
    private var working: ?Texture = None
    private var sceneOpen = false
    private var closed = false
    private var failed = false
    private var failureCode = "none"
    private var nextGroupIndex: Int64 = 0
    private var completedPassCount: Int64 = 0
    private var nativeChildBarrierCount: Int64 = 0
    private var unifiedPixels = true
    private var presentRequested = false
    private var legacyDirect = false
    private var standardGroupCount: Int64 = 0
    private var releasedTransientCount: Int64 = 0
    private var cleanupFailureCount: Int64 = 0
    private let planCode: String

    init(
        owner: SdlFrameGraphExecutor,
        renderer: Renderer,
        graph: CompiledFrameGraph,
        bindings: Array<SdlFramePassBinding>,
        clearColor: Color,
        beforePresent: () -> Unit,
        maxSurfacePixels: Int64,
        physicalPixelScale: Float32,
        deviceBacked: Bool
    ) {
        this.owner = owner
        this.renderer = renderer
        this.graph = graph
        this.bindings = bindings
        this.clearColor = clearColor
        this.beforePresent = beforePresent
        this.maxSurfacePixels = maxSurfacePixels
        this.deviceBacked = deviceBacked
        this.planCode = validateSdlFramePlan(
            graph,
            maxSurfacePixels,
            deviceBacked,
            sdlFramePhysicalPixelCount(
                graph.source.surfaceWidth, graph.source.surfaceHeight, physicalPixelScale))
    }

    public func execute(group: CompiledFramePassGroup): FramePassExecutionResult {
        if (closed) { return FramePassExecutionResult(false, "session-closed") }
        if (failed) { return FramePassExecutionResult(false, failureCode) }
        if (planCode != "accepted") { return fail(planCode) }
        if (!matchesExpectedGroup(group)) { return fail("unexpected-execution-group") }
        if (presentRequested) { return fail("pass-after-present") }

        let first = group.passAt(0)
        let kind = first.descriptor.kind
        let result = if (kind == FramePassKind.Present) {
            executePresentGroup(group)
        } else if (kind == FramePassKind.ExternalScene3D) {
            executeExternalGroup(group)
        } else {
            executeRasterGroup(group)
        }
        if (result.ok) {
            nextGroupIndex += 1
            completedPassCount += group.passCount()
        }
        result
    }

    public func commit(): FrameSessionResult {
        if (closed) { return FrameSessionResult(false, "session-closed") }
        if (failed) { return FrameSessionResult(false, failureCode) }
        if (nextGroupIndex != graph.executionGroupCount()) {
            return failCommit("execution-groups-incomplete")
        }
        if (graph.presentMode == FramePresentMode.Partial) {
            return failCommit("partial-present-unsupported")
        }
        if (graph.presentMode == FramePresentMode.Full && !presentRequested) {
            return failCommit("present-pass-missing")
        }
        if (graph.presentMode == FramePresentMode.NotPresented && presentRequested) {
            return failCommit("unexpected-present-pass")
        }

        releaseTransients()
        if (cleanupFailureCount > 0) {
            return failCommit("transient-release-failed")
        }

        var actualPresent = FramePresentMode.NotPresented
        if (presentRequested) {
            if (!presentFullSurface()) {
                return FrameSessionResult(false, failureCode)
            }
            actualPresent = FramePresentMode.Full
        } else if (!endOpenScene()) {
            return FrameSessionResult(false, failureCode)
        }

        if (legacyDirect) {
            // A direct fallback has no retained texture to seed the next bounded frame.
            owner.discardCommittedAndBounded()
        } else {
            match (working) {
                case Some(texture) =>
                    owner.installCommitted(graph, texture)
                    working = None
                case None => ()
            }
        }
        closed = true
        owner.finishSession(receiptFor(
            true,
            if (legacyDirect) { "accepted-legacy-full-present" } else { "accepted" },
            actualPresent,
            false))
        FrameSessionResult(
            true,
            if (actualPresent == FramePresentMode.Full) { "accepted-full-present" } else { "accepted" })
    }

    public func rollback(): Unit {
        if (closed) { return }
        let _ = endOpenScene()
        closeTexture(working)
        working = None
        releaseTransients()
        closed = true
        owner.finishSession(receiptFor(
            false,
            if (failureCode == "none") { "rolled-back" } else { failureCode },
            FramePresentMode.NotPresented,
            true))
    }

    private func executePresentGroup(group: CompiledFramePassGroup): FramePassExecutionResult {
        if (group.passCount() != 1 || presentRequested ||
            group.passAt(0).descriptor.externalMode != FrameExternalMode.NoExternalSurface) {
            return fail("invalid-present-group")
        }
        presentRequested = true
        FramePassExecutionResult(true, "accepted-full-present-deferred")
    }

    private func executeExternalGroup(group: CompiledFramePassGroup): FramePassExecutionResult {
        if (group.passCount() != 1) { return fail("invalid-external-group") }
        let pass = group.passAt(0)
        if (pass.descriptor.externalMode == FrameExternalMode.SharedTexture) {
            if (!deviceBacked) { return fail("shared-frame-device-unavailable") }
            let result = invokePass(pass, true)
            if (!result.ok) { return fail(result.code) }
            return FramePassExecutionResult(true, "accepted-shared-frame-acquire")
        }
        if (pass.descriptor.externalMode != FrameExternalMode.NativeChildSurfaceBarrier) {
            return fail("invalid-external-mode")
        }
        unifiedPixels = false
        let result = invokePass(pass, false)
        if (!result.ok) { return fail(result.code) }
        nativeChildBarrierCount += 1
        FramePassExecutionResult(true, "accepted-native-child-barrier")
    }

    private func executeRasterGroup(group: CompiledFramePassGroup): FramePassExecutionResult {
        for (i in 0..group.passCount()) {
            let kind = group.passAt(i).descriptor.kind
            if (kind == FramePassKind.Present || kind == FramePassKind.ExternalScene3D) {
                return fail("mixed-execution-group")
            }
        }
        if (!ensureScene()) { return FramePassExecutionResult(false, failureCode) }

        if (!deviceBacked || legacyDirect) {
            let result = invokeRasterActions(group, !legacyDirect)
            if (!result.ok) { return fail(result.code) }
            standardGroupCount += 1
            return FramePassExecutionResult(true, if (legacyDirect) { "accepted-legacy-direct" } else { "accepted" })
        }

        let source = if (graph.redrawMode == FrameRedrawMode.Bounded) {
            owner.committedFor(graph)
        } else {
            None<Texture>
        }
        if (graph.redrawMode == FrameRedrawMode.Bounded && working.isNone() && source.isNone()) {
            owner.disableBounded()
            return fail("committed-frame-missing")
        }

        match (working) {
            case Some(target) =>
                let passResult = SdlFramePassResultBox()
                try {
                    renderer.renderToTexturePreserving(
                        target,
                        Float32(graph.source.surfaceWidth),
                        Float32(graph.source.surfaceHeight),
                        { => passResult.value = invokeRasterActions(group, true) })
                } catch (_: Exception) {
                    return fail("sdl-render-to-texture-failed")
                }
                if (!passResult.value.ok) { return fail(passResult.value.code) }
                standardGroupCount += 1
                return FramePassExecutionResult(true, "accepted-retained-target")
            case None => ()
        }

        let target = match (createStagingTarget()) {
            case Some(value) => value
            case None =>
                if (canUseLegacyDirect()) {
                    legacyDirect = true
                    owner.disableBounded()
                    let result = invokeRasterActions(group, false)
                    if (!result.ok) { return fail(result.code) }
                    standardGroupCount += 1
                    return FramePassExecutionResult(true, "accepted-legacy-direct")
                }
                owner.disableBounded()
                return fail("staging-texture-unavailable")
        }

        let passResult = SdlFramePassResultBox()
        try {
            renderer.renderToTexture(
                target,
                Float32(graph.source.surfaceWidth),
                Float32(graph.source.surfaceHeight),
                clearColor,
                { =>
                    match (source) {
                        case Some(texture) => renderer.texture(texture, fullSurfaceRect())
                        case None => ()
                    }
                    passResult.value = invokeRasterActions(group, true)
                })
        } catch (_: Exception) {
            closeTexture(Some(target))
            return fail("sdl-render-to-texture-failed")
        }
        if (!passResult.value.ok) {
            closeTexture(Some(target))
            return fail(passResult.value.code)
        }

        working = Some(target)
        standardGroupCount += 1
        FramePassExecutionResult(true, "accepted")
    }

    private func invokeRasterActions(
        group: CompiledFramePassGroup,
        applyDamageClip: Bool
    ): FramePassExecutionResult {
        var clipped = false
        // A compiler-level promotion to full redraw is conservative correctness, not just receipt
        // wording. Per-pass bounded metadata must not reintroduce a clip after that promotion or a
        // freshly cleared staging target would present transparent/clear pixels outside the region.
        if (applyDamageClip && graph.redrawMode == FrameRedrawMode.Bounded) {
            match (boundedDamageRect(group.damage())) {
                case Some(rect) =>
                    renderer.pushClip(rect)
                    clipped = true
                case None => ()
            }
        }
        try {
            for (i in 0..group.passCount()) {
                let result = invokePass(group.passAt(i), true)
                if (!result.ok) { return result }
            }
            FramePassExecutionResult(true, "accepted")
        } catch (_: Exception) {
            FramePassExecutionResult(false, "runtime-pass-exception")
        } finally {
            if (clipped) { renderer.popClip() }
        }
    }

    private func invokePass(pass: CompiledFramePass, pixelsUnified: Bool): FramePassExecutionResult {
        let action = match (bindingFor(pass.descriptor.id)) {
            case Some(value) => value
            case None => return FramePassExecutionResult(false, "missing-runtime-binding")
        }
        try {
            action(SdlFramePassContext(
                renderer, graph, pass, pixelsUnified,
                {id, resource => manageTransient(id, resource)}))
        } catch (_: Exception) {
            FramePassExecutionResult(false, "runtime-pass-exception")
        }
    }

    private func bindingFor(id: FramePassId): ?(SdlFramePassContext) -> FramePassExecutionResult {
        for (value in bindings) {
            if (value.id == id) { return Some(value.action) }
        }
        None<(SdlFramePassContext) -> FramePassExecutionResult>
    }

    private func manageTransient(id: FrameResourceId, resource: Resource): Unit {
        var declaredTransient = false
        for (i in 0..graph.source.resourceCount()) {
            let descriptor = graph.source.resourceAt(i)
            if (descriptor.id == id && descriptor.lifetime == FrameResourceLifetime.Transient) {
                declaredTransient = true
                break
            }
        }
        if (!declaredTransient) {
            throw IllegalArgumentException("SDL frame transient must be declared by the graph")
        }
        for (value in transients) {
            if (value.id == id) {
                throw IllegalStateException("SDL frame transient ownership was already transferred")
            }
        }
        transients.add(SdlManagedFrameTransient(id, resource))
    }

    private func releaseTransients(): Unit {
        var i = transients.size - 1
        while (i >= 0) {
            if (!transients[i].isReleased()) {
                releasedTransientCount += 1
                if (!transients[i].release()) { cleanupFailureCount += 1 }
            }
            i -= 1
        }
    }

    private func ensureScene(): Bool {
        if (sceneOpen) { return true }
        sceneOpen = true
        try {
            renderer.beginScene(
                Float32(graph.source.surfaceWidth),
                Float32(graph.source.surfaceHeight),
                clearColor)
            true
        } catch (_: Exception) {
            failureCode = "sdl-begin-scene-failed"
            failed = true
            false
        }
    }

    private func endOpenScene(): Bool {
        if (!sceneOpen) { return true }
        try {
            renderer.endScene()
            sceneOpen = false
            true
        } catch (_: Exception) {
            failureCode = "sdl-end-scene-failed"
            failed = true
            false
        }
    }

    private func presentFullSurface(): Bool {
        if (!deviceBacked) {
            if (sceneOpen && !endOpenScene()) { return false }
            if (!invokeBeforePresent()) { return false }
            renderer.present()
            return true
        }
        if (!ensureScene()) { return false }
        if (!legacyDirect) {
            let source = match (working) {
                case Some(texture) => Some(texture)
                case None => owner.committedFor(graph)
            }
            match (source) {
                case Some(texture) => try {
                    renderer.texture(texture, fullSurfaceRect())
                } catch (_: Exception) {
                    failureCode = "sdl-resolve-failed"
                    failed = true
                    return false
                }
                case None =>
                    failureCode = "sdl-present-source-missing"
                    failed = true
                    owner.disableBounded()
                    return false
            }
        }
        if (!endOpenScene()) { return false }
        if (!invokeBeforePresent()) { return false }
        try {
            // SDL_RenderPresent has no damage argument: this is deliberately a full present.
            renderer.present()
            true
        } catch (_: Exception) {
            failureCode = "sdl-full-present-failed"
            failed = true
            false
        }
    }

    private func invokeBeforePresent(): Bool {
        try {
            beforePresent()
            true
        } catch (_: Exception) {
            failureCode = "sdl-before-present-failed"
            failed = true
            false
        }
    }

    private func createStagingTarget(): ?Texture {
        try {
            let texture = createFrameGraphCopyTargetTexture(
                renderer,
                Float32(graph.source.surfaceWidth), Float32(graph.source.surfaceHeight))
            Some(texture)
        } catch (_: Exception) {
            None<Texture>
        }
    }

    private func canUseLegacyDirect(): Bool {
        standardGroupCount == 0 && working.isNone() &&
            graph.redrawMode == FrameRedrawMode.Full &&
            graph.presentMode == FramePresentMode.Full
    }

    private func matchesExpectedGroup(group: CompiledFramePassGroup): Bool {
        if (group.passCount() <= 0 || nextGroupIndex >= graph.executionGroupCount()) { return false }
        let expected = graph.executionGroupAt(nextGroupIndex)
        if (expected.passCount() != group.passCount()) { return false }
        for (i in 0..group.passCount()) {
            if (expected.passAt(i).descriptor.id != group.passAt(i).descriptor.id) { return false }
        }
        true
    }

    private func boundedDamageRect(damage: DamageRegion): ?Rect {
        if (damage.kind != FrameDamageKind.Bounded || damage.rectangleCount() == 0) { return None }
        var left = damage.rectangleAt(0).x
        var top = damage.rectangleAt(0).y
        var right = damage.rectangleAt(0).right()
        var bottom = damage.rectangleAt(0).bottom()
        for (i in 1..damage.rectangleCount()) {
            let value = damage.rectangleAt(i)
            left = min(left, value.x)
            top = min(top, value.y)
            right = max(right, value.right())
            bottom = max(bottom, value.bottom())
        }
        Some(Rect(
            Float32(left), Float32(top), Float32(right - left), Float32(bottom - top)))
    }

    private func fullSurfaceRect(): Rect {
        Rect(0.0, 0.0, Float32(graph.source.surfaceWidth), Float32(graph.source.surfaceHeight))
    }

    private func fail(code: String): FramePassExecutionResult {
        failureCode = code
        failed = true
        FramePassExecutionResult(false, code)
    }

    private func failCommit(code: String): FrameSessionResult {
        failureCode = code
        failed = true
        FrameSessionResult(false, code)
    }

    private func receiptFor(
        ok: Bool,
        code: String,
        presentMode: FramePresentMode,
        fallbackRequired: Bool
    ): SdlFrameExecutorReceipt {
        SdlFrameExecutorReceipt(
            ok,
            code,
            graph.source.frameId,
            graph.redrawMode,
            presentMode,
            if (presentMode == FramePresentMode.NotPresented) {
                FramePresentStrategy.NotPresented
            } else if (legacyDirect) {
                FramePresentStrategy.UnsupportedFallback
            } else {
                graph.presentStrategy
            },
            deviceBacked,
            unifiedPixels,
            nativeChildBarrierCount,
            completedPassCount,
            transients.size,
            releasedTransientCount,
            cleanupFailureCount,
            ok && legacyDirect,
            fallbackRequired)
    }

    private func closeTexture(value: ?Texture): Unit {
        match (value) {
            case Some(texture) => try { texture.close() } catch (_: Exception) {}
            case None => ()
        }
    }
}

private func validateSdlFramePlan(
    graph: CompiledFrameGraph,
    maxSurfacePixels: Int64,
    deviceBacked: Bool,
    physicalSurfacePixels: Int64
): String {
    if (graph.presentMode == FramePresentMode.Partial) { return "partial-present-unsupported" }
    for (i in 0..graph.source.passCount()) {
        if (graph.source.passAt(i).externalMode == FrameExternalMode.SharedTexture) {
            if (!deviceBacked) { return "shared-frame-device-unavailable" }
        }
    }
    let width = graph.source.surfaceWidth
    let height = graph.source.surfaceHeight
    if (width <= 0 || height <= 0 || physicalSurfacePixels <= 0 ||
        physicalSurfacePixels > maxSurfacePixels) {
        return "surface-pixels-over-cap"
    }
    if (width > maxSurfacePixels / height) { return "surface-pixels-over-cap" }
    "accepted"
}
