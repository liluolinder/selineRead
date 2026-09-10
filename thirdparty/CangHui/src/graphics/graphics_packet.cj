package chui.graphics

import std.collection.ArrayList

public let CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL = "canghui.graphics.render-packet.v0"
public let CANGHUI_GRAPHICS_MAX_PACKET_BYTES: Int64 = 268435456

private let GRAPHICS_PACKET_MAGIC = "CHUIRPK1"
private let GRAPHICS_PACKET_SCHEMA: Int64 = 1

/** Portable resource classes. They describe intent, never native handles. */
public enum GraphicsResourceKind <: Equatable<GraphicsResourceKind> {
    | VertexBuffer
    | IndexBuffer
    | UniformBuffer
    | Texture2D
    | Sampler
    | ShaderModule
    | RenderPipeline

    public operator func ==(other: GraphicsResourceKind): Bool {
        graphicsResourceKindName(this) == graphicsResourceKindName(other)
    }

    public operator func !=(other: GraphicsResourceKind): Bool { !(this == other) }
}

public func graphicsResourceKindName(kind: GraphicsResourceKind): String {
    match (kind) {
        case GraphicsResourceKind.VertexBuffer => "vertex-buffer"
        case GraphicsResourceKind.IndexBuffer => "index-buffer"
        case GraphicsResourceKind.UniformBuffer => "uniform-buffer"
        case GraphicsResourceKind.Texture2D => "texture-2d"
        case GraphicsResourceKind.Sampler => "sampler"
        case GraphicsResourceKind.ShaderModule => "shader-module"
        case GraphicsResourceKind.RenderPipeline => "render-pipeline"
    }
}

private func graphicsResourceKindCode(kind: GraphicsResourceKind): Int64 {
    match (kind) {
        case GraphicsResourceKind.VertexBuffer => 1
        case GraphicsResourceKind.IndexBuffer => 2
        case GraphicsResourceKind.UniformBuffer => 3
        case GraphicsResourceKind.Texture2D => 4
        case GraphicsResourceKind.Sampler => 5
        case GraphicsResourceKind.ShaderModule => 6
        case GraphicsResourceKind.RenderPipeline => 7
    }
}

private func graphicsResourceKindFromCode(code: Int64): GraphicsResourceKind {
    match (code) {
        case 1 => GraphicsResourceKind.VertexBuffer
        case 2 => GraphicsResourceKind.IndexBuffer
        case 3 => GraphicsResourceKind.UniformBuffer
        case 4 => GraphicsResourceKind.Texture2D
        case 5 => GraphicsResourceKind.Sampler
        case 6 => GraphicsResourceKind.ShaderModule
        case 7 => GraphicsResourceKind.RenderPipeline
        case _ => throw IllegalArgumentException("unknown graphics resource kind code")
    }
}

public enum GraphicsResourceOperationKind <: Equatable<GraphicsResourceOperationKind> {
    | Create
    | Update
    | Release

    public operator func ==(other: GraphicsResourceOperationKind): Bool {
        graphicsResourceOperationKindName(this) == graphicsResourceOperationKindName(other)
    }

    public operator func !=(other: GraphicsResourceOperationKind): Bool { !(this == other) }
}

public func graphicsResourceOperationKindName(kind: GraphicsResourceOperationKind): String {
    match (kind) {
        case GraphicsResourceOperationKind.Create => "create"
        case GraphicsResourceOperationKind.Update => "update"
        case GraphicsResourceOperationKind.Release => "release"
    }
}

private func graphicsResourceOperationKindCode(kind: GraphicsResourceOperationKind): Int64 {
    match (kind) {
        case GraphicsResourceOperationKind.Create => 1
        case GraphicsResourceOperationKind.Update => 2
        case GraphicsResourceOperationKind.Release => 3
    }
}

private func graphicsResourceOperationKindFromCode(code: Int64): GraphicsResourceOperationKind {
    match (code) {
        case 1 => GraphicsResourceOperationKind.Create
        case 2 => GraphicsResourceOperationKind.Update
        case 3 => GraphicsResourceOperationKind.Release
        case _ => throw IllegalArgumentException("unknown graphics resource operation code")
    }
}

/** A slot may be reused only with a strictly newer generation. */
public struct GraphicsResourceId <: Equatable<GraphicsResourceId> {
    public let slot: Int64
    public let generation: Int64

    public init(slot: Int64, generation: Int64) {
        if (slot <= 0 || generation <= 0) {
            throw IllegalArgumentException("graphics resource slot and generation must be positive")
        }
        this.slot = slot
        this.generation = generation
    }

    public operator func ==(other: GraphicsResourceId): Bool {
        slot == other.slot && generation == other.generation
    }

    public operator func !=(other: GraphicsResourceId): Bool { !(this == other) }
}

/** One retained resource transition. Payload is copied at construction. */
public class GraphicsResourceOperation {
    public let operation: GraphicsResourceOperationKind
    public let id: GraphicsResourceId
    public let kind: GraphicsResourceKind
    public let contentRevision: Int64
    private let payload = ArrayList<UInt8>()

