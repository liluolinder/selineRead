package chui.graphics

import std.collection.ArrayList

/** Internal AOT pipeline-pack protocol. Payload bytes never enter manifests or frame traces. */
protected let CANGHUI_GPU_PIPELINE_PACK_PROTOCOL = "canghui.gpu-pipeline-pack.v2"

protected let CANGHUI_GPU_PIPELINE_PACK_MAX_ARTIFACTS: Int64 = 1024
protected let CANGHUI_GPU_PIPELINE_PACK_MAX_REQUIREMENTS: Int64 = 1024
protected let CANGHUI_GPU_PIPELINE_PACK_MAX_ARTIFACT_BYTES: Int64 = 4194304
protected let CANGHUI_GPU_PIPELINE_PACK_MAX_BYTES: Int64 = 67108864

protected enum PortableGpuPipelineStage <: Equatable<PortableGpuPipelineStage> {
    | Vertex
    | Fragment
    | Compute

    public operator func ==(other: PortableGpuPipelineStage): Bool {
        portableGpuPipelineStageName(this) == portableGpuPipelineStageName(other)
    }

    public operator func !=(other: PortableGpuPipelineStage): Bool { !(this == other) }
}

protected func portableGpuPipelineStageName(value: PortableGpuPipelineStage): String {
    match (value) {
        case PortableGpuPipelineStage.Vertex => "vertex"
        case PortableGpuPipelineStage.Fragment => "fragment"
        case PortableGpuPipelineStage.Compute => "compute"
    }
}

/** One target-specific precompiled artifact. The constructor copies its payload. */
protected class PortableGpuPipelineArtifact {
    public let id: String
    public let backend: GraphicsBackend
    public let stage: PortableGpuPipelineStage
    public let entryPoint: String
    public let layoutAbi: String
    /** Bounded diagnostic hint only. Correctness uses exact payload comparison and validation. */
    public let contentHint: String
    private let bytes: Array<UInt8>

    public init(
        id: String,
        backend: GraphicsBackend,
        stage: PortableGpuPipelineStage,
        entryPoint: String,
        payload: Array<UInt8>,
        layoutAbi!: String = "chui.bind-layout.v1"
    ) {
        let _ = FramePassId(id)
        let _ = FramePassId(entryPoint)
        let _ = FramePassId(layoutAbi)
        if (backend == GraphicsBackend.Software) {
            throw IllegalArgumentException("AOT GPU artifacts require a native or portable GPU backend")
        }
        if (payload.size <= 0 || payload.size > CANGHUI_GPU_PIPELINE_PACK_MAX_ARTIFACT_BYTES) {
            throw IllegalArgumentException("AOT GPU artifact bytes are outside the hard bound")
        }
        this.id = id
        this.backend = backend
        this.stage = stage
        this.entryPoint = entryPoint
        this.layoutAbi = layoutAbi
        this.bytes = payload.clone()
        this.contentHint = portableGpuPayloadHint(this.bytes)
    }

    public func byteCount(): Int64 { bytes.size }
    public func borrowedBytes(): Array<UInt8> { bytes.clone() }

    /** Exact byte equality is the only content identity used for correctness. */
    public func exactlyMatches(other: PortableGpuPipelineArtifact): Bool {
        if (id != other.id || backend != other.backend || stage != other.stage ||
            entryPoint != other.entryPoint || layoutAbi != other.layoutAbi ||
            bytes.size != other.bytes.size) {
            return false
        }
        for (i in 0..bytes.size) {
            if (bytes[i] != other.bytes[i]) { return false }
        }
        true
    }

    func sortKey(): String {
        graphicsBackendName(backend) + "|" + portableGpuPipelineStageName(stage) +
            "|" + id + "|" + entryPoint + "|" + layoutAbi
    }

    func identityKey(): String {
        graphicsBackendName(backend) + "|" + portableGpuPipelineStageName(stage) + "|" + id
    }
}

/** One pipeline referenced by one FrameGraph pass. */
protected struct PortableGpuPipelineUse <: Equatable<PortableGpuPipelineUse> {
    public let artifactId: String
    public let stage: PortableGpuPipelineStage
    public let entryPoint: String
    public let layoutAbi: String

