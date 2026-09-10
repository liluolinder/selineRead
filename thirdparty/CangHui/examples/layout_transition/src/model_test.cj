package chui_layout_transition

@Test
func layoutTransitionModelReordersStableKeys(): Unit {
    let model = LayoutTransitionModel()
    @Expect(model.items()[0], "crew")
    @Expect(model.items()[5], "signal")
    model.reorder()
    @Expect(model.items()[0], "signal")
    @Expect(model.items()[5], "crew")
}

@Test
func layoutTransitionModelTogglesResponsiveColumns(): Unit {
    let model = LayoutTransitionModel()
    @Expect(model.columns.value, Int64(3))
    model.toggleColumns()
    @Expect(model.columns.value, Int64(2))
    @Expect(model.layoutText().contains("2 columns"))
    model.toggleColumns()
    @Expect(model.columns.value, Int64(3))
}
