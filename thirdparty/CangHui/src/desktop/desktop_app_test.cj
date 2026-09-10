package chui.desktop

import sdl.{MouseButton, UiEvent}
import sdl.system.SdlHint

private class DesktopRunTestException <: Exception {
    public init(message: String) { super(message) }
}

@Test
func desktopRunPreservesOriginatingFailureOverCleanupFailure(): Unit {
    let original = DesktopRunTestException("frame-loop-origin")
    let cleanup = DesktopRunTestException("cleanup-affinity")

    @Expect(preferredDesktopRunFailure(Some(original), cleanup).message, "frame-loop-origin")
}

@Test
func desktopRunReportsCleanupFailureWhenNoEarlierFailureExists(): Unit {
    let cleanup = DesktopRunTestException("cleanup-affinity")

    @Expect(preferredDesktopRunFailure(None, cleanup).message, "cleanup-affinity")
}

@Test
func tickDeltaGuardsAgainstClockReset(): Unit {
    @Expect(tickDelta(UInt64(10), UInt64(25)), UInt64(15))
    @Expect(tickDelta(UInt64(25), UInt64(10)), UInt64(0))
}

@Test
func desktopCaptureRequestNormalizesUnsetAndZeroFrameBudgets(): Unit {
    let defaulted = DesktopCaptureRequest("/tmp/capture.bmp")
    @Expect(defaulted.path, "/tmp/capture.bmp")
    @Expect(defaulted.settleFrames, UInt64(48))

    let zero = DesktopCaptureRequest("/tmp/capture.bmp", settleFrames: UInt64(0))
    @Expect(zero.settleFrames, UInt64(1))
    @Expect(captureFrameValue(""), UInt64(48))
    @Expect(captureFrameValue("0"), UInt64(48))
    @Expect(captureFrameValue("12"), UInt64(12))
    @Expect(captureFrameValue("invalid"), UInt64(48))
}

@Test
func explicitDesktopCaptureRequestWinsHostAndLegacyCompatibilityInputs(): Unit {
    let explicit = DesktopCaptureRequest("explicit.bmp", settleFrames: UInt64(3))
    let host = DesktopCaptureRequest("host.bmp", settleFrames: UInt64(4))
    let legacy = DesktopCaptureRequest("legacy.bmp", settleFrames: UInt64(5))
    @Expect((resolveDesktopCaptureRequest(Some(explicit), Some(host), Some(legacy)) ?? legacy).path,
        "explicit.bmp")
    @Expect((resolveDesktopCaptureRequest(None, Some(host), Some(legacy)) ?? legacy).path, "host.bmp")
    @Expect((resolveDesktopCaptureRequest(None, None, Some(legacy)) ?? explicit).path, "legacy.bmp")
    @Expect(resolveDesktopCaptureRequest(None, None, None).isNone())
}

@Test
func devicePacingUsesPresentForRenderedFramesAndLightIdlePolling(): Unit {
    let pacing = resolveFramePacing(None, true, UInt32(16), false)
    @Expect(framePacingUsesVSync(pacing))
    @Expect(resolvedFramePacingName(pacing), "device")
    @Expect(framePacingDelay(pacing, UInt64(0), true), UInt32(0))
    @Expect(framePacingDelay(pacing, UInt64(0), false), UInt32(16))
}

@Test
func kmodeDefaultsToUnboundedUnlessTheApplicationChoosesAPolicy(): Unit {
    let automatic = resolveFramePacing(None, true, UInt32(16), true)
    @Expect(resolvedFramePacingName(automatic), "unbounded")
    @Expect(!framePacingUsesVSync(automatic))
    @Expect(framePacingDelay(automatic, UInt64(0), true), UInt32(0))
    @Expect(framePacingDelay(automatic, UInt64(0), false), UInt32(16))

    let explicit = resolveFramePacing(Some(FramePacing.Fixed(UInt32(120))), true, UInt32(16), true)
    @Expect(resolvedFramePacingName(explicit), "fixed-120fps")
    @Expect(framePacingDelay(explicit, UInt64(3), true), UInt32(5))
    @Expect(framePacingDelay(explicit, UInt64(9), true), UInt32(0))
}

@Test
func disabledVsyncKeepsTheLegacyDelayWhenNoPolicyWasAdded(): Unit {
    let pacing = resolveFramePacing(None, false, UInt32(16), false)
    @Expect(resolvedFramePacingName(pacing), "legacy-delay-16ms")
    @Expect(framePacingDelay(pacing, UInt64(30), true), UInt32(16))
}

@Test
func invalidFixedFrameRatesFailClosed(): Unit {
    var zeroRejected = false
    try {
        let _ = resolveFramePacing(Some(FramePacing.Fixed(UInt32(0))), true, UInt32(16), false)
    } catch (_: IllegalArgumentException) {
        zeroRejected = true
    }
    @Expect(zeroRejected)

    var excessiveRejected = false
    try {
        let _ = resolveFramePacing(Some(FramePacing.Fixed(UInt32(1001))), true, UInt32(16), false)
    } catch (_: IllegalArgumentException) {
        excessiveRejected = true
    }
    @Expect(excessiveRejected)
}

@Test
func pointerDragBuildsDownMoveUpSequence(): Unit {
    let events = buildPointerDragEvents(10.0, 20.0, 30.0, 40.0, 2)
    @Expect(events.size, 4)
    match (events[0]) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            @Expect(x, 10.0)
            @Expect(y, 20.0)
        case _ => @Expect(false)
    }
    match (events[1]) {
        case UiEvent.MouseMove(x, y) =>
            @Expect(x, 20.0)
            @Expect(y, 30.0)
        case _ => @Expect(false)
    }
    match (events[2]) {
        case UiEvent.MouseMove(x, y) =>
            @Expect(x, 30.0)
            @Expect(y, 40.0)
        case _ => @Expect(false)
    }
    match (events[3]) {
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            @Expect(x, 30.0)
            @Expect(y, 40.0)
        case _ => @Expect(false)
    }
}

@Test
func pointerDragClampsZeroStepsToOne(): Unit {
    let events = buildPointerDragEvents(0.0, 0.0, 5.0, 5.0, 0)
    @Expect(events.size, 3)
}

@Test
func desktopDefaultsFirstFocusClickToReachControls(): Unit {
    let hints = defaultDesktopHints()
    @Expect(hints.size, 1)
    match (hints[0].hint) {
        case SdlHint.MouseFocusClickthrough => @Expect(true)
        case _ => @Expect(false)
    }
    @Expect(hints[0].value, "1")
}

@Test
func frameGraphSkipsTransientZeroAreaDesktopSurfaces(): Unit {
    @Expect(desktopFrameSurfaceUsable(Int32(1280), Int32(720)))
    @Expect(!desktopFrameSurfaceUsable(Int32(0), Int32(720)))
    @Expect(!desktopFrameSurfaceUsable(Int32(1280), Int32(0)))
    @Expect(!desktopFrameSurfaceUsable(Int32(-1), Int32(720)))
}
