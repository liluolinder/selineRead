package chui.graphics

private func packetPipelineId(generation!: Int64 = 1): GraphicsResourceId {
    GraphicsResourceId(1, generation)
}

private func packetVertexId(generation!: Int64 = 1): GraphicsResourceId {
    GraphicsResourceId(2, generation)
}

private func packetItemId(generation!: Int64 = 1): GraphicsRenderItemId {
    GraphicsRenderItemId(1, generation)
}

private func packetCreateResources(
    pipelineGeneration!: Int64 = 1,
    vertexGeneration!: Int64 = 1
): Array<GraphicsResourceOperation> {
    [
        GraphicsResourceOperation(
            GraphicsResourceOperationKind.Create,
            packetPipelineId(generation: pipelineGeneration),
            GraphicsResourceKind.RenderPipeline,
            1,
            payload: [UInt8(1), UInt8(2)]
        ),
        GraphicsResourceOperation(
            GraphicsResourceOperationKind.Create,
            packetVertexId(generation: vertexGeneration),
            GraphicsResourceKind.VertexBuffer,
            1,
            payload: [UInt8(3), UInt8(4)]
        )
    ]
}

private func packetRenderItem(
    generation!: Int64 = 1,
    pipelineGeneration!: Int64 = 1,
    vertexGeneration!: Int64 = 1
): GraphicsRenderItem {
    GraphicsRenderItem(
        packetItemId(generation: generation),
        packetPipelineId(generation: pipelineGeneration),
        packetVertexId(generation: vertexGeneration),
        elementCount: 3
    )
}

private func packetInitialDelta(surfaceGeneration!: Int64 = 1): GraphicsSceneDelta {
    GraphicsSceneDelta(
        "main", surfaceGeneration, 1, 0, 1,
        resourceOperations: packetCreateResources(
            pipelineGeneration: surfaceGeneration,
            vertexGeneration: surfaceGeneration),
        renderItemUpserts: [packetRenderItem(
            generation: surfaceGeneration,
            pipelineGeneration: surfaceGeneration,
            vertexGeneration: surfaceGeneration)]
    )
}

@Test
func graphicsPacketNamesAndGenerationIdentitiesStayStable(): Unit {
    @Expect(CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL, "canghui.graphics.render-packet.v0")
    @Expect(graphicsResourceKindName(GraphicsResourceKind.Texture2D), "texture-2d")
    @Expect(graphicsResourceOperationKindName(GraphicsResourceOperationKind.Release), "release")
    @Expect(graphicsResourceStateName(GraphicsResourceState.Resident), "resident")
    @Expect(graphicsResourceStateName(GraphicsResourceState.Retiring), "retiring")
    @Expect(packetPipelineId() == GraphicsResourceId(1, 1))
    @Expect(packetItemId() == GraphicsRenderItemId(1, 1))

    var rejectedResource = false
    try {
        let _ = GraphicsResourceId(0, 1)
    } catch (_: IllegalArgumentException) {
        rejectedResource = true
    }
    @Expect(rejectedResource)

    var rejectedReleasePayload = false
    try {
        let _ = GraphicsResourceOperation(
            GraphicsResourceOperationKind.Release,
            packetPipelineId(),
            GraphicsResourceKind.RenderPipeline,
            2,
            payload: [UInt8(1)])
    } catch (_: IllegalArgumentException) {
        rejectedReleasePayload = true
    }
    @Expect(rejectedReleasePayload)

    var rejectedLimits = false
    try {
        let _ = GraphicsPacketLimits(maxPacketBytes: CANGHUI_GRAPHICS_MAX_PACKET_BYTES + 1)
    } catch (_: IllegalArgumentException) {
        rejectedLimits = true
    }
    @Expect(rejectedLimits)
}