    public init(
        operation: GraphicsResourceOperationKind,
        id: GraphicsResourceId,
        kind: GraphicsResourceKind,
        contentRevision: Int64,
        payload!: Array<UInt8> = []
    ) {
        if (contentRevision <= 0) {
            throw IllegalArgumentException("graphics resource content revision must be positive")
        }
        if (operation == GraphicsResourceOperationKind.Release && payload.size != 0) {
            throw IllegalArgumentException("graphics resource release must not carry payload bytes")
        }
        if (operation != GraphicsResourceOperationKind.Release && payload.size == 0) {
            throw IllegalArgumentException("graphics resource create/update requires payload bytes")
        }
        this.operation = operation
        this.id = id
        this.kind = kind
        this.contentRevision = contentRevision
        for (byte in payload) { this.payload.add(byte) }
    }

    public func payloadByteCount(): Int64 { payload.size }
    public func payloadByteAt(index: Int64): UInt8 { payload[index] }
}

/** Render-item identity is separate from resource identity but follows the same reuse rule. */
public struct GraphicsRenderItemId <: Equatable<GraphicsRenderItemId> {
    public let slot: Int64
    public let generation: Int64

    public init(slot: Int64, generation: Int64) {
        if (slot <= 0 || generation <= 0) {
            throw IllegalArgumentException("graphics render-item slot and generation must be positive")
        }
        this.slot = slot
        this.generation = generation
    }

    public operator func ==(other: GraphicsRenderItemId): Bool {
        slot == other.slot && generation == other.generation
    }

    public operator func !=(other: GraphicsRenderItemId): Bool { !(this == other) }
}

/**
 * Provider-neutral retained draw description. Scene/material APIs translate to
 * this shape; applications never pass native renderer handles.
 */
public class GraphicsRenderItem {
    public let id: GraphicsRenderItemId
    public let pipeline: GraphicsResourceId
    public let vertexBuffer: GraphicsResourceId
    public let indexBuffer: ?GraphicsResourceId
    public let firstElement: Int64
    public let elementCount: Int64
    public let instanceCount: Int64
    private let bindings = ArrayList<GraphicsResourceId>()

    public init(
        id: GraphicsRenderItemId,
        pipeline: GraphicsResourceId,
        vertexBuffer: GraphicsResourceId,
        indexBuffer!: ?GraphicsResourceId = None,
        firstElement!: Int64 = 0,
        elementCount!: Int64,
        instanceCount!: Int64 = 1,
        bindings!: Array<GraphicsResourceId> = []
    ) {
        if (firstElement < 0 || elementCount <= 0 || instanceCount <= 0) {
            throw IllegalArgumentException("graphics render-item ranges must be non-negative and non-empty")
        }
        this.id = id
        this.pipeline = pipeline
        this.vertexBuffer = vertexBuffer
        this.indexBuffer = indexBuffer
        this.firstElement = firstElement
        this.elementCount = elementCount
        this.instanceCount = instanceCount
        for (binding in bindings) { this.bindings.add(binding) }
    }

    public func bindingCount(): Int64 { bindings.size }
    public func bindingAt(index: Int64): GraphicsResourceId { bindings[index] }
}

/** One bounded dirty delta against a retained scene revision. */
public class GraphicsSceneDelta {
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    public let baseRevision: Int64
    public let targetRevision: Int64
    private let resourceOperations = ArrayList<GraphicsResourceOperation>()
    private let renderItemUpserts = ArrayList<GraphicsRenderItem>()
    private let renderItemRemovals = ArrayList<GraphicsRenderItemId>()

    public init(
        surfaceId: String,
        surfaceGeneration: Int64,
        frameId: Int64,
        baseRevision: Int64,
        targetRevision: Int64,
        resourceOperations!: Array<GraphicsResourceOperation> = [],
        renderItemUpserts!: Array<GraphicsRenderItem> = [],
        renderItemRemovals!: Array<GraphicsRenderItemId> = []
    ) {
        if (surfaceId.isEmpty() || surfaceGeneration <= 0 || frameId <= 0) {
            throw IllegalArgumentException("graphics delta surface generation and frame identity are required")
        }
        if (baseRevision < 0 || targetRevision <= baseRevision) {
            throw IllegalArgumentException("graphics delta target revision must advance its non-negative base")
        }
        this.surfaceId = surfaceId
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
        this.baseRevision = baseRevision
        this.targetRevision = targetRevision
        for (operation in resourceOperations) { this.resourceOperations.add(operation) }
        for (item in renderItemUpserts) { this.renderItemUpserts.add(item) }
        for (id in renderItemRemovals) { this.renderItemRemovals.add(id) }
    }

    public func resourceOperationCount(): Int64 { resourceOperations.size }
    public func resourceOperationAt(index: Int64): GraphicsResourceOperation {
        resourceOperations[index]
    }
    public func renderItemUpsertCount(): Int64 { renderItemUpserts.size }
    public func renderItemUpsertAt(index: Int64): GraphicsRenderItem { renderItemUpserts[index] }
    public func renderItemRemovalCount(): Int64 { renderItemRemovals.size }
    public func renderItemRemovalAt(index: Int64): GraphicsRenderItemId { renderItemRemovals[index] }
}

/** Security and allocation bounds checked before the final packet allocation. */
public struct GraphicsPacketLimits {
    public let maxResourceOperations: Int64
    public let maxRenderItemUpserts: Int64
    public let maxRenderItemRemovals: Int64
    public let maxBindingsPerItem: Int64
    public let maxResourcePayloadBytes: Int64
    public let maxPacketBytes: Int64

