package chui.graphics

import std.collection.ArrayList

/**
 * A pure bridge result. Packing/decoding is checked here, but the packet is deliberately not
 * submitted: a runtime coordinator may commit it only after its frame executor commits.
 */
protected class GraphicsPacketFrameGraphBridge {
    public let ok: Bool
    public let code: String
    public let detail: String
    public let packetSubmitDeferred: Bool
    private let value: ?FrameGraph

    private init(ok: Bool, code: String, detail: String, value: ?FrameGraph) {
        this.ok = ok
        this.code = code
        this.detail = detail
        this.packetSubmitDeferred = ok
        this.value = value
    }

    static func accepted(graph: FrameGraph): GraphicsPacketFrameGraphBridge {
        GraphicsPacketFrameGraphBridge(
            true,
            "accepted",
            "graphics packet decoded into frame metadata; provider submit remains deferred",
            Some(graph)
        )
    }

    static func rejected(code: String, detail: String): GraphicsPacketFrameGraphBridge {
        GraphicsPacketFrameGraphBridge(false, code, detail, None)
    }

    public func graph(): ?FrameGraph { value }
}

/**
 * Converts one immutable retained packet into a bounded graph pass without touching a packet sink.
 * Resource payloads, shader bytes and render-item contents stay in the packet and never enter the
 * graph trace; only stable identities, kinds and byte counts are described.
 */
protected func bridgeGraphicsRenderPacket(
    packet: GraphicsRenderPacket,
    surfaceWidth: Int64,
    surfaceHeight: Int64,
    damage!: DamageRegion = DamageRegion.full()
): GraphicsPacketFrameGraphBridge {
    if (surfaceWidth <= 0 || surfaceHeight <= 0) {
        return GraphicsPacketFrameGraphBridge.rejected(
            "invalid-surface-size", "graphics packet bridge surface size must be positive")
    }
    if (packet.protocol != CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL) {
        return GraphicsPacketFrameGraphBridge.rejected(
            "protocol-mismatch", "graphics packet protocol is unsupported")
    }
    if (packet.byteCount() > CANGHUI_GRAPHICS_MAX_PACKET_BYTES) {
        return GraphicsPacketFrameGraphBridge.rejected(
            "packet-too-large", "graphics packet exceeds the hard byte bound")
    }
    if (graphicsPacketContentCode(packet.borrowedBytes()) != packet.contentCode) {
        return GraphicsPacketFrameGraphBridge.rejected(
            "content-code-mismatch", "graphics packet bytes changed after packing")
    }

    let decoded = try {
        decodeGraphicsRenderPacket(packet)
    } catch (error: IllegalArgumentException) {
        return GraphicsPacketFrameGraphBridge.rejected("malformed-packet", error.message)
    }

    let descriptorCount = decoded.resourceOperationCount() + decoded.renderItemUpsertCount() +
        decoded.renderItemRemovalCount() + 2
    if (descriptorCount > CANGHUI_FRAME_GRAPH_MAX_RESOURCES) {
        return GraphicsPacketFrameGraphBridge.rejected(
            "resource-count-over-cap", "graphics packet cannot fit the frame graph hard resource cap")
    }

    let resources = ArrayList<FrameResourceDescriptor>()
    let reads = ArrayList<FrameResourceId>()
    let packetId = FrameResourceId("packet.buffer", decoded.frameId)
    resources.add(FrameResourceDescriptor(
        packetId,
        FrameResourceKind.Buffer,
        FrameResourceLifetime.Imported,
        declaredBytes: packet.byteCount()
    ))
    reads.add(packetId)

    for (i in 0..decoded.resourceOperationCount()) {
        let operation = decoded.resourceOperationAt(i)
        let id = FrameResourceId(
            "packet.resource.${operation.id.slot}.${i}", operation.id.generation)
        resources.add(FrameResourceDescriptor(
            id,
            packetFrameResourceKind(operation.kind),
            FrameResourceLifetime.Imported,
            declaredBytes: operation.payloadByteCount()
        ))
        reads.add(id)
    }
    for (i in 0..decoded.renderItemUpsertCount()) {
        let item = decoded.renderItemUpsertAt(i)
        let id = FrameResourceId("packet.item.${item.id.slot}.${i}", item.id.generation)
        resources.add(FrameResourceDescriptor(
            id, FrameResourceKind.Buffer, FrameResourceLifetime.Imported))
        reads.add(id)
    }
    for (i in 0..decoded.renderItemRemovalCount()) {
        let item = decoded.renderItemRemovalAt(i)
        let id = FrameResourceId("packet.removal.${item.slot}.${i}", item.generation)
        resources.add(FrameResourceDescriptor(
            id, FrameResourceKind.Buffer, FrameResourceLifetime.Imported))
        reads.add(id)
    }

    let outputId = FrameResourceId("packet.scene", decoded.targetRevision)
    resources.add(FrameResourceDescriptor(
        outputId,
        FrameResourceKind.Buffer,
        FrameResourceLifetime.Persistent
    ))
    let apply = FramePassDescriptor(
        FramePassId("packet.apply"),
        0,
        FramePassKind.OffscreenComposition,
        reads: reads.toArray(),
        writes: [outputId],
        declaredDamage: damage,
        stableInputCode: packet.contentCode,
        canCull: true
    )
    let graph = FrameGraph(
        packetFrameSurfaceKey(decoded.surfaceId),
        decoded.surfaceGeneration,
        decoded.frameId,
        surfaceWidth,
        surfaceHeight,
        resources.toArray(),
        [apply],
        frameDamage: damage,
        limits: FrameGraphLimits(
            maxPasses: 4,
            maxResources: CANGHUI_FRAME_GRAPH_MAX_RESOURCES,
            maxDependencies: CANGHUI_FRAME_GRAPH_MAX_DEPENDENCIES,
            maxDamageRectangles: CANGHUI_FRAME_GRAPH_MAX_DAMAGE_RECTS,
            maxTraceBytes: CANGHUI_FRAME_GRAPH_MAX_TRACE_BYTES,
            maxDeclaredResourceBytes: CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES
        )
    )
    GraphicsPacketFrameGraphBridge.accepted(graph)
}

private func packetFrameResourceKind(value: GraphicsResourceKind): FrameResourceKind {
    match (value) {
        case GraphicsResourceKind.VertexBuffer => FrameResourceKind.Buffer
        case GraphicsResourceKind.IndexBuffer => FrameResourceKind.Buffer
        case GraphicsResourceKind.UniformBuffer => FrameResourceKind.Buffer
        case GraphicsResourceKind.Texture2D => FrameResourceKind.Texture
        case GraphicsResourceKind.Sampler => FrameResourceKind.Sampler
        case GraphicsResourceKind.ShaderModule => FrameResourceKind.Shader
        case GraphicsResourceKind.RenderPipeline => FrameResourceKind.Pipeline
    }
}

/** Surface names may be private or non-ASCII; traces retain only this deterministic bounded token. */
private func packetFrameSurfaceKey(value: String): String {
    var code: Int64 = 17
    for (byte in value.toArray()) {
        code = (code * 131 + Int64(byte)) % 2147483647
    }
    "packet.surface.${code}"
}