    public init(
        artifactId: String,
        stage: PortableGpuPipelineStage,
        entryPoint!: String = "main",
        layoutAbi!: String = "chui.bind-layout.v1"
    ) {
        let _ = FramePassId(artifactId)
        let _ = FramePassId(entryPoint)
        let _ = FramePassId(layoutAbi)
        this.artifactId = artifactId
        this.stage = stage
        this.entryPoint = entryPoint
        this.layoutAbi = layoutAbi
    }

    public operator func ==(other: PortableGpuPipelineUse): Bool {
        artifactId == other.artifactId && stage == other.stage &&
        entryPoint == other.entryPoint && layoutAbi == other.layoutAbi
    }

    public operator func !=(other: PortableGpuPipelineUse): Bool { !(this == other) }
}

/** Exact pass-to-pipeline binding plus a fail-closed resource budget. */
protected class PortableGpuPassRequirement {
    public let passId: String
    public let maximumReferencedBytes: Int64
    private let pipelines = ArrayList<PortableGpuPipelineUse>()

    public init(
        passId: String,
        values: Array<PortableGpuPipelineUse>,
        maximumReferencedBytes: Int64
    ) {
        let _ = FramePassId(passId)
        if (maximumReferencedBytes < 0 ||
            maximumReferencedBytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES) {
            throw IllegalArgumentException("portable GPU pass resource budget is invalid")
        }
        for (value in values) {
            for (current in pipelines) {
                if (current == value) {
                    throw IllegalArgumentException("portable GPU pass repeats a pipeline requirement")
                }
            }
            pipelines.add(value)
        }
        this.passId = passId
        this.maximumReferencedBytes = maximumReferencedBytes
    }

    public func pipelineCount(): Int64 { pipelines.size }
    public func pipelineAt(index: Int64): PortableGpuPipelineUse { pipelines[index] }

    func canonicalFragment(): String {
        let out = StringBuilder()
        out.append(passId)
        out.append(",")
        out.append(maximumReferencedBytes.toString())
        for (value in pipelines) {
            out.append(",")
            out.append(portableGpuPipelineStageName(value.stage))
            out.append(":")
            out.append(value.artifactId)
            out.append(":")
            out.append(value.entryPoint)
            out.append(":")
            out.append(value.layoutAbi)
        }
        out.toString()
    }
}

/** Immutable device truth captured by the provider before any pack is installed. */
protected class PortableGpuDeviceSnapshot {
    public let identity: String
    public let adapter: GraphicsAdapterCapabilities
    public let capabilityGeneration: Int64
    public let artifactFormatAbi: String
    public let layoutAbi: String
    public let executorCapabilities: FrameGraphExecutorCapabilities

    public init(
        identity: String,
        adapter: GraphicsAdapterCapabilities,
        capabilityGeneration: Int64,
        artifactFormatAbi: String,
        layoutAbi: String,
        executorCapabilities: FrameGraphExecutorCapabilities
    ) {
        let _ = FramePassId(identity)
        let _ = FramePassId(artifactFormatAbi)
        let _ = FramePassId(layoutAbi)
        if (capabilityGeneration <= 0) {
            throw IllegalArgumentException("portable GPU capability generation must be positive")
        }
        if (adapter.backend == GraphicsBackend.Software) {
            throw IllegalArgumentException("portable GPU snapshots require a GPU backend")
        }
        this.identity = identity
        this.adapter = adapter
        this.capabilityGeneration = capabilityGeneration
        this.artifactFormatAbi = artifactFormatAbi
        this.layoutAbi = layoutAbi
        this.executorCapabilities = executorCapabilities
    }
}

/** Pack compatibility target. Adapter identity and generation prevent stale AOT reuse. */
protected class PortableGpuPackTarget {
    public let providerId: String
    public let adapterId: String
    public let backend: GraphicsBackend
    public let minimumProfile: GraphicsProfile
    public let capabilityGeneration: Int64
    public let artifactFormatAbi: String
    public let layoutAbi: String
    public let minimumLimits: GraphicsLimits
    public let maximumFrameResourceBytes: Int64
    private let requiredCapabilities = ArrayList<GraphicsCapability>()

