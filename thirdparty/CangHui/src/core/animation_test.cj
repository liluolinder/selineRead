package chui.core

import sdl.FrameInfo

private func animApproxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.001
}

/*
 * The spring eases toward its target across ticks and settles exactly onto it, so an idle
 * spring is free and a static first frame (target == start) never animates. A clamped
 * timestep keeps a long frame hitch from diverging.
 */
@Test
func springEasesTowardTargetAndSettles(): Unit {
    let spring = Spring(0.0)
    @Expect(spring.settled()) // starts at its target

    spring.target(1.0)
    @Expect(!spring.settled())

    var i = 0
    while (i < 400 && !spring.settled()) {
        spring.tick(UInt64(16))
        i += 1
    }
    @Expect(spring.settled())
    @Expect(spring.value, Float32(1.0))
    @Expect(i < 400) // converged well within the budget
}

@Test
func springRetargetsMidFlight(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.tick(UInt64(16))
    spring.tick(UInt64(16))
    let mid = spring.value
    @Expect(mid > Float32(0.0))
    @Expect(mid < Float32(1.0))

    spring.target(0.0)
    var i = 0
    while (i < 400 && !spring.settled()) {
        spring.tick(UInt64(16))
        i += 1
    }
    @Expect(spring.value, Float32(0.0))
}

@Test
func springResetSnapsWithoutAnimating(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.reset(0.5)
    @Expect(spring.settled())
    @Expect(spring.value, Float32(0.5))
}

// The draw-time convenience retargets and advances in one call, returning the new value; over
// enough frames it reaches the target and settles.
@Test
func springAnimateRetargetsAdvancesAndReturnsValue(): Unit {
    let spring = Spring(0.0)
    // A fresh spring starts settled; animate itself sets the target, so drive a fixed number of
    // frames rather than guarding on settled().
    let first = spring.animate(target: 1.0, deltaMs: UInt64(16))
    @Expect(first > Float32(0.0)) // moved off the start on the first frame
    @Expect(first < Float32(1.0))

    var v: Float32 = first
    for (_ in 0..400) {
        v = spring.animate(target: 1.0, deltaMs: UInt64(16))
    }
    @Expect(spring.settled())
    @Expect(v, Float32(1.0))
    @Expect(spring.value, Float32(1.0))
}

// animate(target, deltaMs) is exactly target(goal) + tick(delta) + read value — the same
// trajectory, just folded into one call.
@Test
func springAnimateMatchesTargetThenTick(): Unit {
    let viaAnimate = Spring(0.0)
    let viaSteps = Spring(0.0)
    var i = 0
    while (i < 30) {
        let a = viaAnimate.animate(target: 1.0, deltaMs: UInt64(16))
        viaSteps.target(1.0)
        viaSteps.tick(UInt64(16))
        @Expect(a, viaSteps.value)
        i += 1
    }
}

@Test
func springClampsHugeTimestepInsteadOfDiverging(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.tick(UInt64(100000)) // a 100-second hitch
    @Expect(spring.value >= Float32(0.0))
    @Expect(spring.value <= Float32(2.0)) // bounded: the clamp prevented a blow-up
}

// The ctx form keeps frames coming while the spring is in motion, so the dirty-frame loop (档 0) does
// not idle mid-transition and freeze a switch/radio/progress animation; a settled spring asks for
// nothing, so an idle control still costs no frames.
@Test
func springCtxAnimateRequestsFrameWhileMoving(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16)) // deltaMs = 16
    let spring = Spring(0.0)

    // Already at its target: no motion, no request.
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 0.0)
    @Expect(!ctx.takeFrameRequest())

    // Retargeted away: now moving, so it must ask for the next frame.
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 1.0)
    @Expect(!spring.settled())
    @Expect(ctx.takeFrameRequest())

    // Drive it to rest, then it stops asking.
    var i = 0
    while (i < 400 && !spring.settled()) {
        let _ = spring.animate(ctx, target: 1.0)
        i += 1
    }
    @Expect(spring.settled())
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 1.0)
    @Expect(!ctx.takeFrameRequest())
}

// The animator eases from where it is to the target over an exact duration, settling onto it. A fresh
// animator starts at its target, so a static first frame never animates.
@Test
func animatorEasesToTargetOverDurationAndSettles(): Unit {
    let anim = Animator(0.0, duration: 200, easing: Easing.Linear)
    @Expect(anim.settled()) // starts at its target

    anim.target(1.0)
    @Expect(!anim.settled())

    var i = 0
    while (i < 100 && !anim.settled()) {
        anim.tick(UInt64(16))
        i += 1
    }
    @Expect(anim.settled())
    @Expect(anim.value, Float32(1.0))
    // 200ms / 16ms ≈ 13 ticks; well under the guard.
    @Expect(i <= 14)
}

