package chui.host

@Test
func harmonyNativeSurfaceBridgeRejectsStaleGenerations(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(17, 1080, 1920, 3000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.resize(1200, 2000, 3000, 1), 0)
    @Expect(bridge.detach(1), 0)
    @Expect(bridge.frame(3000, 4000, 1), -2)
    @Expect(bridge.attach(23, 1200, 2000, 3000, 1), -2)
    @Expect(bridge.attach(23, 1200, 2000, 3000, 2), 0)
    let snapshot = bridge.snapshot()
    @Expect(snapshot.attached)
    @Expect(snapshot.generation, Int64(2))
    @Expect(snapshot.handle, Int64(23))
    @Expect(bridge.totalAttachCount(), Int64(2))
    @Expect(bridge.totalResizeCount(), Int64(1))
    @Expect(bridge.totalDetachCount(), Int64(1))
    @Expect(bridge.totalFrameCount(), Int64(1))
}

@Test
func harmonyNativeSurfaceBridgeValidatesIntegerAbiInputs(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(0, 1080, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 0, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 0, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 3000, 0), -1)
    @Expect(bridge.attach(-1, 1080, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 65536, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 16001, 1), -1)
    @Expect(bridge.frame(-1, 0, 1), -1)
}

@Test
func harmonyNativeSurfaceBridgeRejectsRegressedFrameTime(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(31, 1080, 1920, 3000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.frame(999, 2000, 1), -1)
    @Expect(bridge.totalFrameCount(), Int64(1))
}