    public init(
        maxResourceOperations!: Int64 = 4096,
        maxRenderItemUpserts!: Int64 = 65536,
        maxRenderItemRemovals!: Int64 = 65536,
        maxBindingsPerItem!: Int64 = 64,
        maxResourcePayloadBytes!: Int64 = 67108864,
        maxPacketBytes!: Int64 = 75497472
    ) {
        if (maxResourceOperations <= 0 || maxRenderItemUpserts <= 0 ||
            maxRenderItemRemovals <= 0 || maxBindingsPerItem <= 0 ||
            maxResourcePayloadBytes <= 0 || maxPacketBytes <= 0) {
            throw IllegalArgumentException("graphics packet limits must be positive")
        }
        if (maxResourceOperations > 1048576 || maxRenderItemUpserts > 1048576 ||
            maxRenderItemRemovals > 1048576 || maxBindingsPerItem > 4096 ||
            maxResourcePayloadBytes > CANGHUI_GRAPHICS_MAX_PACKET_BYTES ||
            maxPacketBytes > CANGHUI_GRAPHICS_MAX_PACKET_BYTES ||
            maxResourcePayloadBytes > maxPacketBytes) {
            throw IllegalArgumentException("graphics packet limits exceed hard safety bounds")
        }
        this.maxResourceOperations = maxResourceOperations
        this.maxRenderItemUpserts = maxRenderItemUpserts
        this.maxRenderItemRemovals = maxRenderItemRemovals
        this.maxBindingsPerItem = maxBindingsPerItem
        this.maxResourcePayloadBytes = maxResourcePayloadBytes
        this.maxPacketBytes = maxPacketBytes
    }
}

/** Auditable provider-boundary shape. F1 deliberately performs no native call. */
public struct GraphicsPacketShape {
    public let packedBufferCount: Int64
    public let plannedNativeSubmitCallCount: Int64
    public let nativeFfiCallCount: Int64
    public let resourcePayloadBytes: Int64
    public let packetBytes: Int64

    public init(resourcePayloadBytes: Int64, packetBytes: Int64) {
        this.packedBufferCount = 1
        this.plannedNativeSubmitCallCount = 1
        this.nativeFfiCallCount = 0
        this.resourcePayloadBytes = resourcePayloadBytes
        this.packetBytes = packetBytes
    }
}

/** Immutable metadata plus one contiguous provider-boundary byte buffer. */
public class GraphicsRenderPacket {
    public let protocol: String
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    public let baseRevision: Int64
    public let targetRevision: Int64
    public let resourceOperationCount: Int64
    public let renderItemUpsertCount: Int64
    public let renderItemRemovalCount: Int64
    public let contentCode: Int64
    public let shape: GraphicsPacketShape
    private let packedBytes: Array<UInt8>

    internal init(delta: GraphicsSceneDelta, bytes: Array<UInt8>, payloadBytes: Int64) {
        this.protocol = CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL
        this.surfaceId = delta.surfaceId
        this.surfaceGeneration = delta.surfaceGeneration
        this.frameId = delta.frameId
        this.baseRevision = delta.baseRevision
        this.targetRevision = delta.targetRevision
        this.resourceOperationCount = delta.resourceOperationCount()
        this.renderItemUpsertCount = delta.renderItemUpsertCount()
        this.renderItemRemovalCount = delta.renderItemRemovalCount()
        this.packedBytes = bytes
        this.contentCode = graphicsPacketContentCode(bytes)
        this.shape = GraphicsPacketShape(payloadBytes, Int64(bytes.size))
    }

    public func byteCount(): Int64 { Int64(packedBytes.size) }
    public func byteAt(index: Int64): UInt8 { packedBytes[index] }

    /**
     * Borrows the one packed buffer for the duration of `body`. Provider code
     * must treat it as read-only and must not retain it after the callback.
     */
    public func withBorrowedBytes<T>(body: (Array<UInt8>) -> T): T { body(packedBytes) }

    /** Built-in providers borrow this module-internal buffer for one submit call. */
    internal func borrowedBytes(): Array<UInt8> { packedBytes }
}