    public init(
        providerId: String,
        adapterId: String,
        backend: GraphicsBackend,
        minimumProfile: GraphicsProfile,
        capabilityGeneration: Int64,
        artifactFormatAbi: String,
        layoutAbi: String,
        minimumLimits: GraphicsLimits,
        requiredCapabilities: Array<GraphicsCapability>,
        maximumFrameResourceBytes: Int64
    ) {
        if (providerId.isEmpty() || adapterId.isEmpty() || capabilityGeneration <= 0 ||
            maximumFrameResourceBytes <= 0 ||
            maximumFrameResourceBytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES) {
            throw IllegalArgumentException("portable GPU pack target identity or budget is invalid")
        }
        let _ = FramePassId(artifactFormatAbi)
        let _ = FramePassId(layoutAbi)
        if (backend == GraphicsBackend.Software) {
            throw IllegalArgumentException("portable GPU pack targets require a GPU backend")
        }
        for (value in requiredCapabilities) {
            for (current in this.requiredCapabilities) {
                if (current == value) {
                    throw IllegalArgumentException("portable GPU pack target repeats a capability")
                }
            }
            this.requiredCapabilities.add(value)
        }
        this.providerId = providerId
        this.adapterId = adapterId
        this.backend = backend
        this.minimumProfile = minimumProfile
        this.capabilityGeneration = capabilityGeneration
        this.artifactFormatAbi = artifactFormatAbi
        this.layoutAbi = layoutAbi
        this.minimumLimits = minimumLimits
        this.maximumFrameResourceBytes = maximumFrameResourceBytes
    }

    public func requires(capability: GraphicsCapability): Bool {
        for (value in requiredCapabilities) {
            if (value == capability) { return true }
        }
        false
    }

    func canonicalFragment(): String {
        let out = StringBuilder()
        out.append(providerId)
        out.append(",")
        out.append(adapterId)
        out.append(",")
        out.append(graphicsBackendName(backend))
        out.append(",")
        out.append(graphicsProfileName(minimumProfile))
        out.append(",")
        out.append(capabilityGeneration.toString())
        out.append(",")
        out.append(artifactFormatAbi)
        out.append(",")
        out.append(layoutAbi)
        out.append(",")
        out.append(minimumLimits.maxTextureDimension2D.toString())
        out.append(":")
        out.append(minimumLimits.maxBindGroups.toString())
        out.append(":")
        out.append(minimumLimits.maxVertexBuffers.toString())
        out.append(":")
        out.append(minimumLimits.maxColorAttachments.toString())
        out.append(",")
        out.append(maximumFrameResourceBytes.toString())
        for (capability in portableGpuAllCapabilities()) {
            if (requires(capability)) {
                out.append(",")
                out.append(graphicsCapabilityName(capability))
            }
        }
        out.toString()
    }
}

/**
 * Immutable canonical pack. Declaration order does not affect its diagnostic manifest.
 * `cacheKey` is only a bounded cache hint; exact payload and structured contracts decide reuse.
 */
protected class PortableGpuPipelinePack {
    public let id: String
    public let target: PortableGpuPackTarget
    public let manifest: String
    public let cacheKey: String
    public let totalBytes: Int64
    private let artifacts = ArrayList<PortableGpuPipelineArtifact>()
    private let requirements = ArrayList<PortableGpuPassRequirement>()