@Test
func animatorLinearMidpointIsHalf(): Unit {
    // Linear at half the duration is halfway to the target.
    let anim = Animator(0.0, duration: 100, easing: Easing.Linear)
    let v = anim.animate(target: 1.0, deltaMs: UInt64(50))
    @Expect(animApproxEq(v, 0.5))
    // Reaching the duration in one big step lands exactly on the target.
    let anim2 = Animator(0.0, duration: 100, easing: Easing.Linear)
    @Expect(anim2.animate(target: 1.0, deltaMs: UInt64(100)), Float32(1.0))
}

@Test
func animatorDelayHoldsValueThenEases(): Unit {
    // A 100ms delay before a 100ms linear ease: the whole timeline is 200ms.
    let anim = Animator(0.0, duration: 100, easing: Easing.Linear, delay: 100)
    // Inside the delay the value holds at the start, and the animator still counts as busy.
    @Expect(anim.animate(target: 1.0, deltaMs: UInt64(50)), Float32(0.0))
    @Expect(!anim.settled())
    // Just past the delay the ease begins: 50ms into a 100ms linear ease is halfway.
    @Expect(animApproxEq(anim.animate(target: 1.0, deltaMs: UInt64(100)), 0.5))
    @Expect(!anim.settled())
    // The tail of the timeline lands exactly on the target and settles.
    @Expect(anim.animate(target: 1.0, deltaMs: UInt64(50)), Float32(1.0))
    @Expect(anim.settled())
}

@Test
func animatorZeroDelayMatchesUndelayed(): Unit {
    // An explicit zero delay is the same timeline as no delay at all — the default path is unchanged.
    let plain = Animator(0.0, duration: 100, easing: Easing.Linear)
    let zero = Animator(0.0, duration: 100, easing: Easing.Linear, delay: 0)
    for (_ in 0..4) {
        let a = plain.animate(target: 1.0, deltaMs: UInt64(30))
        let b = zero.animate(target: 1.0, deltaMs: UInt64(30))
        @Expect(a, b)
        @Expect(plain.settled() == zero.settled())
    }
}

@Test
func animatorDelayRestartsOnRetarget(): Unit {
    // Each retarget serves the delay again, so a staggered group replays its cascade on every toggle.
    let anim = Animator(0.0, duration: 100, easing: Easing.Linear, delay: 100)
    @Expect(anim.animate(target: 1.0, deltaMs: UInt64(200)), Float32(1.0))
    @Expect(anim.settled())
    // Retargeting back holds at the new start for the delay before easing away.
    @Expect(anim.animate(target: 0.0, deltaMs: UInt64(50)), Float32(1.0))
    @Expect(!anim.settled())
    @Expect(animApproxEq(anim.animate(target: 0.0, deltaMs: UInt64(100)), 0.5))
}

@Test
func pulseAutoreverseBreathesOutAndBack(): Unit {
    // A linear autoreverse pulse sweeps 0 -> 1 over one period and reflects back over the next.
    let pulse = Pulse(period: 100, autoreverse: true, easing: Easing.Linear)
    @Expect(pulse.value, Float32(0.0))
    pulse.tick(UInt64(50))
    @Expect(animApproxEq(pulse.value, 0.5))
    pulse.tick(UInt64(50))
    @Expect(animApproxEq(pulse.value, 1.0)) // the peak of the breath
    pulse.tick(UInt64(50))
    @Expect(animApproxEq(pulse.value, 0.5)) // reflecting back down
    pulse.tick(UInt64(50))
    @Expect(animApproxEq(pulse.value, 0.0)) // full cycle wraps to the start
}

@Test
func pulseLoopSweepsAndWraps(): Unit {
    // A non-reversing pulse is a sawtooth: it sweeps to 1 then jumps back to 0.
    let pulse = Pulse(period: 100, autoreverse: false, easing: Easing.Linear)
    pulse.tick(UInt64(25))
    @Expect(animApproxEq(pulse.value, 0.25))
    pulse.tick(UInt64(100)) // a whole extra cycle lands at the same phase
    @Expect(animApproxEq(pulse.value, 0.25))
    // A huge stall wraps by whole cycles instead of accumulating (10.5 cycles ~ half a cycle).
    let stalled = Pulse(period: 100, autoreverse: false, easing: Easing.Linear)
    stalled.tick(UInt64(1050))
    @Expect(animApproxEq(stalled.value, 0.5))
}

@Test
func pulseNeverSettlesAndKeepsRequestingFrames(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let pulse = Pulse(period: 200)
    // Every animate step asks for the next frame — a pulse is perpetual by definition.
    let _ = ctx.takeFrameRequest()
    let first = pulse.animate(ctx)
    @Expect(ctx.takeFrameRequest())
    ctx.frame = FrameInfo(UInt64(32), UInt64(16)) // the next frame
    let second = pulse.animate(ctx)
    @Expect(ctx.takeFrameRequest())
    // And the value actually moves between frames.
    @Expect(second != first)
}