@Test
func graphicsPacketPackingIsDeterministicExactSizedAndSingleBufferShaped(): Unit {
    let first = packGraphicsRenderPacket(packetInitialDelta())
    let second = packGraphicsRenderPacket(packetInitialDelta())

    @Expect(first.byteCount(), 288)
    @Expect(first.shape.packetBytes, 288)
    @Expect(first.shape.resourcePayloadBytes, 4)
    @Expect(first.shape.packedBufferCount, 1)
    @Expect(first.shape.plannedNativeSubmitCallCount, 1)
    @Expect(first.shape.nativeFfiCallCount, 0)
    @Expect(first.contentCode, second.contentCode)
    @Expect(first.byteCount(), second.byteCount())
    @Expect(first.withBorrowedBytes({bytes => Int64(bytes[0])}), 67)
    for (i in 0..first.byteCount()) {
        @Expect(first.byteAt(i), second.byteAt(i))
    }

    let providerReceipt = GraphicsReplayReceipt(
        true, "native-submitted", "provider accepted one packed buffer", first,
        1, 2, 1, nativeFfiCallCount: 1)
    @Expect(providerReceipt.nativeFfiCallCount, 1)
}

@Test
func nullGraphicsReplayRetainsUpdatesReleasesAndGenerationReuse(): Unit {
    let replay = NullGraphicsReplay()
    let created = replay.submit(packGraphicsRenderPacket(packetInitialDelta()))
    @Expect(created.ok)
    @Expect(created.code, "accepted")
    @Expect(created.revision, 1)
    @Expect(created.residentResourceCount, 2)
    @Expect(created.retainedRenderItemCount, 1)
    @Expect(created.packedBufferCount, 1)
    @Expect(created.plannedNativeSubmitCallCount, 1)
    @Expect(created.nativeFfiCallCount, 0)

    let updated = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 2, 1, 2,
        resourceOperations: [GraphicsResourceOperation(
            GraphicsResourceOperationKind.Update,
            packetVertexId(),
            GraphicsResourceKind.VertexBuffer,
            2,
            payload: [UInt8(9), UInt8(8), UInt8(7)])]
    )))
    @Expect(updated.ok)
    let vertex = replay.resourceState(packetVertexId())
    @Expect(vertex.state == GraphicsResourceState.Resident)
    @Expect(vertex.contentRevision, 2)
    @Expect(vertex.payloadByteCount, 3)

    let released = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 3, 2, 3,
        resourceOperations: [
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Release,
                packetPipelineId(),
                GraphicsResourceKind.RenderPipeline,
                2),
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Release,
                packetVertexId(),
                GraphicsResourceKind.VertexBuffer,
                3)
        ],
        renderItemRemovals: [packetItemId()]
    )))
    @Expect(released.ok)
    @Expect(released.residentResourceCount, 0)
    @Expect(released.retainedRenderItemCount, 0)
    @Expect(replay.resourceState(packetPipelineId()).state == GraphicsResourceState.Released)

    let reused = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 4, 3, 4,
        resourceOperations: [GraphicsResourceOperation(
            GraphicsResourceOperationKind.Create,
            packetPipelineId(generation: 2),
            GraphicsResourceKind.RenderPipeline,
            1,
            payload: [UInt8(5)])]
    )))
    @Expect(reused.ok)
    @Expect(replay.resourceState(packetPipelineId()).code, "resource-stale-generation")
    @Expect(replay.resourceState(packetPipelineId(generation: 2)).state == GraphicsResourceState.Resident)
}

@Test
func nullGraphicsReplayRollsBackDanglingAndStaleResourceOperations(): Unit {
    let replay = NullGraphicsReplay()
    @Expect(replay.submit(packGraphicsRenderPacket(packetInitialDelta())).ok)

    let dangling = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 2, 1, 2,
        resourceOperations: [GraphicsResourceOperation(
            GraphicsResourceOperationKind.Release,
            packetVertexId(),
            GraphicsResourceKind.VertexBuffer,
            2)]
    )))
    @Expect(!dangling.ok)
    @Expect(dangling.code, "resource-not-resident")
    @Expect(dangling.revision, 1)
    @Expect(dangling.residentResourceCount, 2)
    @Expect(dangling.retainedRenderItemCount, 1)
    @Expect(replay.resourceState(packetVertexId()).state == GraphicsResourceState.Resident)
    @Expect(replay.resourceState(packetVertexId()).contentRevision, 1)

    let stale = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 2, 1, 2,
        resourceOperations: [GraphicsResourceOperation(
            GraphicsResourceOperationKind.Update,
            packetVertexId(generation: 2),
            GraphicsResourceKind.VertexBuffer,
            2,
            payload: [UInt8(6)])]
    )))
    @Expect(!stale.ok)
    @Expect(stale.code, "resource-stale-generation")
    @Expect(replay.revision(), 1)
}