/** Packs one exact-size buffer after all counts and sizes pass their limits. */
public func packGraphicsRenderPacket(
    delta: GraphicsSceneDelta,
    limits!: GraphicsPacketLimits = GraphicsPacketLimits()
): GraphicsRenderPacket {
    if (delta.resourceOperationCount() > limits.maxResourceOperations ||
        delta.renderItemUpsertCount() > limits.maxRenderItemUpserts ||
        delta.renderItemRemovalCount() > limits.maxRenderItemRemovals) {
        throw IllegalArgumentException("graphics delta operation count exceeds packet limits")
    }

    let surfaceBytes = delta.surfaceId.toArray()
    var packetBytes: Int64 = 80 + Int64(surfaceBytes.size)
    var payloadBytes: Int64 = 0

    for (i in 0..delta.resourceOperationCount()) {
        let operation = delta.resourceOperationAt(i)
        payloadBytes = checkedGraphicsPacketAdd(
            payloadBytes, operation.payloadByteCount(), limits.maxResourcePayloadBytes,
            "graphics resource payload bytes exceed packet limits")
        packetBytes = checkedGraphicsPacketAdd(
            packetBytes, 48 + operation.payloadByteCount(), limits.maxPacketBytes,
            "graphics packet bytes exceed packet limits")
    }
    for (i in 0..delta.renderItemUpsertCount()) {
        let item = delta.renderItemUpsertAt(i)
        if (item.bindingCount() > limits.maxBindingsPerItem) {
            throw IllegalArgumentException("graphics render-item binding count exceeds packet limits")
        }
        packetBytes = checkedGraphicsPacketAdd(
            packetBytes, 104 + item.bindingCount() * 16, limits.maxPacketBytes,
            "graphics packet bytes exceed packet limits")
    }
    packetBytes = checkedGraphicsPacketAdd(
        packetBytes, delta.renderItemRemovalCount() * 16, limits.maxPacketBytes,
        "graphics packet bytes exceed packet limits")

    let writer = GraphicsPacketWriter(packetBytes)
    writer.writeRawString(GRAPHICS_PACKET_MAGIC)
    writer.writeInt64(GRAPHICS_PACKET_SCHEMA)
    writer.writeInt64(Int64(surfaceBytes.size))
    writer.writeRawBytes(surfaceBytes)
    writer.writeInt64(delta.surfaceGeneration)
    writer.writeInt64(delta.frameId)
    writer.writeInt64(delta.baseRevision)
    writer.writeInt64(delta.targetRevision)
    writer.writeInt64(delta.resourceOperationCount())
    writer.writeInt64(delta.renderItemUpsertCount())
    writer.writeInt64(delta.renderItemRemovalCount())

    for (i in 0..delta.resourceOperationCount()) {
        let operation = delta.resourceOperationAt(i)
        writer.writeInt64(graphicsResourceOperationKindCode(operation.operation))
        writer.writeInt64(graphicsResourceKindCode(operation.kind))
        writer.writeInt64(operation.id.slot)
        writer.writeInt64(operation.id.generation)
        writer.writeInt64(operation.contentRevision)
        writer.writeInt64(operation.payloadByteCount())
        for (j in 0..operation.payloadByteCount()) {
            writer.writeByte(operation.payloadByteAt(j))
        }
    }
    for (i in 0..delta.renderItemUpsertCount()) {
        let item = delta.renderItemUpsertAt(i)
        writer.writeInt64(item.id.slot)
        writer.writeInt64(item.id.generation)
        writer.writeInt64(item.pipeline.slot)
        writer.writeInt64(item.pipeline.generation)
        writer.writeInt64(item.vertexBuffer.slot)
        writer.writeInt64(item.vertexBuffer.generation)
        match (item.indexBuffer) {
            case Some(index) =>
                writer.writeInt64(1)
                writer.writeInt64(index.slot)
                writer.writeInt64(index.generation)
            case None =>
                writer.writeInt64(0)
                writer.writeInt64(0)
                writer.writeInt64(0)
        }
        writer.writeInt64(item.firstElement)
        writer.writeInt64(item.elementCount)
        writer.writeInt64(item.instanceCount)
        writer.writeInt64(item.bindingCount())
        for (j in 0..item.bindingCount()) {
            let binding = item.bindingAt(j)
            writer.writeInt64(binding.slot)
            writer.writeInt64(binding.generation)
        }
    }
    for (i in 0..delta.renderItemRemovalCount()) {
        let id = delta.renderItemRemovalAt(i)
        writer.writeInt64(id.slot)
        writer.writeInt64(id.generation)
    }

    if (writer.position() != packetBytes) {
        throw IllegalArgumentException("graphics packet writer size mismatch")
    }
    GraphicsRenderPacket(delta, writer.finish(), payloadBytes)
}

public enum GraphicsResourceState <: Equatable<GraphicsResourceState> {
    | Unknown
    | Resident
    | Retiring
    | Released

    public operator func ==(other: GraphicsResourceState): Bool {
        graphicsResourceStateName(this) == graphicsResourceStateName(other)
    }

    public operator func !=(other: GraphicsResourceState): Bool { !(this == other) }
}

public func graphicsResourceStateName(state: GraphicsResourceState): String {
    match (state) {
        case GraphicsResourceState.Unknown => "unknown"
        case GraphicsResourceState.Resident => "resident"
        case GraphicsResourceState.Retiring => "retiring"
        case GraphicsResourceState.Released => "released"
    }
}

/** Structured retained-resource query result. */
public struct GraphicsResourceStateReceipt {
    public let state: GraphicsResourceState
    public let code: String
    public let id: GraphicsResourceId
    public let kind: ?GraphicsResourceKind
    public let contentRevision: Int64
    public let payloadByteCount: Int64
    public let contentCode: Int64

    public init(
        state: GraphicsResourceState,
        code: String,
        id: GraphicsResourceId,
        kind: ?GraphicsResourceKind,
        contentRevision: Int64,
        payloadByteCount: Int64,
        contentCode: Int64
    ) {
        if (code.isEmpty() || contentRevision < 0 || payloadByteCount < 0 || contentCode < 0) {
            throw IllegalArgumentException("graphics resource-state receipt fields are invalid")
        }
        this.state = state
        this.code = code
        this.id = id
        this.kind = kind
        this.contentRevision = contentRevision
        this.payloadByteCount = payloadByteCount
        this.contentCode = contentCode
    }
}

/** One packet submission result. Failure never exposes partially staged state. */
public struct GraphicsReplayReceipt {
    public let ok: Bool
    public let code: String
    public let detail: String
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    public let revision: Int64
    public let residentResourceCount: Int64
    public let retainedRenderItemCount: Int64
    public let packedBufferCount: Int64
    public let plannedNativeSubmitCallCount: Int64
    public let nativeFfiCallCount: Int64

