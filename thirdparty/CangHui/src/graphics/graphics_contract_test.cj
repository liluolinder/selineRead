package chui.graphics

private func graphicsTestSurface(generation!: Int64 = 1): GraphicsSurfaceLease {
    GraphicsSurfaceLease(
        "main-scene",
        "host-surface:main",
        640.0,
        480.0,
        1280,
        960,
        2.0,
        generation,
        colorSpace: GraphicsColorSpace.DisplayP3,
        alphaMode: GraphicsAlphaMode.Premultiplied
    )
}

private func graphicsTestCapabilities(
    profile!: GraphicsProfile = GraphicsProfile.Core3D
): GraphicsAdapterCapabilities {
    GraphicsAdapterCapabilities(
        "fake-bgfx",
        "adapter-0",
        GraphicsBackend.Metal,
        profile,
        GraphicsLimits(8192, 4, 8, 4),
        capabilities: [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture,
            GraphicsCapability.Instancing
        ]
    )
}

@Test
func graphicsContractNamesStayStableAndSurfaceDoesNotChooseBackend(): Unit {
    @Expect(CANGHUI_GRAPHICS_PROTOCOL, "canghui.graphics.v0")
    @Expect(graphicsProfileName(GraphicsProfile.Core3D), "core-3d")
    @Expect(graphicsPowerPreferenceName(GraphicsPowerPreference.HighPerformance), "high-performance")
    @Expect(graphicsCapabilityName(GraphicsCapability.StorageBuffer), "storage-buffer")
    @Expect(graphicsBackendName(GraphicsBackend.WebGPU), "webgpu")
    @Expect(graphicsColorSpaceName(GraphicsColorSpace.DisplayP3), "display-p3")
    @Expect(graphicsAlphaModeName(GraphicsAlphaMode.Premultiplied), "premultiplied")

    let surface = graphicsTestSurface()
    @Expect(surface.platformToken, "host-surface:main")
    @Expect(surface.generation, 1)
    @Expect(surface.colorSpace == GraphicsColorSpace.DisplayP3)
}

@Test
func graphicsContractsRejectInvalidIdentityLimitsAndDuplicates(): Unit {
    var rejectedSurface = false
    try {
        let _ = GraphicsSurfaceLease("", "", 1.0, 1.0, 1, 1, 1.0, 0)
    } catch (_: IllegalArgumentException) {
        rejectedSurface = true
    }
    @Expect(rejectedSurface)

    var rejectedNonFiniteSurface = false
    try {
        let _ = GraphicsSurfaceLease(
            "surface", "token", Float32.NaN, 1.0, 1, 1, 1.0, 1)
    } catch (_: IllegalArgumentException) {
        rejectedNonFiniteSurface = true
    }
    @Expect(rejectedNonFiniteSurface)

    var rejectedLimits = false
    try {
        let _ = GraphicsLimits(0, 1, 1, 1)
    } catch (_: IllegalArgumentException) {
        rejectedLimits = true
    }
    @Expect(rejectedLimits)

    var rejectedCapabilities = false
    try {
        let _ = GraphicsAdapterCapabilities(
            "provider", "adapter", GraphicsBackend.Software, GraphicsProfile.Core3D,
            GraphicsLimits(1024, 1, 1, 1), capabilities: [
                GraphicsCapability.RenderPipeline,
                GraphicsCapability.RenderPipeline
            ]
        )
    } catch (_: IllegalArgumentException) {
        rejectedCapabilities = true
    }
    @Expect(rejectedCapabilities)

    var rejectedIncompleteCoreProfile = false
    try {
        let _ = GraphicsAdapterCapabilities(
            "provider", "adapter", GraphicsBackend.Software, GraphicsProfile.Core3D,
            GraphicsLimits(1024, 1, 1, 1), capabilities: [
                GraphicsCapability.RenderPipeline,
                GraphicsCapability.SampledTexture
            ]
        )
    } catch (_: IllegalArgumentException) {
        rejectedIncompleteCoreProfile = true
    }
    @Expect(rejectedIncompleteCoreProfile)

    var rejectedRequest = false
    try {
        let _ = GraphicsAdapterRequest(
            GraphicsProfile.Core3D, requiredCapabilities: [
                GraphicsCapability.DepthTexture,
                GraphicsCapability.DepthTexture
            ]
        )
    } catch (_: IllegalArgumentException) {
        rejectedRequest = true
    }
    @Expect(rejectedRequest)
}

