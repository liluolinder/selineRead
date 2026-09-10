package chui

@Test
func umbrellaExportsRendererEffectContract(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(200.0, 120.0, Color.rgb(10, 20, 30))
    let request = BackdropEffectRequest(
        Rect(20.0, 20.0, 100.0, 48.0),
        cornerRadius: 18.0,
        blurRadius: 8.0,
        refraction: 0.3,
        edgeResponse: 0.7,
        expectedFrameGeneration: renderer.effectFrameGeneration()
    )
    let receipt = renderer.applyBackdropEffect(request)
    @Expect(receipt.status, RendererEffectStatus.Unsupported)
    @Expect(receipt.code, "no-effect-adapter")
    @Expect(rendererEffectStatusName(receipt.status), "unsupported")
    @Expect(rendererEffectCapabilityName(RendererEffectCapability.ShapeUnion), "shape-union")
    renderer.endScene()
}