@Test
func nullGraphicsReplayRejectsMalformedBytesWithoutStateMutation(): Unit {
    let replay = NullGraphicsReplay()
    @Expect(replay.submit(packGraphicsRenderPacket(packetInitialDelta())).ok)

    let next = packGraphicsRenderPacket(GraphicsSceneDelta("main", 1, 2, 1, 2))
    next.borrowedBytes()[0] = UInt8(0)
    let malformed = replay.submit(next)
    @Expect(!malformed.ok)
    @Expect(malformed.code, "content-code-mismatch")
    @Expect(replay.frameId(), 1)
    @Expect(replay.revision(), 1)
    @Expect(replay.residentResourceCount(), 2)
}

@Test
func nullGraphicsReplayEnforcesFrameRevisionAndSurfaceGenerationReset(): Unit {
    let replay = NullGraphicsReplay()
    @Expect(replay.submit(packGraphicsRenderPacket(packetInitialDelta())).ok)

    let staleFrame = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 1, 1, 2)))
    @Expect(!staleFrame.ok)
    @Expect(staleFrame.code, "stale-frame")

    let staleBase = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 2, 0, 1)))
    @Expect(!staleBase.ok)
    @Expect(staleBase.code, "base-revision-mismatch")

    let reset = replay.submit(packGraphicsRenderPacket(packetInitialDelta(surfaceGeneration: 2)))
    @Expect(reset.ok)
    @Expect(replay.surfaceGeneration(), 2)
    @Expect(replay.frameId(), 1)
    @Expect(replay.revision(), 1)
    @Expect(replay.resourceState(packetPipelineId()).state == GraphicsResourceState.Unknown)
    @Expect(replay.resourceState(packetPipelineId(generation: 2)).state == GraphicsResourceState.Resident)

    let staleGeneration = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 2, 1, 2)))
    @Expect(!staleGeneration.ok)
    @Expect(staleGeneration.code, "stale-surface-generation")
}

@Test
func graphicsPacketBoundsRejectBeforePacking(): Unit {
    var rejectedCount = false
    try {
        let _ = packGraphicsRenderPacket(
            packetInitialDelta(),
            limits: GraphicsPacketLimits(maxResourceOperations: 1))
    } catch (_: IllegalArgumentException) {
        rejectedCount = true
    }
    @Expect(rejectedCount)

    var rejectedPayload = false
    try {
        let _ = packGraphicsRenderPacket(
            packetInitialDelta(),
            limits: GraphicsPacketLimits(
                maxResourcePayloadBytes: 3,
                maxPacketBytes: 1024))
    } catch (_: IllegalArgumentException) {
        rejectedPayload = true
    }
    @Expect(rejectedPayload)
}

@Test
func nullGraphicsReplayRejectsDuplicateLiveResourceTransactionally(): Unit {
    let replay = NullGraphicsReplay()
    let duplicate = replay.submit(packGraphicsRenderPacket(GraphicsSceneDelta(
        "main", 1, 1, 0, 1,
        resourceOperations: [
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Create,
                packetVertexId(),
                GraphicsResourceKind.VertexBuffer,
                1,
                payload: [UInt8(1)]),
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Create,
                packetVertexId(),
                GraphicsResourceKind.VertexBuffer,
                2,
                payload: [UInt8(2)])
        ]
    )))
    @Expect(!duplicate.ok)
    @Expect(duplicate.code, "resource-slot-live")
    @Expect(replay.revision(), 0)
    @Expect(replay.residentResourceCount(), 0)
}
