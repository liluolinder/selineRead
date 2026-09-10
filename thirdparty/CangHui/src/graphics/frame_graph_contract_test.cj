package chui.graphics

@Test
func frameGraphContractNamesAndIdentityStayStable(): Unit {
    @Expect(CANGHUI_FRAME_GRAPH_PROTOCOL, "canghui.frame-graph.v0")
    @Expect(frameResourceLifetimeName(FrameResourceLifetime.Transient), "transient")
    @Expect(frameResourceKindName(FrameResourceKind.ExternalSurface), "external-surface")
    @Expect(framePassKindName(FramePassKind.CopyResolve), "copy-resolve")
    @Expect(frameExternalModeName(FrameExternalMode.NativeChildSurfaceBarrier),
        "native-child-surface-barrier")
    @Expect(frameDynamicRangeName(FrameDynamicRange.Sdr), "sdr")
    @Expect(frameDamageKindName(FrameDamageKind.Bounded), "bounded")
    @Expect(frameRedrawModeName(FrameRedrawMode.Bounded), "bounded")
    @Expect(framePresentModeName(FramePresentMode.Full), "full")
    @Expect(FrameResourceId("surface.main", 2) == FrameResourceId("surface.main", 2))
    @Expect(FrameResourceId("surface.main", 2) != FrameResourceId("surface.main", 3))
    @Expect(FramePassId("ui.main") == FramePassId("ui.main"))
}

@Test
func frameGraphContractRejectsUnsafeTokensGeometryAndLimits(): Unit {
    var rejectedToken = false
    try {
        let _ = FramePassId("UI/Main")
    } catch (_: IllegalArgumentException) {
        rejectedToken = true
    }
    @Expect(rejectedToken)

    var rejectedGeneration = false
    try {
        let _ = FrameResourceId("surface.main", 0)
    } catch (_: IllegalArgumentException) {
        rejectedGeneration = true
    }
    @Expect(rejectedGeneration)

    var rejectedRect = false
    try {
        let _ = FrameDamageRect(Int64.Max - 1, 0, 2, 1)
    } catch (_: IllegalArgumentException) {
        rejectedRect = true
    }
    @Expect(rejectedRect)

    var rejectedBounds = false
    try {
        let _ = FrameGraphLimits(maxPasses: CANGHUI_FRAME_GRAPH_MAX_PASSES + 1)
    } catch (_: IllegalArgumentException) {
        rejectedBounds = true
    }
    @Expect(rejectedBounds)
}

@Test
func frameDamageAndGraphDescriptorsCopyCallerArrays(): Unit {
    let initial = FrameDamageRect(1, 2, 3, 4)
    let changed = FrameDamageRect(8, 8, 2, 2)
    let rectangles = [initial]
    let damage = DamageRegion.bounded(rectangles)
    rectangles[0] = changed
    @Expect(damage.rectangleCount(), 1)
    @Expect(damage.rectangleAt(0), initial)

    let source = FrameResourceDescriptor(
        FrameResourceId("surface.main", 1),
        FrameResourceKind.Surface,
        FrameResourceLifetime.Imported)
    let output = FrameResourceDescriptor(
        FrameResourceId("surface.main", 2),
        FrameResourceKind.Surface,
        FrameResourceLifetime.Persistent)
    let pass = FramePassDescriptor(
        FramePassId("ui.main"), 0, FramePassKind.Ui2D,
        reads: [source.id], writes: [output.id],
        bounds: Some(FrameDamageRect(0, 0, 32, 32)), stableInputCode: 7)
    let resources = [source, output]
    let passes = [pass]
    let graph = FrameGraph("main", 1, 1, 32, 32, resources, passes)
    resources[0] = output
    passes[0] = FramePassDescriptor(
        FramePassId("ui.changed"), 0, FramePassKind.Ui2D, writes: [output.id])

    @Expect(graph.resourceAt(0).id, source.id)
    @Expect(graph.passAt(0).id, pass.id)
    @Expect(graph.frameDamage.kind == FrameDamageKind.Full)
}