    public init(
        id: String,
        target: PortableGpuPackTarget,
        values: Array<PortableGpuPipelineArtifact>,
        passRequirements: Array<PortableGpuPassRequirement>
    ) {
        let _ = FramePassId(id)
        if (values.size <= 0 || values.size > CANGHUI_GPU_PIPELINE_PACK_MAX_ARTIFACTS ||
            passRequirements.size <= 0 ||
            passRequirements.size > CANGHUI_GPU_PIPELINE_PACK_MAX_REQUIREMENTS) {
            throw IllegalArgumentException("AOT GPU pipeline pack counts are outside hard bounds")
        }

        let ordered = values.clone()
        sortPortableGpuArtifacts(ordered)
        var bytes: Int64 = 0
        for (i in 0..ordered.size) {
            let artifact = ordered[i]
            if (artifact.backend != target.backend || artifact.layoutAbi != target.layoutAbi) {
                throw IllegalArgumentException("AOT GPU artifact is incompatible with the pack target")
            }
            if (i > 0 && artifact.identityKey() == ordered[i - 1].identityKey()) {
                throw IllegalArgumentException("AOT GPU pipeline pack contains an ambiguous artifact identity")
            }
            if (artifact.byteCount() > CANGHUI_GPU_PIPELINE_PACK_MAX_BYTES - bytes) {
                throw IllegalArgumentException("AOT GPU pipeline pack bytes exceed the hard bound")
            }
            bytes += artifact.byteCount()
            artifacts.add(artifact)
        }

        let orderedRequirements = passRequirements.clone()
        sortPortableGpuRequirements(orderedRequirements)
        for (i in 0..orderedRequirements.size) {
            let requirement = orderedRequirements[i]
            if (i > 0 && requirement.passId == orderedRequirements[i - 1].passId) {
                throw IllegalArgumentException("AOT GPU pipeline pack repeats a pass requirement")
            }
            for (pipelineIndex in 0..requirement.pipelineCount()) {
                let pipeline = requirement.pipelineAt(pipelineIndex)
                if (!hasPortableGpuArtifactVariant(
                    artifacts, pipeline.artifactId, target.backend, pipeline.stage,
                    pipeline.entryPoint, pipeline.layoutAbi)) {
                    throw IllegalArgumentException("AOT GPU pass requirement references a missing artifact")
                }
            }
            requirements.add(requirement)
        }
        this.id = id
        this.target = target
        this.totalBytes = bytes
        this.manifest = renderPortableGpuPipelineManifest(id, target, artifacts, requirements, bytes)
        this.cacheKey = "cgpp-v2-hint-${portableGpuStableHint(this.manifest)}-${this.manifest.toArray().size}"
    }

    public func artifactCount(): Int64 { artifacts.size }
    public func artifactAt(index: Int64): PortableGpuPipelineArtifact { artifacts[index] }
    public func requirementCount(): Int64 { requirements.size }
    public func requirementAt(index: Int64): PortableGpuPassRequirement { requirements[index] }

    public func hasArtifact(id: String, backend: GraphicsBackend, stage: PortableGpuPipelineStage): Bool {
        hasPortableGpuArtifact(artifacts, id, backend, stage)
    }

    public func requirementFor(passId: String): ?PortableGpuPassRequirement {
        for (value in requirements) {
            if (value.passId == passId) { return Some(value) }
        }
        None
    }

    /** Manifest/hash equality is insufficient; this method performs exact byte comparison. */
    public func exactlyMatches(other: PortableGpuPipelinePack): Bool {
        if (manifest != other.manifest || artifacts.size != other.artifacts.size) { return false }
        for (i in 0..artifacts.size) {
            if (!artifacts[i].exactlyMatches(other.artifacts[i])) { return false }
        }
        true
    }
}

protected struct PortableGpuCompatibilityReceipt {
    public let ok: Bool
    public let code: String

    public init(ok: Bool, code: String) {
        this.ok = ok
        this.code = code
    }
}

/** Provider-owned transaction. Native devices and handles remain behind this internal SPI. */
protected interface PortableGpuExecutionSession {
    func execute(group: CompiledFramePassGroup): FramePassExecutionResult
    func commit(): FrameSessionResult
    func rollback(): Unit
}

/** Provider boundary for a portable FrameGraph executor backed by an AOT pipeline pack. */
protected interface PortableGpuDevice {
    func snapshot(): PortableGpuDeviceSnapshot
    /** Provider must atomically reject if its live device no longer exactly matches `expectedSnapshot`. */
    func begin(
        graph: CompiledFrameGraph,
        pack: PortableGpuPipelinePack,
        expectedSnapshot: PortableGpuDeviceSnapshot
    ): PortableGpuExecutionSession
}

/** FrameGraph adapter with a complete fail-closed compatibility gate before `device.begin`. */
protected class PortableGpuFrameGraphExecutor <: FrameGraphExecutor {
    private let device: PortableGpuDevice
    private let pack: PortableGpuPipelinePack
    private let compiledSnapshot: PortableGpuDeviceSnapshot

    public init(device: PortableGpuDevice, pack: PortableGpuPipelinePack) {
        this.compiledSnapshot = device.snapshot()
        this.device = device
        this.pack = pack
    }

    public func capabilities(): FrameGraphExecutorCapabilities {
        compiledSnapshot.executorCapabilities
    }

