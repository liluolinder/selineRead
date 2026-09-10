package chui.core

import sdl.{Rect, Renderer}

private class SharedFrameFinishCounter {
    var calls: Int64 = 0
    var outcome = "none"
    func finish(value: String): Bool { calls += 1; outcome = value; true }
}

@Test
func nativeChildFrameSurfaceRegistrationIsHandleFreeAndFrameScoped(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.beginFrameSurfaceRegistration()
    ctx.registerNativeChildFrameSurface("scene", 2, Rect(10.0, 20.0, 80.0, 60.0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), 1)
    let value = ctx.nativeChildFrameSurfaceAt(0)
    @Expect(value.identity, "scene")
    @Expect(value.generation, 2)
    @Expect(value.bounds.x, 10.0)
    @Expect(value.bounds.y, 20.0)
    @Expect(value.bounds.w, 80.0)
    @Expect(value.bounds.h, 60.0)
    ctx.beginFrameSurfaceRegistration()
    @Expect(ctx.nativeChildFrameSurfaceCount(), 0)
}

@Test
func sharedFrameSurfaceRegistrationIsHandleFreeValidatedAndFrameScoped(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let finishes = SharedFrameFinishCounter()
    let pixels: Array<UInt8> = [
        UInt8(255), UInt8(0), UInt8(0), UInt8(255),
        UInt8(0), UInt8(255), UInt8(0), UInt8(255)
    ]
    let value = SharedFrameSurface(
        "scene", 4, 8, Rect(1.0, 2.0, 20.0, 10.0),
        2, 1, 8, "srgb", "premultiplied", "sdr", 9, 17, "portrait", pixels,
        onFinish: {outcome => finishes.finish(outcome)})
    pixels[0] = UInt8(0)
    ctx.beginFrameSurfaceRegistration()
    ctx.registerSharedFrameSurface(value)
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(1))
    let registered = ctx.sharedFrameSurfaceAt(0)
    @Expect(registered.identity, "scene")
    @Expect(registered.frameId, Int64(8))
    @Expect(registered.pixelWidth, Int64(2))
    @Expect(registered.pixels().size, Int64(8))
    @Expect(registered.pixels()[0], UInt8(255))
    @Expect(!ctx.sharedFrameCompositionSucceeded())
    ctx.beginSharedFrameCompositionAttempt()
    registered.recordComposition(true, "sampled")
    @Expect(ctx.sharedFrameCompositionSucceeded())
    registered.recordComposition(false, "upload-failed")
    @Expect(!ctx.sharedFrameCompositionSucceeded())

    ctx.beginFrameSurfaceRegistration()
    @Expect(ctx.sharedFrameSurfaceCount(), Int64(0))
    @Expect(finishes.calls, Int64(1))
    @Expect(finishes.outcome, "abandoned")
    @ExpectThrows[IllegalStateException](registered.pixels())
}

@Test
func sharedFrameSurfaceRejectsMismatchedPayload(): Unit {
    @ExpectThrows[IllegalArgumentException](SharedFrameSurface(
        "scene", 1, 0, Rect(0.0, 0.0, 10.0, 10.0),
        2, 2, 8, "srgb", "opaque", "sdr", 0, 1, "portrait",
        [UInt8(0), UInt8(0), UInt8(0), UInt8(255)]
    ))
    @ExpectThrows[IllegalArgumentException](SharedFrameSurface(
        "scene", 1, 0, Rect(0.0, 0.0, 10.0, 10.0),
        Int64.Max, 1, Int64.Max, "srgb", "opaque", "sdr", 0, 1, "portrait", []
    ))
}
