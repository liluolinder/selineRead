package chui.core

private func easeApproxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.01
}

@Test
func easingCurvesAnchorAtEndpoints(): Unit {
    // Every named curve passes through (0,0) and (1,1); overshoot happens strictly inside.
    let curves = [
        Easing.Linear,
        Easing.EaseInQuad,
        Easing.EaseOutQuad,
        Easing.EaseInOutQuad,
        Easing.EaseInCubic,
        Easing.EaseOutCubic,
        Easing.EaseInOutCubic,
        Easing.EaseInSine,
        Easing.EaseOutSine,
        Easing.EaseInOutSine,
        Easing.EaseOutBack,
        Easing.CubicBezier(0.25, 0.1, 0.25, 1.0)
    ]
    for (curve in curves) {
        @Expect(easeApproxEq(curve.ease(0.0), 0.0))
        @Expect(easeApproxEq(curve.ease(1.0), 1.0))
    }
}

@Test
func easingClampsProgress(): Unit {
    @Expect(easeApproxEq(Easing.EaseInOutQuad.ease(-0.5), 0.0))
    @Expect(easeApproxEq(Easing.EaseInOutQuad.ease(1.5), 1.0))
    @Expect(easeApproxEq(Easing.EaseInCubic.ease(-3.0), 0.0))
}

@Test
func easingKnownMidpoints(): Unit {
    @Expect(easeApproxEq(Easing.Linear.ease(0.5), 0.5))
    @Expect(easeApproxEq(Easing.EaseInQuad.ease(0.5), 0.25)) // 0.5^2
    @Expect(easeApproxEq(Easing.EaseOutQuad.ease(0.5), 0.75)) // 1-(1-0.5)^2
    @Expect(easeApproxEq(Easing.EaseInCubic.ease(0.5), 0.125)) // 0.5^3
    @Expect(easeApproxEq(Easing.EaseOutCubic.ease(0.5), 0.875))
    @Expect(easeApproxEq(Easing.EaseInOutQuad.ease(0.5), 0.5)) // symmetric midpoint
    @Expect(easeApproxEq(Easing.EaseInOutSine.ease(0.5), 0.5))
}

@Test
func easeInIsSlowerThanEaseOutEarly(): Unit {
    // Early in the timeline ease-in has moved less than linear, ease-out more.
    let t: Float32 = 0.25
    @Expect(Easing.EaseInQuad.ease(t) < Easing.Linear.ease(t))
    @Expect(Easing.EaseOutQuad.ease(t) > Easing.Linear.ease(t))
    // Curves are monotonic: later progress is never less than earlier.
    @Expect(Easing.EaseInOutCubic.ease(0.3) <= Easing.EaseInOutCubic.ease(0.6))
}

@Test
func easeOutBackOvershootsThenSettles(): Unit {
    // Back easing exceeds 1 before returning to it — the overshoot.
    @Expect(Easing.EaseOutBack.ease(0.7) > 1.0)
    @Expect(easeApproxEq(Easing.EaseOutBack.ease(1.0), 1.0))
}

@Test
func cubicBezierApproximatesLinearAndSolvesX(): Unit {
    // Control points on the diagonal reproduce linear timing.
    let linearish = Easing.CubicBezier(0.333, 0.333, 0.666, 0.666)
    @Expect(easeApproxEq(linearish.ease(0.5), 0.5))
    @Expect(easeApproxEq(linearish.ease(0.25), 0.25))
    // The CSS "ease" curve is ahead of linear at its midpoint (fast start).
    let cssEase = Easing.CubicBezier(0.25, 0.1, 0.25, 1.0)
    @Expect(cssEase.ease(0.5) > 0.5)
}
