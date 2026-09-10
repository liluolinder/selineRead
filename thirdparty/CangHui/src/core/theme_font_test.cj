package chui.core

@Test
func themeFontFamilySurvivesMotionAndTransitions(): Unit {
    let branded = Theme.light().withFontFamily(Some("brand"))
    @Expect(branded.fontFamily.getOrThrow(), "brand")
    @Expect(branded.withMotionLevel(MotionLevel.Full).fontFamily.getOrThrow(), "brand")

    let target = Theme.dark().withFontFamily(Some("night"))
    @Expect(branded.lerp(target, 0.25).fontFamily.getOrThrow(), "brand")
    @Expect(branded.lerp(target, 0.75).fontFamily.getOrThrow(), "night")
}
