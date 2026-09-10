package chui.graphics

import sdl.{BackdropEffectRequest, Rect}

@Test
func backdropEffectBridgePreservesBoundsAndSamplingRadius(): Unit {
    let input = FrameResourceId("target.before", 1)
    let output = FrameResourceId("target.after", 1)
    let bridged = bridgeBackdropEffectRequest(
        BackdropEffectRequest(
            Rect(20.5, 30.25, 80.0, 40.0), blurRadius: 12.0, refraction: 0.5),
        1, input, output, 320, 180)
    @Expect(bridged.ok)
    match (bridged.pass()) {
        case Some(pass) =>
            @Expect(pass.kind == FramePassKind.RendererEffect)
            @Expect(pass.effectRadius, 18)
            @Expect(pass.declaredDamage.rectangleAt(0), FrameDamageRect(20, 30, 81, 41))
            @Expect(pass.readAt(0) == input)
            @Expect(pass.writeAt(0) == output)
        case None => @Expect(false)
    }
}

@Test
func backdropEffectBridgeRejectsOutsideAndSameResource(): Unit {
    let id = FrameResourceId("target", 1)
    let same = bridgeBackdropEffectRequest(
        BackdropEffectRequest(Rect(1.0, 1.0, 10.0, 10.0)), 0, id, id, 100, 100)
    @Expect(!same.ok)
    @Expect(same.code, "invalid-effect-bridge")

    let outside = bridgeBackdropEffectRequest(
        BackdropEffectRequest(Rect(200.0, 200.0, 10.0, 10.0)),
        0, id, FrameResourceId("next", 1), 100, 100)
    @Expect(!outside.ok)
    @Expect(outside.code, "effect-outside-surface")
}