    public init(
        ok: Bool,
        code: String,
        detail: String,
        packet: GraphicsRenderPacket,
        revision: Int64,
        residentResourceCount: Int64,
        retainedRenderItemCount: Int64,
        nativeFfiCallCount!: Int64 = 0
    ) {
        if (code.isEmpty() || revision < 0 || residentResourceCount < 0 ||
            retainedRenderItemCount < 0 || nativeFfiCallCount < 0 ||
            nativeFfiCallCount > packet.shape.plannedNativeSubmitCallCount) {
            throw IllegalArgumentException("graphics replay receipt fields are invalid")
        }
        this.ok = ok
        this.code = code
        this.detail = detail
        this.surfaceId = packet.surfaceId
        this.surfaceGeneration = packet.surfaceGeneration
        this.frameId = packet.frameId
        this.revision = revision
        this.residentResourceCount = residentResourceCount
        this.retainedRenderItemCount = retainedRenderItemCount
        this.packedBufferCount = packet.shape.packedBufferCount
        this.plannedNativeSubmitCallCount = packet.shape.plannedNativeSubmitCallCount
        this.nativeFfiCallCount = nativeFfiCallCount
    }
}

/** Future built-in native providers implement the same one-packet submission boundary. */
public interface GraphicsRenderPacketSink {
    func submit(packet: GraphicsRenderPacket): GraphicsReplayReceipt
}

private struct RetainedGraphicsResource {
    let id: GraphicsResourceId
    let kind: GraphicsResourceKind
    let state: GraphicsResourceState
    let contentRevision: Int64
    let payloadByteCount: Int64
    let contentCode: Int64

    init(
        id: GraphicsResourceId,
        kind: GraphicsResourceKind,
        state: GraphicsResourceState,
        contentRevision: Int64,
        payloadByteCount: Int64,
        contentCode: Int64
    ) {
        this.id = id
        this.kind = kind
        this.state = state
        this.contentRevision = contentRevision
        this.payloadByteCount = payloadByteCount
        this.contentCode = contentCode
    }
}

private struct RetainedGraphicsRenderItem {
    let item: GraphicsRenderItem
    let active: Bool

    init(item: GraphicsRenderItem, active: Bool) {
        this.item = item
        this.active = active
    }
}

/**
 * Deterministic packed-byte replay. It models provider lifetime truth without
 * opening a native device or making an FFI call.
 */
public class NullGraphicsReplay <: GraphicsRenderPacketSink {
    private var currentSurfaceId = ""
    private var currentSurfaceGeneration: Int64 = 0
    private var currentFrameId: Int64 = 0
    private var currentRevision: Int64 = 0
    private var resources = ArrayList<RetainedGraphicsResource>()
    private var renderItems = ArrayList<RetainedGraphicsRenderItem>()

    public func submit(packet: GraphicsRenderPacket): GraphicsReplayReceipt {
        if (packet.protocol != CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL) {
            return failure(packet, "protocol-mismatch", "graphics packet protocol is unsupported")
        }
        if (packet.byteCount() > CANGHUI_GRAPHICS_MAX_PACKET_BYTES) {
            return failure(packet, "packet-too-large", "graphics packet exceeds the hard byte bound")
        }
        if (graphicsPacketContentCode(packet.borrowedBytes()) != packet.contentCode) {
            return failure(packet, "content-code-mismatch", "graphics packet bytes changed after packing")
        }

        try {
            let decoded = decodeGraphicsRenderPacket(packet)
            applyDecodedPacket(packet, decoded)
        } catch (error: IllegalArgumentException) {
            let code = if (error.message.contains(" ")) { "malformed-packet" } else { error.message }
            failure(packet, code, error.message)
        }
    }

    public func resourceState(id: GraphicsResourceId): GraphicsResourceStateReceipt {
        let index = findRetainedResource(resources, id.slot)
        if (index < 0) {
            return GraphicsResourceStateReceipt(
                GraphicsResourceState.Unknown, "resource-unknown", id, None, 0, 0, 0)
        }
        let resource = resources[index]
        if (resource.id.generation != id.generation) {
            return GraphicsResourceStateReceipt(
                GraphicsResourceState.Unknown, "resource-stale-generation", id,
                Some(resource.kind), resource.contentRevision,
                resource.payloadByteCount, resource.contentCode)
        }
        GraphicsResourceStateReceipt(
            resource.state, graphicsResourceStateName(resource.state), id,
            Some(resource.kind), resource.contentRevision,
            resource.payloadByteCount, resource.contentCode)
    }

    public func surfaceId(): String { currentSurfaceId }
    public func surfaceGeneration(): Int64 { currentSurfaceGeneration }
    public func frameId(): Int64 { currentFrameId }
    public func revision(): Int64 { currentRevision }
    public func residentResourceCount(): Int64 { countResidentResources(resources) }
    public func retainedRenderItemCount(): Int64 { countActiveRenderItems(renderItems) }