@Test
func graphicsComputeProfileRequiresCompletePortableComputeBaseline(): Unit {
    var rejected = false
    try {
        let _ = GraphicsAdapterCapabilities(
            "provider", "adapter", GraphicsBackend.Vulkan, GraphicsProfile.Compute3D,
            GraphicsLimits(8192, 4, 8, 4), capabilities: [
                GraphicsCapability.RenderPipeline,
                GraphicsCapability.SampledTexture,
                GraphicsCapability.DepthTexture,
                GraphicsCapability.ComputePipeline
            ]
        )
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)

    let complete = GraphicsAdapterCapabilities(
        "provider", "adapter", GraphicsBackend.Vulkan, GraphicsProfile.Compute3D,
        GraphicsLimits(8192, 4, 8, 4), capabilities: [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture,
            GraphicsCapability.ComputePipeline,
            GraphicsCapability.StorageBuffer
        ]
    )
    @Expect(complete.supportsProfile(GraphicsProfile.Core3D))
    @Expect(complete.supportsProfile(GraphicsProfile.Compute3D))
}

@Test
func fakeGraphicsAdapterSelectsPortableProfileWithoutSurfaceBackendInput(): Unit {
    let adapter = FakeGraphicsAdapter(graphicsTestCapabilities())
    let selection = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.Core3D,
        powerPreference: GraphicsPowerPreference.HighPerformance,
        requiredCapabilities: [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.DepthTexture
        ],
        minimumLimits: Some(GraphicsLimits(4096, 2, 4, 1))
    ), graphicsTestSurface())

    @Expect(selection.ok())
    @Expect(selection.status == GraphicsAdapterSelectionStatus.Selected)
    @Expect(selection.code, "selected")
    @Expect(selection.backend == GraphicsBackend.Metal)
    @Expect(selection.providerId, "fake-bgfx")
    @Expect(selection.requestedProfile == GraphicsProfile.Core3D)
    @Expect(selection.selectedProfile == GraphicsProfile.Core3D)
    @Expect(adapter.isSelected())
    @Expect(adapter.currentGeneration(), 1)
}

@Test
func fakeGraphicsAdapterReportsMissingCapabilityAndLimitsWithoutCommittingState(): Unit {
    let adapter = FakeGraphicsAdapter(graphicsTestCapabilities())
    let missing = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.Core3D,
        requiredCapabilities: [GraphicsCapability.ComputePipeline]
    ), graphicsTestSurface())
    @Expect(!missing.ok())
    @Expect(missing.status == GraphicsAdapterSelectionStatus.Unsupported)
    @Expect(missing.code, "missing-capability:compute-pipeline")
    @Expect(!adapter.isSelected())

    let limits = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.Core3D,
        minimumLimits: Some(GraphicsLimits(16384, 4, 8, 4))
    ), graphicsTestSurface())
    @Expect(!limits.ok())
    @Expect(limits.code, "limits-unsupported")
    @Expect(!adapter.isSelected())
}

@Test
func fakeGraphicsAdapterMakesFallbackAndGenerationTruthExplicit(): Unit {
    let adapter = FakeGraphicsAdapter(graphicsTestCapabilities())
    let unsupported = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.NativeExtended
    ), graphicsTestSurface())
    @Expect(unsupported.status == GraphicsAdapterSelectionStatus.Unsupported)
    @Expect(unsupported.code, "profile-unsupported")

    let degraded = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.NativeExtended,
        allowFallback: true
    ), graphicsTestSurface())
    @Expect(degraded.ok())
    @Expect(degraded.status == GraphicsAdapterSelectionStatus.Degraded)
    @Expect(degraded.code, "profile-fallback")
    @Expect(degraded.requestedProfile == GraphicsProfile.NativeExtended)
    @Expect(degraded.selectedProfile == GraphicsProfile.Core3D)

    let stale = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.Core3D
    ), graphicsTestSurface())
    @Expect(stale.status == GraphicsAdapterSelectionStatus.Rejected)
    @Expect(stale.code, "stale-generation")

    let advanced = adapter.select(GraphicsAdapterRequest(
        GraphicsProfile.Core3D
    ), graphicsTestSurface(generation: 2))
    @Expect(advanced.ok())
    @Expect(adapter.currentGeneration(), 2)

    @Expect(!adapter.release("main-scene", 1).ok)
    let released = adapter.release("main-scene", 2)
    @Expect(released.ok)
    @Expect(released.code, "released")
    @Expect(!adapter.isSelected())
}
