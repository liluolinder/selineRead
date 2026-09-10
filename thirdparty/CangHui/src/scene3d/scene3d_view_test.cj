package chui.scene3d

import chui.core.{Theme, UiContext}
import chui.graphics.SdlSharedFrameHeadlessTarget
import chui.host.{NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceEvent, NativeSurfaceFrame}
import sdl.{Color, DeviceRotation, DeviceRotationEvent, DeviceRotationSource, GamepadButton, MouseButton, Rect,
    Renderer, Size, UiEvent, deviceRotationDeltaDegrees}

private class TestFrameSource <: Scene3DViewFrameSource {
    var calls: Int64 = 0

    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        calls += 1
        let snapshot = Scene3DFrameSnapshot("frame-${clock.frameId}")
        snapshot.add(Scene3DEntitySnapshot("entity-${clock.frameId}", 0.0, 0.0, 0.0))
        snapshot
    }
}

private class TestInputRecorder {
    var calls: Int64 = 0
    var localX: Float32 = -1.0
    var localY: Float32 = -1.0
    var lastKind = ""

    func accept(event: Scene3DViewInputEvent): Bool {
        calls += 1
        match (event) {
            case Scene3DViewInputEvent.PointerDown(x, y, _) =>
                localX = x
                localY = y
                lastKind = "pointer-down"
            case Scene3DViewInputEvent.GamepadButtonDown(_, button) =>
                lastKind = match (button) {
                    case GamepadButton.South => "gamepad-south"
                    case _ => "gamepad-other"
                }
            case Scene3DViewInputEvent.GamepadAxisMotion(_, _, _) => lastKind = "gamepad-axis"
            case _ => lastKind = "other"
        }
        true
    }
}

@Test
func scene3DViewControllerBridgesHostLifecycleAndFrames(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let frames = TestFrameSource()
    let controller = Scene3DViewController("metro", host, provider, testResource(), frames)

    @Expect(!controller.isAttached())
    host.publish(NativeSurfaceEvent.Available(testSurface(1, 640.0, 480.0)))
    @Expect(controller.isAttached())
    @Expect(controller.currentGeneration(), Int64(1))
    @Expect(controller.lifecycleReceipt().operation, "load-scene")
    @Expect(controller.lifecycleReceipt().ok)

    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(7, 100, 116)))
    @Expect(frames.calls, Int64(1))
    @Expect(controller.currentFrameId(), Int64(7))
    @Expect(provider.currentSceneId(), "frame-7")
    @Expect(controller.lifecycleReceipt().operation, "present")

    host.publish(NativeSurfaceEvent.Changed(testSurface(1, 800.0, 600.0)))
    @Expect(controller.lifecycleReceipt().operation, "resize")
    @Expect(controller.lifecycleReceipt().ok)

    host.publish(NativeSurfaceEvent.Unavailable("surface", 1))
    @Expect(!controller.isAttached())
    @Expect(controller.lifecycleReceipt().operation, "detach")
}

@Test
func scene3DViewControllerRejectsStaleGenerationAndDeduplicatesPlacement(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let controller = Scene3DViewController("scene", host, provider, testResource(), TestFrameSource())
    let rect = Rect(20.0, 30.0, 320.0, 180.0)

    @Expect(controller.place(rect, 2.0).code, "accepted")
    @Expect(controller.place(rect, 2.0).code, "unchanged")
    @Expect(host.placementCount(), Int64(1))

    host.publish(NativeSurfaceEvent.Available(testSurface(2, 320.0, 180.0)))
    controller.resize(testSurface(1, 640.0, 360.0))
    @Expect(controller.lifecycleReceipt().code, "stale-generation")
    @Expect(controller.isAttached())
    controller.detach("surface", 1)
    @Expect(controller.lifecycleReceipt().code, "stale-generation")
    @Expect(controller.isAttached())

    @Expect(controller.remove().ok)
    @Expect(controller.remove().code, "already-removed")
}