    public func compatibility(graph: CompiledFrameGraph): PortableGpuCompatibilityReceipt {
        if (!portableGpuDeviceSnapshotsExactlyMatch(compiledSnapshot, device.snapshot())) {
            return PortableGpuCompatibilityReceipt(false, "capability-snapshot-changed")
        }
        validatePortableGpuExecution(graph, compiledSnapshot, pack)
    }

    public func begin(graph: CompiledFrameGraph): FrameGraphExecutionSession {
        let receipt = compatibility(graph)
        if (!receipt.ok) {
            throw IllegalStateException("portable GPU compatibility rejected: " + receipt.code)
        }
        if (!portableGpuDeviceSnapshotsExactlyMatch(compiledSnapshot, device.snapshot())) {
            throw IllegalStateException(
                "portable GPU compatibility rejected: capability-snapshot-changed")
        }
        // The provider receives the exact immutable pack, not the bounded diagnostic cache hint.
        PortableGpuFrameExecutionSession(device.begin(graph, pack, compiledSnapshot))
    }

    public func pipelineCacheHint(): String { pack.cacheKey }
    public func selectedBackend(): GraphicsBackend { compiledSnapshot.adapter.backend }
}

private class PortableGpuFrameExecutionSession <: FrameGraphExecutionSession {
    private let session: PortableGpuExecutionSession

    init(session: PortableGpuExecutionSession) { this.session = session }

    public func execute(group: CompiledFramePassGroup): FramePassExecutionResult {
        session.execute(group)
    }

    public func commit(): FrameSessionResult { session.commit() }
    public func rollback(): Unit { session.rollback() }
}

protected func validatePortableGpuExecution(
    graph: CompiledFrameGraph,
    snapshot: PortableGpuDeviceSnapshot,
    pack: PortableGpuPipelinePack
): PortableGpuCompatibilityReceipt {
    let target = pack.target
    let adapter = snapshot.adapter
    if (adapter.providerId != target.providerId || adapter.adapterId != target.adapterId ||
        adapter.backend != target.backend) {
        return PortableGpuCompatibilityReceipt(false, "device-identity-mismatch")
    }
    if (snapshot.capabilityGeneration != target.capabilityGeneration) {
        return PortableGpuCompatibilityReceipt(false, "stale-capability-generation")
    }
    if (snapshot.artifactFormatAbi != target.artifactFormatAbi) {
        return PortableGpuCompatibilityReceipt(false, "artifact-format-abi-mismatch")
    }
    if (snapshot.layoutAbi != target.layoutAbi) {
        return PortableGpuCompatibilityReceipt(false, "bind-layout-abi-mismatch")
    }
    if (!adapter.supportsProfile(target.minimumProfile) ||
        !adapter.limits.supports(target.minimumLimits)) {
        return PortableGpuCompatibilityReceipt(false, "profile-or-limit-mismatch")
    }
    for (capability in portableGpuAllCapabilities()) {
        if (target.requires(capability) && !adapter.has(capability)) {
            return PortableGpuCompatibilityReceipt(false, "required-capability-missing")
        }
    }
    if (graph.declaredResourceBytes > target.maximumFrameResourceBytes ||
        graph.declaredResourceBytes > snapshot.executorCapabilities.maxDeclaredResourceBytes) {
        return PortableGpuCompatibilityReceipt(false, "frame-resource-budget-exceeded")
    }

    for (i in 0..graph.source.passCount()) {
        let pass = graph.source.passAt(i)
        let requirement = match (pack.requirementFor(pass.id.key)) {
            case Some(value) => value
            case None => return PortableGpuCompatibilityReceipt(false, "pass-requirement-missing")
        }
        if (!portableGpuPassPipelineShapeIsValid(pass.kind, requirement)) {
            return PortableGpuCompatibilityReceipt(false, "pass-pipeline-requirement-invalid")
        }
        let referencedBytes = portableGpuPassReferencedBytes(graph.source, pass)
        if (referencedBytes < 0 || referencedBytes > requirement.maximumReferencedBytes) {
            return PortableGpuCompatibilityReceipt(false, "pass-resource-budget-exceeded")
        }
    }
    for (i in 0..pack.requirementCount()) {
        if (!portableGpuGraphHasPass(graph.source, pack.requirementAt(i).passId)) {
            return PortableGpuCompatibilityReceipt(false, "unknown-pass-requirement")
        }
    }
    PortableGpuCompatibilityReceipt(true, "compatible")
}

