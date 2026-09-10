package chui.host

@Test
func nativeSurfaceBackendNamesStayStable(): Unit {
    @Expect(nativeSurfaceBackendName(NativeSurfaceBackend.Metal), "metal")
    @Expect(nativeSurfaceBackendName(NativeSurfaceBackend.Vulkan), "vulkan")
}

@Test
func hostPresentationModesSeparateOwnedAndEmbeddedApplications(): Unit {
    @Expect(hostPresentationModeName(HostPresentationMode.OwnedWindow), "owned-window")
    @Expect(hostPresentationModeName(HostPresentationMode.EmbeddedSurface), "embedded-surface")
}

@Test
func hostLoopResultsStayCompatibleWithCallbackDrivers(): Unit {
    @Expect(hostLoopResultName(HostLoopResult.Continue), "continue")
    @Expect(hostLoopResultName(HostLoopResult.Success), "success")
    @Expect(hostLoopResultName(HostLoopResult.Failure("render failed")), "failure")
}

@Test
func nativeSurfaceDescriptorCarriesLogicalAndPixelGeometry(): Unit {
    let surface = NativeSurfaceDescriptor(
        "main",
        NativeSurfaceBackend.Metal,
        UInt64(42),
        393.0,
        852.0,
        1179,
        2556,
        3.0,
        1
    )
    @Expect(surface.logicalWidth, 393.0)
    @Expect(surface.pixelWidth, 1179)
    @Expect(surface.generation, 1)
}

@Test
func nativeSurfaceRejectsMissingOpaqueHandle(): Unit {
    var rejected = false
    try {
        let _ = NativeSurfaceDescriptor(
            "main",
            NativeSurfaceBackend.Metal,
            UInt64(0),
            100.0,
            100.0,
            200,
            200,
            2.0,
            0
        )
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func nativeSurfaceFrameRejectsBackwardsTargetTime(): Unit {
    var rejected = false
    try {
        let _ = NativeSurfaceFrame(7, 200, 199)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}
