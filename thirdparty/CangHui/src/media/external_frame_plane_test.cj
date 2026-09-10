package chui.media

import sdl.{Rect, Renderer}

private class FakeExternalFramePlane <: ExternalFramePlane {
    public func render(target: Renderer, frame: Rect): Bool {
        true
    }

    public func snapshot(): ?ExternalFrameSnapshot {
        Some(ExternalFrameSnapshot(
            1,
            320,
            240,
            100,
            10000,
            0,
            true,
            true
        ))
    }

    public func play(): Bool {
        true
    }

    public func pause(): Bool {
        true
    }

    public func seek(positionMs: Int64): Bool {
        true
    }

    public func close(): Unit {}
}

@Test
func externalFramePlaneInterfaceIsImplementable(): Unit {
    let plane = FakeExternalFramePlane()
    @Expect(plane.play())
    @Expect(plane.pause())
    @Expect(plane.seek(5000))
    let snapshot = plane.snapshot()
    @Expect(snapshot.isSome())
    if (let Some(value) <- snapshot) {
        @Expect(value.width, UInt32(320))
        @Expect(value.height, UInt32(240))
        @Expect(value.playing)
        @Expect(value.prepared)
        @Expect(value.currentTimeMs, Int64(100))
    }
}
