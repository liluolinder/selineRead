package chui.core

private func scrollApproxEq(a: Float32, b: Float32): Bool {
    let delta = if (a >= b) { a - b } else { b - a }
    delta < 0.01
}

@Test
func webScrollDefaultsFollowThemeMotionAndUseACssStyleCurve(): Unit {
    let options = ScrollOptions.web()
    @Expect(scrollBehaviorName(options.behavior), "smooth")
    @Expect(options.wheelStep, 72.0)
    @Expect(options.animation.resolvedDuration(MotionLevel.Basic), UInt64(165))
    @Expect(options.animation.resolvedDuration(MotionLevel.Standard), UInt64(220))
    @Expect(options.animation.resolvedDuration(MotionLevel.Full), UInt64(275))
}

@Test
func immediateScrollPreservesTheDirectOffsetContract(): Unit {
    let motion = ScrollMotion(100.0)
    let next = motion.wheel(100.0, -1.0, 1000.0, 200.0, ScrollOptions.immediate())
    @Expect(next, 172.0)
    @Expect(!motion.active())
}

@Test
func smoothScrollEasesAndSettlesOnTheBoundedTarget(): Unit {
    let motion = ScrollMotion(100.0)
    let options = ScrollOptions.web(duration: UInt64(220), easing: Easing.EaseOutCubic)
    @Expect(motion.wheel(100.0, -1.0, 1000.0, 200.0, options), 100.0)
    @Expect(motion.active())
    let quarter = motion.advance(100.0, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(55), options)
    @Expect(quarter > 100.0)
    @Expect(quarter < 172.0)
    let settled = motion.advance(quarter, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(220), options)
    @Expect(scrollApproxEq(settled, 172.0))
    @Expect(!motion.active())
}

@Test
func repeatedWheelInputAccumulatesAgainstThePreviousTarget(): Unit {
    let motion = ScrollMotion(0.0)
    let options = ScrollOptions.web(duration: UInt64(200), easing: Easing.Linear)
    let _ = motion.wheel(0.0, -1.0, 1000.0, 200.0, options)
    let partial = motion.advance(0.0, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(50), options)
    let _ = motion.wheel(partial, -1.0, 1000.0, 200.0, options)
    let settled = motion.advance(partial, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(200), options)
    @Expect(scrollApproxEq(settled, 144.0))
}

@Test
func directOffsetWritesCancelRetainedWheelMotion(): Unit {
    let motion = ScrollMotion(0.0)
    let options = ScrollOptions.web()
    let _ = motion.wheel(0.0, -1.0, 1000.0, 200.0, options)
    let next = motion.advance(300.0, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(16), options)
    @Expect(next, 300.0)
    @Expect(!motion.active())
}

@Test
func smoothTargetsAreClampedWhenContentEnds(): Unit {
    let motion = ScrollMotion(760.0)
    let options = ScrollOptions.web(duration: UInt64(100), easing: Easing.Linear)
    let _ = motion.wheel(760.0, -1.0, 1000.0, 200.0, options)
    let settled = motion.advance(760.0, 1000.0, 200.0, MotionLevel.Standard, false, UInt64(100), options)
    @Expect(settled, 800.0)
}

@Test
func shrinkingContentClampsAndCancelsActiveMotion(): Unit {
    let motion = ScrollMotion(600.0)
    let options = ScrollOptions.web(duration: UInt64(220), easing: Easing.Linear)
    let _ = motion.wheel(600.0, -1.0, 1000.0, 200.0, options)
    @Expect(motion.active())

    let clamped = motion.advance(600.0, 500.0, 200.0, MotionLevel.Standard, false, UInt64(16), options)
    @Expect(clamped, 300.0)
    @Expect(!motion.active())
}

@Test
func nonPositiveWheelStepsFailClosed(): Unit {
    var rejected = false
    try {
        let _ = ScrollOptions.immediate(wheelStep: 0.0)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}