    private func applyDecodedPacket(
        packet: GraphicsRenderPacket,
        decoded: GraphicsSceneDelta
    ): GraphicsReplayReceipt {
        var resetGeneration = false
        if (currentSurfaceId.isEmpty()) {
            if (decoded.baseRevision != 0) {
                return failure(packet, "base-revision-mismatch", "first graphics packet must start at revision zero")
            }
            resetGeneration = true
        } else if (decoded.surfaceId != currentSurfaceId) {
            return failure(packet, "surface-mismatch", "graphics replay already owns another surface")
        } else if (decoded.surfaceGeneration < currentSurfaceGeneration) {
            return failure(packet, "stale-surface-generation", "graphics packet surface generation is stale")
        } else if (decoded.surfaceGeneration > currentSurfaceGeneration) {
            if (decoded.baseRevision != 0) {
                return failure(packet, "generation-reset-required", "new surface generation must start at revision zero")
            }
            resetGeneration = true
        } else {
            if (decoded.frameId <= currentFrameId) {
                return failure(packet, "stale-frame", "graphics frame id must advance")
            }
            if (decoded.baseRevision != currentRevision) {
                return failure(packet, "base-revision-mismatch", "graphics delta base revision is stale")
            }
        }

        var stagedResources = if (resetGeneration) {
            ArrayList<RetainedGraphicsResource>()
        } else {
            copyRetainedResources(resources)
        }
        var stagedRenderItems = if (resetGeneration) {
            ArrayList<RetainedGraphicsRenderItem>()
        } else {
            copyRetainedRenderItems(renderItems)
        }

        for (i in 0..decoded.resourceOperationCount()) {
            applyResourceOperation(stagedResources, decoded.resourceOperationAt(i))
        }
        for (i in 0..decoded.renderItemUpsertCount()) {
            applyRenderItemUpsert(stagedResources, stagedRenderItems, decoded.renderItemUpsertAt(i))
        }
        for (i in 0..decoded.renderItemRemovalCount()) {
            applyRenderItemRemoval(stagedRenderItems, decoded.renderItemRemovalAt(i))
        }
        validateRetainedRenderItems(stagedResources, stagedRenderItems)

        resources = stagedResources
        renderItems = stagedRenderItems
        currentSurfaceId = decoded.surfaceId
        currentSurfaceGeneration = decoded.surfaceGeneration
        currentFrameId = decoded.frameId
        currentRevision = decoded.targetRevision
        GraphicsReplayReceipt(
            true, "accepted", "graphics packet committed transactionally", packet,
            currentRevision, countResidentResources(resources), countActiveRenderItems(renderItems))
    }

    private func failure(
        packet: GraphicsRenderPacket,
        code: String,
        detail: String
    ): GraphicsReplayReceipt {
        GraphicsReplayReceipt(
            false, code, detail, packet, currentRevision,
            countResidentResources(resources), countActiveRenderItems(renderItems))
    }
}

private class GraphicsPacketWriter {
    private let bytes: Array<UInt8>
    private var offset: Int64 = 0

    init(size: Int64) {
        if (size <= 0 || size > CANGHUI_GRAPHICS_MAX_PACKET_BYTES) {
            throw IllegalArgumentException("graphics packet allocation size is invalid")
        }
        bytes = Array<UInt8>(size, repeat: 0)
    }

    func writeByte(value: UInt8): Unit {
        if (offset >= Int64(bytes.size)) {
            throw IllegalArgumentException("graphics packet writer overflow")
        }
        bytes[offset] = value
        offset += 1
    }

    func writeInt64(value: Int64): Unit {
        if (value < 0) {
            throw IllegalArgumentException("graphics packet integer fields must be non-negative")
        }
        for (shift in 0..8) {
            writeByte(UInt8((value >> (shift * 8)) & 255))
        }
    }

    func writeRawString(value: String): Unit { writeRawBytes(value.toArray()) }

    func writeRawBytes(values: Array<UInt8>): Unit {
        for (value in values) { writeByte(value) }
    }

    func position(): Int64 { offset }
    func finish(): Array<UInt8> { bytes }
}

private class GraphicsPacketCursor {
    private let packet: GraphicsRenderPacket
    private var offset: Int64 = 0

    init(packet: GraphicsRenderPacket) { this.packet = packet }

    func readByte(): UInt8 {
        ensureAvailable(1)
        let value = packet.byteAt(offset)
        offset += 1
        value
    }

    func readInt64(): Int64 {
        ensureAvailable(8)
        var value: Int64 = 0
        for (shift in 0..8) {
            value |= Int64(readByte()) << (shift * 8)
        }
        if (value < 0) {
            throw IllegalArgumentException("graphics packet integer exceeds signed range")
        }
        value
    }

    func readString(count: Int64): String {
        ensureAvailable(count)
        let values = Array<UInt8>(count, repeat: 0)
        for (i in 0..count) { values[i] = readByte() }
        String.fromUtf8(values)
    }

    func readBytes(count: Int64): Array<UInt8> {
        ensureAvailable(count)
        let values = Array<UInt8>(count, repeat: 0)
        for (i in 0..count) { values[i] = readByte() }
        values
    }

    func position(): Int64 { offset }

    private func ensureAvailable(count: Int64): Unit {
        if (count < 0 || offset > packet.byteCount() - count) {
            throw IllegalArgumentException("graphics packet is truncated")
        }
    }
}

