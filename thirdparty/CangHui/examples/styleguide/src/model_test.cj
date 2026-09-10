package chui_styleguide

@Test
func spacingStepsAreOrdered(): Unit {
    @Expect(SPACING_STEPS.size, 6)
    @Expect(SPACING_STEPS[0].name, "xs")
    // Strictly ascending lengths.
    for (i in 1..SPACING_STEPS.size) {
        @Expect(SPACING_STEPS[i].length.value > SPACING_STEPS[i - 1].length.value)
    }
}

@Test
func radiusAndTypeStepsAscend(): Unit {
    for (i in 1..RADIUS_STEPS.size) {
        @Expect(RADIUS_STEPS[i].radius > RADIUS_STEPS[i - 1].radius)
    }
    for (i in 1..TYPE_STEPS.size) {
        @Expect(TYPE_STEPS[i].size > TYPE_STEPS[i - 1].size)
    }
    // The largest radius (pill) rounds fully.
    @Expect(RADIUS_STEPS[RADIUS_STEPS.size - 1].name, "pill")
}

@Test
func formatMsAndBarWidth(): Unit {
    @Expect(formatMs(220), "220ms")
    @Expect(formatMs(120), "120ms")
    // A longer duration yields a wider indicator bar.
    @Expect(msBarWidth(360).value > msBarWidth(120).value)
    @Expect(MOTION_STEPS.size, 3)
    @Expect(ELEVATION_LEVELS.size, 4)
}
