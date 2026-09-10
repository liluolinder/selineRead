package chui_gradients

@Test
func clampPresetKeepsIndexInRange(): Unit {
    @Expect(clampPreset(-3), 0)
    @Expect(clampPreset(0), 0)
    @Expect(clampPreset(PRESETS.size - 1), PRESETS.size - 1)
    @Expect(clampPreset(PRESETS.size + 5), PRESETS.size - 1)
}

@Test
func gradientForComposesPresetAndDirection(): Unit {
    let preset = PRESETS[1]
    let g = gradientFor(1, true)
    @Expect(g.vertical)
    @Expect(Int64(g.start.r), Int64(preset.start.r))
    @Expect(Int64(g.end.r), Int64(preset.end.r))
    // Horizontal keeps the same stops but flips the axis.
    @Expect(!gradientFor(1, false).vertical)
    // Out-of-range index clamps rather than crashing.
    @Expect(Int64(gradientFor(99, true).start.r), Int64(PRESETS[PRESETS.size - 1].start.r))
}

@Test
func directionLabelReflectsAxis(): Unit {
    @Expect(directionLabel(true), "纵向（顶 → 底）")
    @Expect(directionLabel(false), "横向（左 → 右）")
}

@Test
func presetsAreDistinctAndNamed(): Unit {
    @Expect(PRESETS.size, 6)
    for (preset in PRESETS) {
        @Expect(preset.name.size > 0)
        // A gradient with two different stops (start ≠ end on at least one channel).
        @Expect(!(preset.start.r == preset.end.r && preset.start.g == preset.end.g && preset.start.b == preset.end.b))
    }
}

@Test
func modelDerivesCurrentAndGradient(): Unit {
    let model = GradientsModel()
    @Expect(model.current().name, "Dusk")
    @Expect(model.gradient().vertical)
    model.selected.value = 2
    model.vertical.value = false
    @Expect(model.current().name, "Ocean")
    @Expect(!model.gradient().vertical)
}
