package sdl

private class RecordingRendererEffectAdapter <: RendererEffectAdapter {
    private let offered: RendererEffectCapabilities
    var beginCount: Int64 = 0
    var applyCount: Int64 = 0
    var endCount: Int64 = 0
    var releaseCount: Int64 = 0
    var lastFrame = RendererEffectFrame(UInt64(0), Rect.zero(), 1.0, 1.0)
    var lastBounds = Rect.zero()

    init(
        maxEffectsPerFrame!: Int64 = 4,
        maxSamplePixels!: Int64 = 1000000,
        shapeUnion!: Bool = false
    ) {
        let capabilities = if (shapeUnion) {
            [
                RendererEffectCapability.BackdropSampling,
                RendererEffectCapability.Blur,
                RendererEffectCapability.Refraction,
                RendererEffectCapability.EdgeResponse,
                RendererEffectCapability.ShapeUnion
            ]
        } else {
            [
                RendererEffectCapability.BackdropSampling,
                RendererEffectCapability.Blur,
                RendererEffectCapability.Refraction,
                RendererEffectCapability.EdgeResponse
            ]
        }
        offered = RendererEffectCapabilities(
            "recording-effect",
            capabilities,
            maxSamplePixels: maxSamplePixels,
            maxEffectsPerFrame: maxEffectsPerFrame
        )
    }

    public func capabilities(): RendererEffectCapabilities { offered }

    public func beginFrame(frame: RendererEffectFrame): Unit {
        beginCount += 1
        lastFrame = frame
    }

    public func apply(
        renderer: Renderer,
        frame: RendererEffectFrame,
        request: BackdropEffectRequest
    ): RendererEffectReceipt {
        let _ = renderer
        applyCount += 1
        lastFrame = frame
        lastBounds = request.resolvedBounds()
        RendererEffectReceipt(
            RendererEffectStatus.Applied,
            "backdrop",
            "recorded",
            providerId: offered.providerId,
            frameGeneration: frame.generation,
            sampledPixels: Int64(lastBounds.w * lastBounds.h),
            effectIndex: applyCount
        )
    }

    public func endFrame(frame: RendererEffectFrame): Unit {
        endCount += 1
        lastFrame = frame
    }

    public func release(): RendererEffectReceipt {
        releaseCount += 1
        RendererEffectReceipt(
            RendererEffectStatus.Applied,
            "release",
            "released",
            providerId: offered.providerId,
            frameGeneration: lastFrame.generation
        )
    }
}

@Test
func backdropRequestRejectsInvalidTransformedBounds(): Unit {
    var rejected = false
    try {
        let _ = BackdropEffectRequest(
            Rect(0.0, 0.0, 20.0, 20.0),
            transformedBounds: Some(Rect(0.0, 0.0, 0.0, 20.0))
        )
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func rendererEffectUsesResolvedBoundsAndRejectsStaleFrames(): Unit {
    let renderer = Renderer.recordingHeadless()
    let adapter = RecordingRendererEffectAdapter()
    @Expect(renderer.installEffectAdapter(adapter).applied())
    renderer.beginScene(240.0, 160.0, Color.rgb(10, 20, 30))
    let generation = renderer.effectFrameGeneration()
    let applied = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(8.0, 8.0, 40.0, 30.0),
        transformedBounds: Some(Rect(18.0, 12.0, 60.0, 32.0)),
        expectedFrameGeneration: generation
    ))
    @Expect(applied.applied())
    @Expect(adapter.lastBounds.x, Float32(18.0))
    @Expect(adapter.lastBounds.w, Float32(60.0))

    let stale = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(8.0, 8.0, 40.0, 30.0),
        expectedFrameGeneration: generation + UInt64(1)
    ))
    @Expect(stale.status, RendererEffectStatus.Rejected)
    @Expect(stale.code, "stale-frame")
    @Expect(adapter.applyCount, Int64(1))
    renderer.endScene()
}

@Test
func unsupportedUnionAndBudgetsSelectDeterministicFallbackReceipts(): Unit {
    let renderer = Renderer.headless()
    let adapter = RecordingRendererEffectAdapter(maxEffectsPerFrame: 2, maxSamplePixels: 5000)
    let _ = renderer.installEffectAdapter(adapter)
    renderer.beginScene(200.0, 100.0, Color.rgb(0, 0, 0))

    let union = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(10.0, 10.0, 40.0, 24.0), requireShapeUnion: true, groupId: "tabs"
    ))
    @Expect(union.status, RendererEffectStatus.Unsupported)
    @Expect(union.code, "shape-union-unsupported")

    let tooLarge = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(0.0, 0.0, 160.0, 80.0), blurRadius: 10.0
    ))
    @Expect(tooLarge.status, RendererEffectStatus.Degraded)
    @Expect(tooLarge.code, "sample-budget-exceeded")

    let first = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(20.0, 20.0, 24.0, 18.0), blurRadius: 0.0
    ))
    let second = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(32.0, 24.0, 24.0, 18.0), blurRadius: 0.0
    ))
    let overBudget = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(70.0, 20.0, 24.0, 18.0), blurRadius: 0.0
    ))
    @Expect(first.applied())
    @Expect(second.applied())
    @Expect(adapter.applyCount, Int64(2))
    @Expect(overBudget.status, RendererEffectStatus.Degraded)
    @Expect(overBudget.code, "effect-budget-exceeded")
    renderer.endScene()
}

@Test
func resizeAdvancesGenerationAndAdapterTeardownIsExactlyOnce(): Unit {
    let renderer = Renderer.headless()
    let first = RecordingRendererEffectAdapter()
    let second = RecordingRendererEffectAdapter()
    let _ = renderer.installEffectAdapter(first)
    renderer.beginScene(100.0, 80.0, Color.rgb(0, 0, 0))
    let oldGeneration = renderer.effectFrameGeneration()
    renderer.endScene()
    renderer.beginScene(300.0, 180.0, Color.rgb(0, 0, 0))
    @Expect(renderer.effectFrameGeneration() > oldGeneration)
    @Expect(second.beginCount, Int64(0))
    @Expect(renderer.installEffectAdapter(second).applied())
    @Expect(first.releaseCount, Int64(1))
    @Expect(second.beginCount, Int64(1))
    @Expect(second.lastFrame.viewport.w, Float32(300.0))
    @Expect(second.lastFrame.viewport.h, Float32(180.0))
    renderer.releaseResources()
    renderer.releaseResources()
    @Expect(second.releaseCount, Int64(1))
}

@Test
func nativeSdlReadbackAppliesInsideOneLiveScene(): Unit {
    let window = SdlWindow(WindowSpec("Renderer effect native test", 240, 160, supersample: 1))
    try {
        let renderer = window.renderer
        renderer.beginScene(240.0, 160.0, Color.rgb(17, 28, 44))
        renderer.fill(Rect(0.0, 0.0, 120.0, 160.0), Color.rgb(245, 90, 88))
        renderer.fill(Rect(120.0, 0.0, 120.0, 160.0), Color.rgb(62, 142, 246))
        let receipt = renderer.applyBackdropEffect(BackdropEffectRequest(
            Rect(60.0, 44.0, 120.0, 64.0),
            cornerRadius: 24.0,
            blurRadius: 8.0,
            refraction: 0.45,
            edgeResponse: 0.7
        ))
        @Expect(receipt.applied())
        @Expect(receipt.providerId, "sdl-readback")
        @Expect(receipt.sampledPixels > 0)
        renderer.endScene()
        renderer.present()
    } finally {
        window.close()
    }
}