@Test
func scene3DViewLocalizesPointerAndRoutesGamepadOnlyWhileFocused(): Unit {
    let host = FakeScene3DViewHost()
    let recorder = TestInputRecorder()
    let controller = Scene3DViewController("interactive-scene", host, FakeScene3DProvider(), testResource(),
        TestFrameSource(), onInput: { event => recorder.accept(event) })
    let view = Scene3DView(controller, width: 300.0, height: 200.0)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.displayScale = 2.0

    @Expect(view.measure(ctx, Size(500.0, 400.0)).w, Float32(300.0))
    ctx.beginFrameSurfaceRegistration()
    view.layout(ctx, Rect(40.0, 60.0, 300.0, 200.0))
    @Expect(host.currentPlacement().getOrThrow().scale, Float32(2.0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(0))

    host.publish(NativeSurfaceEvent.Available(testSurface(2, 300.0, 200.0)))
    ctx.beginFrameSurfaceRegistration()
    view.layout(ctx, Rect(40.0, 60.0, 300.0, 200.0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(1))
    @Expect(ctx.nativeChildFrameSurfaceAt(0).generation, Int64(2))

    @Expect(!view.handle(ctx, UiEvent.GamepadButtonDown(UInt32(4), GamepadButton.South)))
    @Expect(recorder.calls, Int64(0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 75.0, 92.0)))
    @Expect(ctx.hasFocus("interactive-scene"))
    @Expect(recorder.localX, Float32(35.0))
    @Expect(recorder.localY, Float32(32.0))
    @Expect(recorder.lastKind, "pointer-down")

    @Expect(view.handle(ctx, UiEvent.GamepadButtonDown(UInt32(4), GamepadButton.South)))
    @Expect(recorder.lastKind, "gamepad-south")
    @Expect(recorder.calls, Int64(2))
}

@Test
func scene3DViewSharedModeFallsBackByGenerationAndRejectsFalsePresentedReceipt(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let controller = Scene3DViewController(
        "shared-scene", host, provider, testResource(), TestFrameSource(),
        compositionMode: Scene3DCompositionMode.PreferSharedFrame)
    let view = Scene3DView(controller, width: 120.0, height: 80.0)
    let ctx = UiContext(Renderer.headless(), Theme.light())

    host.publish(NativeSurfaceEvent.Available(testSurface(1, 120.0, 80.0)))
    ctx.beginFrameSurfaceRegistration()
    view.layout(ctx, Rect(10.0, 20.0, 120.0, 80.0))
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(1))

    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(3, 10, 20)))
    ctx.beginFrameSurfaceRegistration()
    view.layout(ctx, Rect(10.0, 20.0, 120.0, 80.0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(0))
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(1))
    let frame = ctx.sharedFrameSurfaceAt(0)
    @Expect(frame.identity, "shared-scene")
    @Expect(frame.frameId, Int64(3))
    @Expect(frame.rotationCode, "portrait")
    @Expect(frame.pixelWidth, Int64(240))
    @Expect(frame.pixelHeight, Int64(160))
    @Expect(frame.pixels().size, Int64(240 * 160 * 4))
    @Expect(provider.sharedAcquireCount(), Int64(1))
    @Expect(provider.sharedReleaseCount(), Int64(0))
    ctx.beginSharedFrameCompositionAttempt()
    // Headless deliberately has no SDL texture device. The widget may paint its placeholder, but
    // it must also restore the established native-child path for this generation and must never
    // report the provider lease as presented when its pixels were not sampled.
    view.draw(ctx)
    @Expect(frame.compositionAttempted())
    @Expect(!frame.compositionSucceeded())
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(1))
    @Expect(ctx.nativeChildFrameSurfaceAt(0).identity, "shared-scene")
    @Expect(ctx.finishSharedFrameSurfaces("fallback"))
    @Expect(frame.finishOutcome(), "fallback")
    @Expect(provider.sharedReleaseCount(), Int64(1))
    @Expect(ctx.finishSharedFrameSurfaces("presented"))
    @Expect(frame.finishOutcome(), "fallback")
    @Expect(provider.sharedReleaseCount(), Int64(1))

    // A persistent failure does not oscillate back to a missing shared frame when the declarative
    // body rebuilds its ephemeral Scene3DView around the same retained controller.
    let rebuiltView = Scene3DView(controller, width: 120.0, height: 80.0)
    ctx.beginFrameSurfaceRegistration()
    rebuiltView.layout(ctx, Rect(10.0, 20.0, 120.0, 80.0))
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(1))
    @Expect(provider.sharedAcquireCount(), Int64(1))

    // A new native generation is a bounded recovery point and may try shared composition again.
    host.publish(NativeSurfaceEvent.Available(testSurface(2, 120.0, 80.0)))
    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(4, 30, 40)))
    let recoveredView = Scene3DView(controller, width: 120.0, height: 80.0)
    ctx.beginFrameSurfaceRegistration()
    recoveredView.layout(ctx, Rect(10.0, 20.0, 120.0, 80.0))
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(1))
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(0))
    @Expect(provider.sharedAcquireCount(), Int64(2))
    @Expect(ctx.finishSharedFrameSurfaces("fallback"))
    @Expect(provider.sharedReleaseCount(), Int64(2))
}