private func portableGpuPassPipelineShapeIsValid(
    kind: FramePassKind,
    requirement: PortableGpuPassRequirement
): Bool {
    var vertex = false
    var fragment = false
    var compute = false
    for (i in 0..requirement.pipelineCount()) {
        match (requirement.pipelineAt(i).stage) {
            case PortableGpuPipelineStage.Vertex => vertex = true
            case PortableGpuPipelineStage.Fragment => fragment = true
            case PortableGpuPipelineStage.Compute => compute = true
        }
    }
    match (kind) {
        case FramePassKind.Ui2D => vertex && fragment && !compute
        case FramePassKind.RendererEffect => vertex && fragment && !compute
        case FramePassKind.OffscreenComposition =>
            (compute && !vertex && !fragment) || (!compute && vertex && fragment)
        case FramePassKind.ExternalScene3D => requirement.pipelineCount() == 0
        case FramePassKind.CopyResolve => requirement.pipelineCount() == 0
        case FramePassKind.Present => requirement.pipelineCount() == 0
    }
}

/** Exact helper for the provider's atomic begin-time snapshot revalidation. */
protected func portableGpuDeviceSnapshotsExactlyMatch(
    first: PortableGpuDeviceSnapshot,
    second: PortableGpuDeviceSnapshot
): Bool {
    let a = first.adapter
    let b = second.adapter
    if (first.identity != second.identity ||
        first.capabilityGeneration != second.capabilityGeneration ||
        first.artifactFormatAbi != second.artifactFormatAbi || first.layoutAbi != second.layoutAbi ||
        a.providerId != b.providerId || a.adapterId != b.adapterId || a.backend != b.backend ||
        a.profile != b.profile ||
        a.limits.maxTextureDimension2D != b.limits.maxTextureDimension2D ||
        a.limits.maxBindGroups != b.limits.maxBindGroups ||
        a.limits.maxVertexBuffers != b.limits.maxVertexBuffers ||
        a.limits.maxColorAttachments != b.limits.maxColorAttachments) {
        return false
    }
    for (capability in portableGpuAllCapabilities()) {
        if (a.has(capability) != b.has(capability)) { return false }
    }
    let firstExecutor = first.executorCapabilities
    let secondExecutor = second.executorCapabilities
    firstExecutor.supportsBoundedRedraw == secondExecutor.supportsBoundedRedraw &&
    firstExecutor.supportsPartialPresent == secondExecutor.supportsPartialPresent &&
    firstExecutor.supportsSharedTexture == secondExecutor.supportsSharedTexture &&
    firstExecutor.supportsExtendedDynamicRange == secondExecutor.supportsExtendedDynamicRange &&
    firstExecutor.maxDeclaredResourceBytes == secondExecutor.maxDeclaredResourceBytes
}

private func portableGpuPassReferencedBytes(graph: FrameGraph, pass: FramePassDescriptor): Int64 {
    var total: Int64 = 0
    for (i in 0..pass.readCount()) {
        let bytes = portableGpuResourceBytes(graph, pass.readAt(i))
        if (bytes < 0 || bytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES - total) { return -1 }
        total += bytes
    }
    for (i in 0..pass.writeCount()) {
        let bytes = portableGpuResourceBytes(graph, pass.writeAt(i))
        if (bytes < 0 || bytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES - total) { return -1 }
        total += bytes
    }
    total
}

private func portableGpuResourceBytes(graph: FrameGraph, id: FrameResourceId): Int64 {
    for (i in 0..graph.resourceCount()) {
        let value = graph.resourceAt(i)
        if (value.id == id) { return value.declaredBytes }
    }
    -1
}

private func portableGpuGraphHasPass(graph: FrameGraph, passId: String): Bool {
    for (i in 0..graph.passCount()) {
        if (graph.passAt(i).id.key == passId) { return true }
    }
    false
}

