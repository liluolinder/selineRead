package chui.core

@Test
func spacingScaleAscendsOnAGrid(): Unit {
    @Expect(Spacing.none.value, Float32(0.0))
    // Strictly ascending steps.
    @Expect(Spacing.xs.value < Spacing.sm.value)
    @Expect(Spacing.sm.value < Spacing.md.value)
    @Expect(Spacing.md.value < Spacing.lg.value)
    @Expect(Spacing.lg.value < Spacing.xl.value)
    @Expect(Spacing.xl.value < Spacing.xxl.value)
    // Known 4px-grid values, expressed in virtual pixels.
    @Expect(Spacing.md.value, Float32(12.0))
    @Expect(Spacing.lg.value, Float32(16.0))
    match (Spacing.md.unit) {
        case LengthUnit.Vp => ()
        case _ => @Fail("Spacing steps should be in virtual pixels")
    }
}

@Test
func radiiScaleAscendsAndPillIsLarge(): Unit {
    @Expect(Radii.none, Float32(0.0))
    @Expect(Radii.sm < Radii.md)
    @Expect(Radii.md < Radii.lg)
    @Expect(Radii.lg < Radii.xl)
    // pill is large enough that the renderer's clamp to half the shorter side fully rounds the ends.
    @Expect(Radii.pill > Radii.xl)
    @Expect(Radii.pill > Float32(1000.0))
}

@Test
func motionDurationsAscend(): Unit {
    @Expect(Motion.fast < Motion.normal)
    @Expect(Motion.normal < Motion.slow)
    @Expect(Motion.fast, UInt64(120))
    @Expect(Motion.normal, UInt64(220))
}

@Test
func motionEasingsAreUsableCurves(): Unit {
    // Each motion easing is a real curve anchored at the endpoints (emphasized overshoots in between).
    for (curve in [Motion.standard, Motion.decelerate, Motion.accelerate, Motion.emphasized]) {
        @Expect(curve.ease(0.0) < 0.01)
        @Expect(curve.ease(1.0) > 0.99)
    }
    // The emphasized curve overshoots past 1 before settling.
    @Expect(Motion.emphasized.ease(0.7) > 1.0)
}

@Test
func motionLevelsScaleOnlyAutomaticAnimationSpecs(): Unit {
    let automatic = AnimationSpec.automatic(duration: UInt64(200), easing: Easing.Linear)
    @Expect(automatic.resolvedDuration(MotionLevel.Basic), UInt64(150))
    @Expect(automatic.resolvedDuration(MotionLevel.Standard), UInt64(200))
    @Expect(automatic.resolvedDuration(MotionLevel.Full), UInt64(250))

    let explicit = AnimationSpec(duration: UInt64(200), easing: Easing.Linear)
    @Expect(explicit.resolvedDuration(MotionLevel.Basic), UInt64(200))
    @Expect(explicit.resolvedDuration(MotionLevel.Full), UInt64(200))
    @Expect(MotionLevel.Basic.amplitude() < MotionLevel.Standard.amplitude())
    @Expect(MotionLevel.Standard.amplitude() < MotionLevel.Full.amplitude())
}

@Test
func themeCarriesMotionLevelBesideVisualTokens(): Unit {
    let basic = Theme.light(motionLevel: MotionLevel.Basic)
    match (basic.motionLevel) {
        case MotionLevel.Basic => ()
        case _ => @Fail("Theme should retain the selected motion level")
    }
    let full = basic.withMotionLevel(MotionLevel.Full)
    @Expect(full.bg.r, basic.bg.r)
    @Expect(full.bg.g, basic.bg.g)
    @Expect(full.bg.b, basic.bg.b)
    @Expect(full.bg.a, basic.bg.a)
    @Expect(full.accent.r, basic.accent.r)
    @Expect(full.accent.g, basic.accent.g)
    @Expect(full.accent.b, basic.accent.b)
    @Expect(full.accent.a, basic.accent.a)
    match (full.motionLevel) {
        case MotionLevel.Full => ()
        case _ => @Fail("withMotionLevel should preserve colors and replace motion")
    }
}

@Test
func reducedMotionCollapsesAutomaticDurationsAndPreservesExplicit(): Unit {
    let automatic = AnimationSpec.automatic(duration: UInt64(200), easing: Easing.Linear)
    @Expect(automatic.resolvedDuration(MotionLevel.Standard, true), UInt64(1))
    @Expect(automatic.resolvedDuration(MotionLevel.Full, true), UInt64(1))
    @Expect(automatic.resolvedDuration(MotionLevel.Standard, false), UInt64(200))

    let explicit = AnimationSpec(duration: UInt64(200), easing: Easing.Linear)
    @Expect(explicit.resolvedDuration(MotionLevel.Standard, true), UInt64(200))
}

@Test
func themeCarriesReduceMotionBesideVisualTokens(): Unit {
    let normal = Theme.light()
    @Expect(!normal.reduceMotion)
    let reduced = Theme.light(reduceMotion: true)
    @Expect(reduced.reduceMotion)
    @Expect(reduced.withMotionLevel(MotionLevel.Full).reduceMotion)
    @Expect(!reduced.withReduceMotion(false).reduceMotion)
    @Expect(Theme.dark(reduceMotion: true).reduceMotion)
}
