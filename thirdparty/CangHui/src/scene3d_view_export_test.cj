package chui

private class UmbrellaSceneFrames <: Scene3DViewFrameSource {
    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        Scene3DFrameSnapshot("umbrella-${clock.frameId}")
    }
}

@Test
func umbrellaExportsScene3DViewAndGamepadContract(): Unit {
    @Expect(gamepadAxisName(GamepadAxis.LeftX), "left-x")
    @Expect(gamepadButtonName(GamepadButton.South), "south")
    @Expect(gamepadConnectionStateName(GamepadConnectionState.Connected), "connected")

    let host = FakeScene3DViewHost()
    let controller = Scene3DViewController("umbrella-scene", host, FakeScene3DProvider(),
        Scene3DResource("umbrella-resource", "memory://umbrella", "sha256:umbrella", 0),
        UmbrellaSceneFrames())
    let view: Widget = Scene3DView(controller, width: 200.0, height: 120.0)
    @Expect(view.focusableId().isSome())
    @Expect(controller.place(Rect(4.0, 8.0, 200.0, 120.0), 2.0).ok)
    @Expect(host.currentPlacement().getOrThrow().scale, Float32(2.0))

    let harmonyBridge = HarmonyNativeSurfaceBridge()
    let harmonyHost = HarmonyXComponentScene3DHost("umbrella-harmony", bridge: harmonyBridge)
    @Expect(harmonyHost.presentationMode(), HostPresentationMode.EmbeddedSurface)
    @Expect(harmonyHost.current().isNone())
}