/** Module-only decoder shared by transactional replay and the internal FrameGraph bridge. */
protected func decodeGraphicsRenderPacket(packet: GraphicsRenderPacket): GraphicsSceneDelta {
    let cursor = GraphicsPacketCursor(packet)
    let magic = cursor.readString(8)
    if (magic != GRAPHICS_PACKET_MAGIC || cursor.readInt64() != GRAPHICS_PACKET_SCHEMA) {
        throw IllegalArgumentException("graphics packet magic or schema is invalid")
    }
    let surfaceId = cursor.readString(cursor.readInt64())
    let surfaceGeneration = cursor.readInt64()
    let frameId = cursor.readInt64()
    let baseRevision = cursor.readInt64()
    let targetRevision = cursor.readInt64()
    let resourceCount = cursor.readInt64()
    let upsertCount = cursor.readInt64()
    let removalCount = cursor.readInt64()
    if (resourceCount != packet.resourceOperationCount ||
        upsertCount != packet.renderItemUpsertCount ||
        removalCount != packet.renderItemRemovalCount ||
        surfaceId != packet.surfaceId || surfaceGeneration != packet.surfaceGeneration ||
        frameId != packet.frameId || baseRevision != packet.baseRevision ||
        targetRevision != packet.targetRevision) {
        throw IllegalArgumentException("graphics packet metadata does not match its packed header")
    }

    let operations = ArrayList<GraphicsResourceOperation>()
    for (_ in 0..resourceCount) {
        let operation = graphicsResourceOperationKindFromCode(cursor.readInt64())
        let kind = graphicsResourceKindFromCode(cursor.readInt64())
        let id = GraphicsResourceId(cursor.readInt64(), cursor.readInt64())
        let revision = cursor.readInt64()
        let payload = cursor.readBytes(cursor.readInt64())
        operations.add(GraphicsResourceOperation(operation, id, kind, revision, payload: payload))
    }

    let upserts = ArrayList<GraphicsRenderItem>()
    for (_ in 0..upsertCount) {
        let id = GraphicsRenderItemId(cursor.readInt64(), cursor.readInt64())
        let pipeline = GraphicsResourceId(cursor.readInt64(), cursor.readInt64())
        let vertex = GraphicsResourceId(cursor.readInt64(), cursor.readInt64())
        let hasIndex = cursor.readInt64()
        let indexSlot = cursor.readInt64()
        let indexGeneration = cursor.readInt64()
        let index: ?GraphicsResourceId = if (hasIndex == 0) {
            if (indexSlot != 0 || indexGeneration != 0) {
                throw IllegalArgumentException("graphics packet absent index buffer must use zero identity")
            }
            None
        } else if (hasIndex == 1) {
            Some(GraphicsResourceId(indexSlot, indexGeneration))
        } else {
            throw IllegalArgumentException("graphics packet index-buffer presence flag is invalid")
        }
        let firstElement = cursor.readInt64()
        let elementCount = cursor.readInt64()
        let instanceCount = cursor.readInt64()
        let bindingCount = cursor.readInt64()
        if (bindingCount > 4096) {
            throw IllegalArgumentException("graphics packet binding count exceeds hard safety bound")
        }
        let bindings = ArrayList<GraphicsResourceId>()
        for (_ in 0..bindingCount) {
            bindings.add(GraphicsResourceId(cursor.readInt64(), cursor.readInt64()))
        }
        upserts.add(GraphicsRenderItem(
            id, pipeline, vertex, indexBuffer: index, firstElement: firstElement,
            elementCount: elementCount, instanceCount: instanceCount,
            bindings: bindings.toArray()))
    }

    let removals = ArrayList<GraphicsRenderItemId>()
    for (_ in 0..removalCount) {
        removals.add(GraphicsRenderItemId(cursor.readInt64(), cursor.readInt64()))
    }
    if (cursor.position() != packet.byteCount()) {
        throw IllegalArgumentException("graphics packet contains trailing bytes")
    }
    GraphicsSceneDelta(
        surfaceId, surfaceGeneration, frameId, baseRevision, targetRevision,
        resourceOperations: operations.toArray(), renderItemUpserts: upserts.toArray(),
        renderItemRemovals: removals.toArray())
}

private func applyResourceOperation(
    resources: ArrayList<RetainedGraphicsResource>,
    operation: GraphicsResourceOperation
): Unit {
    let index = findRetainedResource(resources, operation.id.slot)
    match (operation.operation) {
        case GraphicsResourceOperationKind.Create =>
            if (index >= 0) {
                let previous = resources[index]
                if (previous.state == GraphicsResourceState.Resident) {
                    throw IllegalArgumentException("resource-slot-live")
                }
                if (operation.id.generation <= previous.id.generation) {
                    throw IllegalArgumentException("resource-stale-generation")
                }
                resources[index] = retainedResource(operation, GraphicsResourceState.Resident)
            } else {
                resources.add(retainedResource(operation, GraphicsResourceState.Resident))
            }
        case GraphicsResourceOperationKind.Update =>
            let previous = requireLiveResource(resources, operation.id)
            if (previous.kind != operation.kind) {
                throw IllegalArgumentException("resource-kind-mismatch")
            }
            if (operation.contentRevision <= previous.contentRevision) {
                throw IllegalArgumentException("resource-stale-content-revision")
            }
            resources[index] = retainedResource(operation, GraphicsResourceState.Resident)
        case GraphicsResourceOperationKind.Release =>
            let previous = requireLiveResource(resources, operation.id)
            if (previous.kind != operation.kind) {
                throw IllegalArgumentException("resource-kind-mismatch")
            }
            if (operation.contentRevision <= previous.contentRevision) {
                throw IllegalArgumentException("resource-stale-content-revision")
            }
            resources[index] = RetainedGraphicsResource(
                operation.id, operation.kind, GraphicsResourceState.Released,
                operation.contentRevision, 0, 0)
    }
}

private func retainedResource(
    operation: GraphicsResourceOperation,
    state: GraphicsResourceState
): RetainedGraphicsResource {
    var code: Int64 = 0
    for (i in 0..operation.payloadByteCount()) {
        code += Int64(operation.payloadByteAt(i)) * ((i % 251) + 1)
    }
    RetainedGraphicsResource(
        operation.id, operation.kind, state, operation.contentRevision,
        operation.payloadByteCount(), code)
}

