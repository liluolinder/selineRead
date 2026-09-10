package chui_dashed

@Test
func describeDashFormatsSettings(): Unit {
    @Expect(describeDash(7, 5, 14), "实线 7 · 间隔 5 · 圆角 14vp")
    @Expect(describeDash(6, 4, 0), "实线 6 · 间隔 4 · 圆角 0vp")
}

@Test
func modelDefaultsAndDescribe(): Unit {
    let model = DashedModel()
    @Expect(model.dash.value, 7)
    @Expect(model.gap.value, 5)
    @Expect(model.radius.value, 14)
    @Expect(model.describe(), "实线 7 · 间隔 5 · 圆角 14vp")
    // Adjusting settings flows into the description.
    model.dash.value = 10
    model.radius.value = 0
    @Expect(model.describe(), "实线 10 · 间隔 5 · 圆角 0vp")
}
