package chui.core

import sdl.{DeviceRotation, DeviceRotationEvent, DeviceRotationSource, FrameInfo, Rect, Size, UiEvent,
    deviceRotationDeltaDegrees, deviceRotationIsLandscape, deviceRotationName, deviceRotationSourceName}

private class RotationSizeProbe <: Widget {
    private let desired: Size
    private let focusIdValue: String

    init(desired: Size, focusId: String) {
        this.desired = desired
        this.focusIdValue = focusableControlIdentity(focusId)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
    public func focusableId(): ?String { Some(focusIdValue) }
}

@Test
func deviceRotationVocabularyKeepsDirectionAndSourceTruth(): Unit {
    @Expect(deviceRotationName(DeviceRotation.Portrait), "portrait")
    @Expect(deviceRotationName(DeviceRotation.LandscapeCounterClockwise), "landscape-counter-clockwise")
    @Expect(deviceRotationSourceName(DeviceRotationSource.Gyroscope), "gyroscope")
    @Expect(deviceRotationIsLandscape(DeviceRotation.LandscapeClockwise))
    @Expect(!deviceRotationIsLandscape(DeviceRotation.PortraitUpsideDown))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.Portrait, DeviceRotation.LandscapeClockwise), Float32(90.0))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.Portrait, DeviceRotation.LandscapeCounterClockwise),
        Float32(-90.0))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.Portrait, DeviceRotation.PortraitUpsideDown),
        Float32(180.0))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.PortraitUpsideDown, DeviceRotation.Portrait),
        Float32(-180.0))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.LandscapeClockwise,
        DeviceRotation.LandscapeCounterClockwise), Float32(-180.0))
    @Expect(deviceRotationDeltaDegrees(DeviceRotation.LandscapeCounterClockwise,
        DeviceRotation.LandscapeClockwise), Float32(180.0))
}

@Test
func uiContextFallsBackToViewportUntilProviderReports(): Unit {
    let ctx = testContext()
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 500.0
    @Expect(deviceRotationName(ctx.reportedDeviceRotation()), "unknown")
    @Expect(deviceRotationName(ctx.deviceRotation()), "landscape-clockwise")

    ctx.updateDeviceRotation(DeviceRotationEvent(DeviceRotation.Portrait,
        source: DeviceRotationSource.Gyroscope, timestampMs: UInt64(42)))
    @Expect(deviceRotationName(ctx.deviceRotation()), "portrait")
    let event = ctx.deviceRotationEvent().getOrThrow()
    @Expect(deviceRotationSourceName(event.source), "gyroscope")
    @Expect(event.timestampMs, UInt64(42))
}

@Test
func deviceRotationLayoutSelectsStructureAndExposesOnlyActiveFocusTree(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let rotation = State<DeviceRotation>(DeviceRotation.Portrait)
    let captured = State<?DeviceRotationLayout>(None)
    let build = {
        =>
        let _ = buildRoot(
            {
                =>
                captured.value = Some(DeviceRotationLayout(
                    rotation: rotation.value,
                    key: "responsive-shell",
                    portrait: { => RotationSizeProbe(Size(120.0, 220.0), "portrait-focus") },
                    landscape: { => RotationSizeProbe(Size(320.0, 90.0), "landscape-focus") }
                ))
            },
            store
        )
    }

    build()
    let initial = captured.value.getOrThrow()
    let initialSize = initial.measure(ctx, Size(500.0, 500.0))
    @Expect(initialSize.w, Float32(120.0))
    @Expect(initialSize.h, Float32(220.0))
    @Expect(initial.focusableIds().size, 1)
    @Expect(initial.focusableIds()[0].contains("portrait-focus"))
    @Expect(store.focusRing().size, 1)
    @Expect(store.focusRing()[0].contains("portrait-focus"))

    rotation.value = DeviceRotation.LandscapeClockwise
    build()
    let landscape = captured.value.getOrThrow()
    let landscapeSize = landscape.measure(ctx, Size(500.0, 500.0))
    @Expect(landscapeSize.w, Float32(320.0))
    @Expect(landscapeSize.h, Float32(90.0))
    @Expect(landscape.focusableIds().size, 1)
    @Expect(landscape.focusableIds()[0].contains("landscape-focus"))
    @Expect(store.focusRing().size, 1)
    @Expect(store.focusRing()[0].contains("landscape-focus"))
}

@Test
func pageTransitionPreservesTheFormerCrossWipeAsAnIndependentCapability(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let store = StateStore()
    let showSecond = State<Bool>(false)
    let captured = State<?PageTransitionLayout>(None)
    let build = {
        =>
        let _ = buildRoot(
            {
                =>
                captured.value = Some(PageTransitionLayout(
                    showSecond: showSecond.value,
                    key: "page-shell",
                    animation: AnimationSpec(duration: UInt64(100)),
                    first: { => RotationSizeProbe(Size(100.0, 200.0), "first") },
                    second: { => RotationSizeProbe(Size(300.0, 100.0), "second") }
                ))
            },
            store
        )
    }

    build()
    @Expect(captured.value.getOrThrow().focusableIds().size, 1)
    @Expect(captured.value.getOrThrow().focusableIds()[0].contains("first"))
    showSecond.value = true
    var animatedWidth = Float32(100.0)
    for (frame in 1..12) {
        ctx.frame = FrameInfo(UInt64(frame * 16), UInt64(16))
        build()
        let layout = captured.value.getOrThrow()
        let size = layout.measure(ctx, Size(400.0, 400.0))
        layout.layout(ctx, Rect(0.0, 0.0, size.w, size.h))
        layout.draw(ctx)
        animatedWidth = size.w
    }
    @Expect(animatedWidth > Float32(290.0))
    @Expect(captured.value.getOrThrow().focusableIds().size, 1)
    @Expect(captured.value.getOrThrow().focusableIds()[0].contains("second"))
}

@Test
func wholeFrameRotationTransitionKeepsSignedTurnsAndFitsRotatedBounds(): Unit {
    let clockwise = DeviceRotationTransition(DeviceRotation.Portrait, DeviceRotation.PortraitUpsideDown,
        AnimationSpec(duration: UInt64(100)), Theme.light())
    let counterClockwise = DeviceRotationTransition(DeviceRotation.PortraitUpsideDown, DeviceRotation.Portrait,
        AnimationSpec(duration: UInt64(100)), Theme.light())
    @Expect(clockwise.deltaDegrees(), Float32(180.0))
    @Expect(counterClockwise.deltaDegrees(), Float32(-180.0))

    clockwise.advance(UInt64(50))
    @Expect(clockwise.progress() > Float32(0.49))
    @Expect(clockwise.progress() < Float32(0.51))

    let fitted = rotatedFitRect(760.0, 520.0, 760.0, 520.0, 90.0)
    @Expect(fitted.w <= Float32(520.1))
    @Expect(fitted.h <= Float32(356.0))
    @Expect(fitted.x >= Float32(119.9))
    @Expect(fitted.y >= Float32(81.9))
}