@Test
func scene3DSharedFrameHeadlessMatrixPropagatesSignedRotationResizeAndFallbackOutcome(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let controller = Scene3DViewController(
        "rotation-shared-scene", host, provider, testResource(), TestFrameSource(),
        compositionMode: Scene3DCompositionMode.PreferSharedFrame)
    let view = Scene3DView(controller, width: 14.0, height: 12.0)
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let target = SdlSharedFrameHeadlessTarget(16, 16, clear: Color.rgb(2, 3, 4))

    host.publish(NativeSurfaceEvent.Available(testSurface(1, 120.0, 80.0)))
    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(5, 30, 40)))

    composeRotationLayout(
        view, ctx, target, provider,
        DeviceRotation.Portrait, DeviceRotation.LandscapeClockwise, 90.0,
        "landscape-clockwise", Rect(2.0, 2.0, 12.0, 8.0))
    composeRotationLayout(
        view, ctx, target, provider,
        DeviceRotation.Portrait, DeviceRotation.PortraitUpsideDown, 180.0,
        "portrait-upside-down", Rect(3.0, 1.0, 8.0, 12.0))
    composeRotationLayout(
        view, ctx, target, provider,
        DeviceRotation.Portrait, DeviceRotation.LandscapeCounterClockwise, -90.0,
        "landscape-counter-clockwise", Rect(1.0, 3.0, 13.0, 7.0))
    composeRotationLayout(
        view, ctx, target, provider,
        DeviceRotation.PortraitUpsideDown, DeviceRotation.Portrait, -180.0,
        "portrait", Rect(4.0, 2.0, 7.0, 11.0))

    @Expect(provider.sharedAcquireCount(), Int64(4))
    @Expect(provider.sharedReleaseCount(), Int64(4))
}

@Test
func scene3DViewControllerRejectsCrossContextReuseBeforeHostReplacement(): Unit {
    let host = FakeScene3DViewHost()
    let controller = Scene3DViewController(
        "window-owned-scene", host, FakeScene3DProvider(), testResource(), TestFrameSource())
    let view = Scene3DView(controller, width: 120.0, height: 80.0)
    let first = UiContext(Renderer.headless(), Theme.light())
    let second = UiContext(Renderer.headless(), Theme.light())
    let bounds = Rect(10.0, 20.0, 120.0, 80.0)

    view.layout(first, bounds)
    @Expect(host.placementCount(), Int64(1))

    var rejected = false
    try {
        view.layout(second, bounds)
    } catch (_: IllegalStateException) {
        rejected = true
    }
    @Expect(rejected)
    @Expect(host.placementCount(), Int64(1))
}

private func testResource(): Scene3DResource {
    Scene3DResource("metro-scene", "memory://metro", "sha256:test", 0)
}

private func composeRotationLayout(
    view: Scene3DView,
    ctx: UiContext,
    target: SdlSharedFrameHeadlessTarget,
    provider: FakeScene3DProvider,
    from: DeviceRotation,
    to: DeviceRotation,
    expectedDelta: Float32,
    expectedCode: String,
    bounds: Rect
): Unit {
    @Expect(deviceRotationDeltaDegrees(from, to), expectedDelta)
    ctx.updateDeviceRotation(DeviceRotationEvent(
        from, source: DeviceRotationSource.Synthetic, timestampMs: UInt64(1)))
    ctx.updateDeviceRotation(DeviceRotationEvent(
        to, source: DeviceRotationSource.Gyroscope, timestampMs: UInt64(2)))
    target.clear(Color.rgb(2, 3, 4))
    ctx.renderer.clearDrawIr()
    ctx.beginFrameSurfaceRegistration()
    view.layout(ctx, bounds)
    @Expect(ctx.nativeChildFrameSurfaceCount(), Int64(0))
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(1))
    let frame = ctx.sharedFrameSurfaceAt(0)
    @Expect(frame.rotationCode, expectedCode)
    @Expect(frame.bounds.x, bounds.x)
    @Expect(frame.bounds.y, bounds.y)
    @Expect(frame.bounds.w, bounds.w)
    @Expect(frame.bounds.h, bounds.h)

    ctx.beginSharedFrameCompositionAttempt()
    let result = target.composite(
        ctx.renderer,
        frame.pixelWidth,
        frame.pixelHeight,
        frame.rowBytes,
        frame.alphaMode,
        frame.pixels(),
        bounds,
        cornerRadius: 2.0,
        rotationCode: frame.rotationCode)
    frame.recordComposition(result.ok, result.code)
    @Expect(result.ok)
    @Expect(ctx.sharedFrameCompositionSucceeded())
    // A recording-headless software sample is deterministic composition proof, not a native
    // present. The lease therefore terminates as fallback and must never manufacture Presented.
    @Expect(ctx.finishSharedFrameSurfaces("fallback"))
    @Expect(frame.finishOutcome(), "fallback")
    @Expect(frame.isFinished())
    @Expect(!frame.finishOutcome().contains("presented"))
    @Expect(provider.sharedReleaseCount() > 0)
}

private func testSurface(generation: Int64, width: Float32, height: Float32): NativeSurfaceDescriptor {
    NativeSurfaceDescriptor("surface", NativeSurfaceBackend.Metal, UInt64(99), width, height,
        Int64(width * 2.0), Int64(height * 2.0), 2.0, generation)
}
