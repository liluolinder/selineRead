package chui_cards

@Test
func describeStyleReflectsSettings(): Unit {
    @Expect(describeStyle(3, 14, true), "elevation 3 · 圆角 14vp · 边框开")
    @Expect(describeStyle(0, 8, false), "无阴影 · 圆角 8vp · 边框关")
    // Elevation 0 reads as no shadow regardless of the border/radius.
    @Expect(describeStyle(0, 0, true), "无阴影 · 圆角 0vp · 边框开")
}

@Test
func rampCoversAscendingLevels(): Unit {
    @Expect(RAMP_LEVELS.size, 6)
    @Expect(RAMP_LEVELS[0], 1)
    @Expect(RAMP_LEVELS[RAMP_LEVELS.size - 1], 6)
    // Strictly ascending.
    for (i in 1..RAMP_LEVELS.size) {
        @Expect(RAMP_LEVELS[i] > RAMP_LEVELS[i - 1])
    }
}

@Test
func modelDefaultsAndDescribe(): Unit {
    let model = CardsModel()
    @Expect(model.elevation.value, 3)
    @Expect(model.radius.value, 14)
    @Expect(model.borderOn.value)
    @Expect(model.describe(), "elevation 3 · 圆角 14vp · 边框开")
    // Adjusting settings flows into the description.
    model.elevation.value = 0
    model.borderOn.value = false
    @Expect(model.describe(), "无阴影 · 圆角 14vp · 边框关")
}