private func applyRenderItemUpsert(
    resources: ArrayList<RetainedGraphicsResource>,
    renderItems: ArrayList<RetainedGraphicsRenderItem>,
    item: GraphicsRenderItem
): Unit {
    validateRenderItemResources(resources, item)
    let index = findRetainedRenderItem(renderItems, item.id.slot)
    if (index < 0) {
        renderItems.add(RetainedGraphicsRenderItem(item, true))
        return
    }
    let previous = renderItems[index]
    if (previous.active && previous.item.id.generation != item.id.generation) {
        throw IllegalArgumentException("render-item-slot-live")
    }
    if (!previous.active && item.id.generation <= previous.item.id.generation) {
        throw IllegalArgumentException("render-item-stale-generation")
    }
    renderItems[index] = RetainedGraphicsRenderItem(item, true)
}

private func applyRenderItemRemoval(
    renderItems: ArrayList<RetainedGraphicsRenderItem>,
    id: GraphicsRenderItemId
): Unit {
    let index = findRetainedRenderItem(renderItems, id.slot)
    if (index < 0 || !renderItems[index].active || renderItems[index].item.id != id) {
        throw IllegalArgumentException("render-item-stale-or-missing")
    }
    renderItems[index] = RetainedGraphicsRenderItem(renderItems[index].item, false)
}

private func validateRetainedRenderItems(
    resources: ArrayList<RetainedGraphicsResource>,
    renderItems: ArrayList<RetainedGraphicsRenderItem>
): Unit {
    for (retained in renderItems) {
        if (retained.active) { validateRenderItemResources(resources, retained.item) }
    }
}

private func validateRenderItemResources(
    resources: ArrayList<RetainedGraphicsResource>,
    item: GraphicsRenderItem
): Unit {
    let pipeline = requireLiveResource(resources, item.pipeline)
    if (pipeline.kind != GraphicsResourceKind.RenderPipeline) {
        throw IllegalArgumentException("render-item-pipeline-kind-mismatch")
    }
    let vertex = requireLiveResource(resources, item.vertexBuffer)
    if (vertex.kind != GraphicsResourceKind.VertexBuffer) {
        throw IllegalArgumentException("render-item-vertex-kind-mismatch")
    }
    match (item.indexBuffer) {
        case Some(id) =>
            let index = requireLiveResource(resources, id)
            if (index.kind != GraphicsResourceKind.IndexBuffer) {
                throw IllegalArgumentException("render-item-index-kind-mismatch")
            }
        case None => ()
    }
    for (i in 0..item.bindingCount()) {
        let _ = requireLiveResource(resources, item.bindingAt(i))
    }
}

private func requireLiveResource(
    resources: ArrayList<RetainedGraphicsResource>,
    id: GraphicsResourceId
): RetainedGraphicsResource {
    let index = findRetainedResource(resources, id.slot)
    if (index < 0) { throw IllegalArgumentException("resource-missing") }
    let resource = resources[index]
    if (resource.id.generation != id.generation) {
        throw IllegalArgumentException("resource-stale-generation")
    }
    if (resource.state != GraphicsResourceState.Resident) {
        throw IllegalArgumentException("resource-not-resident")
    }
    resource
}

private func findRetainedResource(
    resources: ArrayList<RetainedGraphicsResource>,
    slot: Int64
): Int64 {
    for (i in 0..resources.size) {
        if (resources[i].id.slot == slot) { return i }
    }
    -1
}

private func findRetainedRenderItem(
    renderItems: ArrayList<RetainedGraphicsRenderItem>,
    slot: Int64
): Int64 {
    for (i in 0..renderItems.size) {
        if (renderItems[i].item.id.slot == slot) { return i }
    }
    -1
}

private func copyRetainedResources(
    input: ArrayList<RetainedGraphicsResource>
): ArrayList<RetainedGraphicsResource> {
    let output = ArrayList<RetainedGraphicsResource>()
    for (value in input) { output.add(value) }
    output
}

private func copyRetainedRenderItems(
    input: ArrayList<RetainedGraphicsRenderItem>
): ArrayList<RetainedGraphicsRenderItem> {
    let output = ArrayList<RetainedGraphicsRenderItem>()
    for (value in input) { output.add(value) }
    output
}

private func countResidentResources(resources: ArrayList<RetainedGraphicsResource>): Int64 {
    var count: Int64 = 0
    for (resource in resources) {
        if (resource.state == GraphicsResourceState.Resident) { count += 1 }
    }
    count
}

private func countActiveRenderItems(renderItems: ArrayList<RetainedGraphicsRenderItem>): Int64 {
    var count: Int64 = 0
    for (item in renderItems) { if (item.active) { count += 1 } }
    count
}

private func checkedGraphicsPacketAdd(
    total: Int64,
    added: Int64,
    maximum: Int64,
    message: String
): Int64 {
    if (added < 0 || total < 0 || total > maximum || added > maximum - total) {
        throw IllegalArgumentException(message)
    }
    total + added
}

/** Module-only integrity code shared by transactional replay and the internal FrameGraph bridge. */
protected func graphicsPacketContentCode(bytes: Array<UInt8>): Int64 {
    var code: Int64 = 0
    for (i in 0..bytes.size) {
        code += Int64(bytes[i]) * ((i % 251) + 1)
    }
    code
}