private func hasPortableGpuArtifact(
    artifacts: ArrayList<PortableGpuPipelineArtifact>,
    id: String,
    backend: GraphicsBackend,
    stage: PortableGpuPipelineStage
): Bool {
    for (value in artifacts) {
        if (value.id == id && value.backend == backend && value.stage == stage) { return true }
    }
    false
}

private func hasPortableGpuArtifactVariant(
    artifacts: ArrayList<PortableGpuPipelineArtifact>,
    id: String,
    backend: GraphicsBackend,
    stage: PortableGpuPipelineStage,
    entryPoint: String,
    layoutAbi: String
): Bool {
    for (value in artifacts) {
        if (value.id == id && value.backend == backend && value.stage == stage &&
            value.entryPoint == entryPoint && value.layoutAbi == layoutAbi) { return true }
    }
    false
}

private func sortPortableGpuArtifacts(values: Array<PortableGpuPipelineArtifact>): Unit {
    var i: Int64 = 1
    while (i < values.size) {
        let current = values[i]
        var j = i
        while (j > 0 && portableGpuStringCompare(current.sortKey(), values[j - 1].sortKey()) < 0) {
            values[j] = values[j - 1]
            j -= 1
        }
        values[j] = current
        i += 1
    }
}

private func sortPortableGpuRequirements(values: Array<PortableGpuPassRequirement>): Unit {
    var i: Int64 = 1
    while (i < values.size) {
        let current = values[i]
        var j = i
        while (j > 0 && portableGpuStringCompare(current.passId, values[j - 1].passId) < 0) {
            values[j] = values[j - 1]
            j -= 1
        }
        values[j] = current
        i += 1
    }
}

private func renderPortableGpuPipelineManifest(
    id: String,
    target: PortableGpuPackTarget,
    values: ArrayList<PortableGpuPipelineArtifact>,
    requirements: ArrayList<PortableGpuPassRequirement>,
    totalBytes: Int64
): String {
    let out = StringBuilder()
    out.append("protocol=")
    out.append(CANGHUI_GPU_PIPELINE_PACK_PROTOCOL)
    out.append("\npack=")
    out.append(id)
    out.append("\ntarget=")
    out.append(target.canonicalFragment())
    out.append("\nartifact-count=")
    out.append(values.size.toString())
    out.append("\ntotal-bytes=")
    out.append(totalBytes.toString())
    for (value in values) {
        out.append("\nartifact=")
        out.append(graphicsBackendName(value.backend))
        out.append(",")
        out.append(portableGpuPipelineStageName(value.stage))
        out.append(",")
        out.append(value.id)
        out.append(",")
        out.append(value.entryPoint)
        out.append(",")
        out.append(value.layoutAbi)
        out.append(",")
        out.append(value.byteCount().toString())
        out.append(",")
        out.append(value.contentHint)
    }
    for (value in requirements) {
        out.append("\npass=")
        out.append(value.canonicalFragment())
    }
    out.toString()
}

private func portableGpuAllCapabilities(): Array<GraphicsCapability> {
    [
        GraphicsCapability.RenderPipeline,
        GraphicsCapability.SampledTexture,
        GraphicsCapability.DepthTexture,
        GraphicsCapability.Instancing,
        GraphicsCapability.ComputePipeline,
        GraphicsCapability.StorageBuffer,
        GraphicsCapability.TimestampQuery,
        GraphicsCapability.HdrSurface
    ]
}

private func portableGpuPayloadHint(bytes: Array<UInt8>): String {
    var first: Int64 = 17
    var second: Int64 = 29
    for (value in bytes) {
        first = (first * 131 + Int64(value)) % 2147483647
        second = (second * 257 + Int64(value) + 1) % 2147483629
    }
    "hint-${first}-${second}-${bytes.size}"
}

private func portableGpuStableHint(value: String): Int64 {
    var code: Int64 = 23
    for (byte in value.toArray()) {
        code = (code * 131 + Int64(byte)) % 2147483647
    }
    code
}

private func portableGpuStringCompare(first: String, second: String): Int64 {
    let a = first.toArray()
    let b = second.toArray()
    let count = min(a.size, b.size)
    for (i in 0..count) {
        if (a[i] < b[i]) { return -1 }
        if (a[i] > b[i]) { return 1 }
    }
    if (a.size < b.size) { return -1 }
    if (a.size > b.size) { return 1 }
    0
}
