package chui

@Test
func umbrellaExportsProviderNeutralGraphicsContract(): Unit {
    let limits = GraphicsLimits(4096, 4, 8, 4)
    let capabilities = GraphicsAdapterCapabilities(
        "umbrella-fake",
        "adapter-0",
        GraphicsBackend.Software,
        GraphicsProfile.Core3D,
        limits,
        capabilities: [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture
        ]
    )
    let request = GraphicsAdapterRequest(
        GraphicsProfile.Core3D,
        requiredCapabilities: [GraphicsCapability.RenderPipeline]
    )

    @Expect(CANGHUI_GRAPHICS_PROTOCOL, "canghui.graphics.v0")
    @Expect(capabilities.supportsProfile(request.profile))
    @Expect(graphicsBackendName(capabilities.backend), "software")

    let pipeline = GraphicsResourceId(1, 1)
    let vertex = GraphicsResourceId(2, 1)
    let packet = packGraphicsRenderPacket(GraphicsSceneDelta(
        "umbrella-surface", 1, 1, 0, 1,
        resourceOperations: [
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Create,
                pipeline,
                GraphicsResourceKind.RenderPipeline,
                1,
                payload: [UInt8(1)]),
            GraphicsResourceOperation(
                GraphicsResourceOperationKind.Create,
                vertex,
                GraphicsResourceKind.VertexBuffer,
                1,
                payload: [UInt8(2)])
        ],
        renderItemUpserts: [GraphicsRenderItem(
            GraphicsRenderItemId(1, 1), pipeline, vertex, elementCount: 3)]
    ))
    let replay = NullGraphicsReplay()
    let receipt = replay.submit(packet)
    @Expect(CANGHUI_GRAPHICS_RENDER_PACKET_PROTOCOL, "canghui.graphics.render-packet.v0")
    @Expect(receipt.ok)
    @Expect(receipt.packedBufferCount, 1)
    @Expect(receipt.nativeFfiCallCount, 0)
}