@Test
func pulseSharedAcrossWidgetsTicksOncePerFrame(): Unit {
    // A whole skeleton screen shares one Pulse and every row calls animate in its draw: only the
    // first call of a frame advances the clock, so sharing does not multiply the breathing speed.
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    let pulse = Pulse(period: 100, autoreverse: false, easing: Easing.Linear)
    let a = pulse.animate(ctx)
    let b = pulse.animate(ctx)
    let c = pulse.animate(ctx)
    @Expect(animApproxEq(a, 0.16))
    @Expect(b, a) // same frame: later callers read, not tick
    @Expect(c, a)
    ctx.frame = FrameInfo(UInt64(32), UInt64(16))
    @Expect(animApproxEq(pulse.animate(ctx), 0.32)) // next frame advances exactly one delta
}

@Test
func animatorEasingShapesTrajectory(): Unit {
    // EaseInQuad at the midpoint has moved 0.25 (0.5^2), not 0.5 — proving the curve is applied.
    let anim = Animator(0.0, duration: 100, easing: Easing.EaseInQuad)
    let v = anim.animate(target: 1.0, deltaMs: UInt64(50))
    @Expect(animApproxEq(v, 0.25))
}

@Test
func animatorRetargetsFromCurrentMidFlight(): Unit {
    let anim = Animator(0.0, duration: 100, easing: Easing.Linear)
    let mid = anim.animate(target: 1.0, deltaMs: UInt64(50)) // 0.5
    @Expect(animApproxEq(mid, 0.5))
    // Retarget to 0: eases from the current 0.5, not from 1.
    let back = anim.animate(target: 0.0, deltaMs: UInt64(50)) // 0.5 + (0-0.5)*0.5 = 0.25
    @Expect(animApproxEq(back, 0.25))
    var i = 0
    while (i < 100 && !anim.settled()) {
        let _ = anim.animate(target: 0.0, deltaMs: UInt64(16))
        i += 1
    }
    @Expect(anim.value, Float32(0.0))
}

@Test
func animatorResetSnapsWithoutAnimating(): Unit {
    let anim = Animator(0.0, duration: 100)
    anim.target(1.0)
    anim.reset(0.5)
    @Expect(anim.settled())
    @Expect(anim.value, Float32(0.5))
    @Expect(anim.goal, Float32(0.5))
}

// The ctx form keeps frames coming while in motion so the dirty-frame loop does not freeze the
// transition; a settled animator asks for nothing.
@Test
func animatorCtxAnimateRequestsFrameWhileMoving(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16)) // deltaMs = 16
    let anim = Animator(0.0, duration: 200, easing: Easing.EaseInOutQuad)

    // Already at its target: no motion, no request.
    let _ = ctx.takeFrameRequest()
    let _ = anim.animate(ctx, target: 0.0)
    @Expect(!ctx.takeFrameRequest())

    // Retargeted away: now moving, so it must ask for the next frame.
    let _ = ctx.takeFrameRequest()
    let _ = anim.animate(ctx, target: 1.0)
    @Expect(!anim.settled())
    @Expect(ctx.takeFrameRequest())

    // Drive it to rest, then it stops asking.
    var i = 0
    while (i < 100 && !anim.settled()) {
        let _ = anim.animate(ctx, target: 1.0)
        i += 1
    }
    @Expect(anim.settled())
    let _ = ctx.takeFrameRequest()
    let _ = anim.animate(ctx, target: 1.0)
    @Expect(!ctx.takeFrameRequest())
}

@Test
func animatorShorterSpecMidFlightCompletesAtGoal(): Unit {
    let ctx = testContext()
    let anim = Animator(0.0)
    let automatic = AnimationSpec.automatic(duration: UInt64(200), easing: Easing.Linear)

    ctx.theme = Theme.light(motionLevel: MotionLevel.Full)
    ctx.frame = FrameInfo(UInt64(200), UInt64(200))
    let partial = anim.animate(ctx, target: 1.0, spec: automatic)
    @Expect(partial > Float32(0.0))
    @Expect(partial < Float32(1.0))
    @Expect(!anim.settled())

    // A runtime motion-level change shortens the same automatic timeline below the elapsed time.
    // Completion must pin to the goal instead of becoming "settled" at the partial value.
    ctx.theme = Theme.light(motionLevel: MotionLevel.Basic)
    ctx.frame = FrameInfo(UInt64(216), UInt64(16))
    let _ = ctx.takeFrameRequest()
    let completed = anim.animate(ctx, target: 1.0, spec: automatic)
    @Expect(anim.settled())
    @Expect(completed, Float32(1.0))
    @Expect(anim.value, anim.goal)
    @Expect(!ctx.takeFrameRequest())
}
