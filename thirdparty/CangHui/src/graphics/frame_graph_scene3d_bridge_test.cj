package chui.graphics

@Test
func scene3DNativeChildBridgeIsExplicitlyNotUnifiedPixels(): Unit {
    let bridged = bridgeScene3DExternalSurface(
        "private-view-name",
        3,
        0,
        FrameExternalMode.NativeChildSurfaceBarrier,
        bounds: Some(FrameDamageRect(10, 20, 200, 120)))
    @Expect(bridged.ok)
    @Expect(bridged.code, "native-child-surface-barrier")
    @Expect(!bridged.unifiedPixels)
    @Expect(!bridged.clipOcclusionUnified)
    match (bridged.pass()) {
        case Some(value) =>
            @Expect(value.kind == FramePassKind.ExternalScene3D)
            @Expect(value.externalMode == FrameExternalMode.NativeChildSurfaceBarrier)
            @Expect(!value.id.key.contains("private-view-name"))
        case None => @Expect(false)
    }
}

@Test
func scene3DSharedTextureRequiresProviderProofAndExecutorCapability(): Unit {
    let unproved = bridgeScene3DExternalSurface(
        "scene", 1, 0, FrameExternalMode.SharedTexture)
    @Expect(!unproved.ok)
    @Expect(unproved.code, "shared-texture-unproven")

    let proved = bridgeScene3DExternalSurface(
        "scene", 1, 0, FrameExternalMode.SharedTexture,
        providerProvedSharedTexture: true)
    @Expect(proved.ok)
    @Expect(proved.unifiedPixels)
    let resource = proved.resource().getOrThrow()
    let pass = proved.pass().getOrThrow()
    let graph = FrameGraph("scene.surface", 1, 1, 320, 180, [resource], [pass])
    let unsupported = compileFrameGraph(
        graph, FrameGraphCompilerState(), FrameGraphExecutorCapabilities())
    @Expect(!unsupported.ok)
    @Expect(unsupported.code, "unsupported-shared-texture")
}

@Test
func scene3DSharedFrameBridgeBuildsAUnifiedTargetVersionChain(): Unit {
    let input = FrameResourceId("desktop.input", 1)
    let output = FrameResourceId("desktop.output", 1)
    let bridged = bridgeScene3DSharedFrame(
        "scene", 3, 9, 0, input, output, 4096, 71, 11,
        FrameDamageRect(12, 18, 64, 32),
        damage: DamageRegion.bounded([FrameDamageRect(12, 18, 64, 32)]))
    @Expect(bridged.ok)
    @Expect(bridged.code, "shared-frame-composition")
    @Expect(bridged.unifiedPixels)
    @Expect(!bridged.clipOcclusionUnified)
    let source = bridged.resource().getOrThrow()
    let pass = bridged.pass().getOrThrow()
    @Expect(source.kind == FrameResourceKind.Texture)
    @Expect(source.lifetime == FrameResourceLifetime.Imported)
    @Expect(source.declaredBytes, Int64(4096))
    @Expect(pass.kind == FramePassKind.ExternalScene3D)
    @Expect(pass.externalMode == FrameExternalMode.SharedTexture)
    @Expect(pass.readCount(), Int64(2))
    @Expect(pass.readAt(0) == input)
    @Expect(pass.readAt(1) == source.id)
    @Expect(pass.writeCount(), Int64(1))
    @Expect(pass.writeAt(0) == output)

    let inputResource = FrameResourceDescriptor(
        input, FrameResourceKind.Surface, FrameResourceLifetime.Imported)
    let outputResource = FrameResourceDescriptor(
        output, FrameResourceKind.Surface, FrameResourceLifetime.Transient,
        declaredBytes: 4096)
    let graph = FrameGraph(
        "scene.surface", 1, 9, 128, 72,
        [inputResource, source, outputResource], [pass])
    let supported = compileFrameGraph(
        graph,
        FrameGraphCompilerState(),
        FrameGraphExecutorCapabilities(supportsSharedTexture: true))
    @Expect(supported.ok)
    @Expect(supported.graph().getOrThrow().trace.contains("\"unifiedPixels\":true"))
}

@Test
func scene3DSharedImportFeedsTheUiTreeWithoutClaimingClipProof(): Unit {
    let bridged = bridgeScene3DSharedFrameImport(
        "scene", 3, Int64.Max, 0, 4096, Int64.Max, Int64.Max,
        FrameDamageRect(12, 18, 64, 32))
    @Expect(bridged.ok)
    @Expect(bridged.unifiedPixels)
    @Expect(!bridged.clipOcclusionUnified)
    let source = bridged.resource().getOrThrow()
    let pass = bridged.pass().getOrThrow()
    @Expect(pass.readCount(), Int64(1))
    @Expect(pass.readAt(0) == source.id)
    @Expect(pass.writeCount(), Int64(0))
    @Expect(pass.stableInputCode > 0)
}
