package chui.scene3d

import chui.host.{HarmonyNativeSurfaceBridge, NativeSurfaceDescriptor, NativeSurfaceFrame,
    NativeSurfaceRenderer}

private class HarmonyHostRendererProbe <: NativeSurfaceRenderer {
    var attaches: Int64 = 0
    var resizes: Int64 = 0
    var frames: Int64 = 0
    var detaches: Int64 = 0
    var lastDetachId = ""
    var lastDetachGeneration: Int64 = 0
    var lastSurface: ?NativeSurfaceDescriptor = None
    var lastFrame: ?NativeSurfaceFrame = None

    public func attach(value: NativeSurfaceDescriptor): Unit {
        attaches += 1
        lastSurface = Some(value)
    }
    public func resize(value: NativeSurfaceDescriptor): Unit {
        resizes += 1
        lastSurface = Some(value)
    }
    public func draw(value: NativeSurfaceFrame): Unit {
        frames += 1
        lastFrame = Some(value)
    }
    public func detach(id: String, generation: Int64): Unit {
        detaches += 1
        lastDetachId = id
        lastDetachGeneration = generation
    }
}

@Test
func harmonyXComponentHostBridgesLifecycleAndDisplayFrames(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    let host = HarmonyXComponentScene3DHost("metro", bridge: bridge)
    let renderer = HarmonyHostRendererProbe()
    host.bind(renderer)

    @Expect(!host.place(Scene3DViewPlacement("metro", 0.0, 0.0, 360.0, 640.0, 3.0)).ok)
    @Expect(bridge.attach(41, 1080, 1920, 3000, 1), 0)
    host.refresh()
    @Expect(renderer.attaches, Int64(1))
    let attached = renderer.lastSurface.getOrThrow()
    @Expect(attached.pixelWidth, Int64(1080))
    @Expect(attached.logicalWidth, Float32(360.0))
    @Expect(attached.generation, Int64(1))

    @Expect(bridge.resize(1200, 2000, 2500, 1), 0)
    host.refresh()
    @Expect(renderer.resizes, Int64(1))
    @Expect(renderer.lastSurface.getOrThrow().logicalWidth, Float32(480.0))

    @Expect(bridge.frame(1000, 16667667, 1), 0)
    host.requestFrame()
    @Expect(renderer.frames, Int64(1))
    @Expect(renderer.lastFrame.getOrThrow().frameId, Int64(0))
    host.requestFrame()
    @Expect(renderer.frames, Int64(1))

    @Expect(bridge.detach(1), 0)
    host.refresh()
    @Expect(renderer.detaches, Int64(1))
    @Expect(host.current().isNone())
}

@Test
func harmonyXComponentHostReattachesOnlyForNewGeneration(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    let host = HarmonyXComponentScene3DHost("scene", bridge: bridge)
    let renderer = HarmonyHostRendererProbe()
    host.bind(renderer)
    @Expect(bridge.attach(71, 800, 600, 2000, 1), 0)
    @Expect(host.place(Scene3DViewPlacement("scene", 0.0, 0.0, 400.0, 300.0, 2.0)).ok)
    @Expect(renderer.attaches, Int64(1))

    @Expect(bridge.detach(1), 0)
    host.refresh()
    @Expect(bridge.attach(73, 800, 600, 2000, 2), 0)
    host.refresh()
    @Expect(renderer.attaches, Int64(2))
    @Expect(renderer.detaches, Int64(1))
    @Expect(host.current().getOrThrow().opaqueHandle, UInt64(73))

    @Expect(host.remove("scene").ok)
    @Expect(renderer.detaches, Int64(2))
    @Expect(host.remove("scene").code, "already-removed")

    @Expect(host.place(Scene3DViewPlacement("scene", 0.0, 0.0, 400.0, 300.0, 2.0)).ok)
    @Expect(renderer.attaches, Int64(3))
    @Expect(host.current().getOrThrow().generation, Int64(2))
}

@Test
func harmonyXComponentHostAttachesRendererBoundAfterPlacement(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    let host = HarmonyXComponentScene3DHost("late-bind", bridge: bridge)
    @Expect(bridge.attach(79, 800, 600, 2000, 1), 0)
    @Expect(host.place(Scene3DViewPlacement("late-bind", 0.0, 0.0, 400.0, 300.0, 2.0)).ok)
    let renderer = HarmonyHostRendererProbe()
    host.bind(renderer)
    @Expect(renderer.attaches, Int64(1))
    @Expect(renderer.lastSurface.getOrThrow().opaqueHandle, UInt64(79))
}
