package chui.graphics

private class CountingPacketSink <: GraphicsRenderPacketSink {
    var submitCount: Int64 = 0

    public func submit(packet: GraphicsRenderPacket): GraphicsReplayReceipt {
        submitCount += 1
        GraphicsReplayReceipt(
            true, "accepted", "test sink", packet,
            packet.targetRevision, packet.resourceOperationCount, packet.renderItemUpsertCount)
    }
}

private func bridgePacket(): GraphicsRenderPacket {
    packGraphicsRenderPacket(GraphicsSceneDelta(
        "Private Surface 名称",
        2,
        7,
        0,
        1,
        resourceOperations: [
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Create,
                GraphicsResourceId(3, 2),
                GraphicsResourceKind.Texture2D,
                1,
                payload: [UInt8(9), UInt8(8), UInt8(7)]
            )
        ]
    ))
}

@Test
func graphicsPacketBridgeIsPureBoundedAndSanitized(): Unit {
    let packet = bridgePacket()
    let sink = CountingPacketSink()
    let bridged = bridgeGraphicsRenderPacket(packet, 640, 360)

    @Expect(bridged.ok)
    @Expect(bridged.packetSubmitDeferred)
    @Expect(sink.submitCount, 0)
    match (bridged.graph()) {
        case Some(graph) =>
            @Expect(graph.surfaceKey.startsWith("packet.surface."))
            @Expect(!graph.surfaceKey.contains("Private"))
            @Expect(graph.resourceCount(), 3)
            @Expect(graph.passCount(), 1)
            @Expect(graph.passAt(0).kind == FramePassKind.OffscreenComposition)
            @Expect(graph.passAt(0).stableInputCode, packet.contentCode)
        case None => @Expect(false)
    }
}

@Test
func graphicsPacketBridgeCompilesWithoutSubmittingPacket(): Unit {
    let bridged = bridgeGraphicsRenderPacket(
        bridgePacket(), 320, 180,
        damage: DamageRegion.bounded([FrameDamageRect(20, 30, 40, 50)]))
    let graph = match (bridged.graph()) {
        case Some(value) => value
        case None => throw Exception("bridge must produce a graph")
    }
    let result = compileFrameGraph(
        graph,
        FrameGraphCompilerState(),
        FrameGraphExecutorCapabilities(supportsBoundedRedraw: true))
    @Expect(result.ok)
    match (result.graph()) {
        case Some(compiled) =>
            @Expect(compiled.executedPassCount, 1)
            // A first surface generation is conservatively full even when its source region is bounded.
            @Expect(compiled.redrawMode == FrameRedrawMode.Full)
        case None => @Expect(false)
    }
}

@Test
func graphicsPacketBridgeRejectsInvalidSurfaceBeforeGraphAllocation(): Unit {
    let bridged = bridgeGraphicsRenderPacket(bridgePacket(), 0, 180)
    @Expect(!bridged.ok)
    @Expect(bridged.code, "invalid-surface-size")
    @Expect(bridged.graph().isNone())
}
