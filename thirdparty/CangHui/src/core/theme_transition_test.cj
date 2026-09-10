package chui.core

@Test
func themeInterpolationKeepsExactEndpoints(): Unit {
    let light = Theme.light()
    let dark = Theme.dark()
    @Expect(light.lerp(dark, 0.0).bg.r, light.bg.r)
    @Expect(light.lerp(dark, 1.0).bg.r, dark.bg.r)
    @Expect(light.lerp(dark, 1.0).text.b, dark.text.b)
}

@Test
func themeTransitionAdvancesAndCompletesDeterministically(): Unit {
    let transition = ThemeTransition(Theme.dark(), Theme.light(), 40.0, 40.0, durationMs: UInt64(100))
    let halfway = transition.advance(UInt64(50))
    @Expect(transition.progress(), Float32(0.5))
    @Expect(!transition.isComplete())
    @Expect(halfway.bg.r > Theme.dark().bg.r)

    let complete = transition.advance(UInt64(80))
    @Expect(transition.isComplete())
    @Expect(complete.bg.r, Theme.light().bg.r)
}

@Test
func themeTransitionRevealRadiusStartsAtOriginAndCoversFarthestCorner(): Unit {
    let transition = ThemeTransition(Theme.dark(), Theme.light(), 10.0, 20.0, durationMs: UInt64(100))
    @Expect(transition.revealRadius(100.0, 80.0), Float32(0.0))

    let _ = transition.advance(UInt64(100))
    let radius = transition.revealRadius(100.0, 80.0)
    @Expect(radius > Float32(110.0))
    @Expect(radius < Float32(111.0))
}
