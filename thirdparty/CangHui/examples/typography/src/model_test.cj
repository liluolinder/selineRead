package chui_typography

import chui.FontStyle

@Test
func composeStyleMapsFlags(): Unit {
    let s = composeStyle(true, false, true, false)
    @Expect(s.bold)
    @Expect(!s.italic)
    @Expect(s.underline)
    @Expect(!s.strikethrough)
    // All off is the regular style.
    @Expect(composeStyle(false, false, false, false) == FontStyle.regular)
    // All on packs every flag.
    @Expect(composeStyle(true, true, true, true).ttfFlags(), 0x0F)
}

@Test
func styleSummaryJoinsActiveStyles(): Unit {
    @Expect(styleSummary(FontStyle.regular), "常规")
    @Expect(styleSummary(FontStyle(bold: true)), "粗体")
    @Expect(styleSummary(FontStyle(bold: true, italic: true)), "粗体 · 斜体")
    @Expect(
        styleSummary(FontStyle(bold: true, italic: true, underline: true, strikethrough: true)),
        "粗体 · 斜体 · 下划线 · 删除线"
    )
}

@Test
func stepCaptionFormatsNameAndSize(): Unit {
    @Expect(stepCaption(TypeStep("Body", 15.0)), "Body · 15fp")
    @Expect(stepCaption(TypeStep("Display", 32.0)), "Display · 32fp")
    // The shipped scale runs largest to smallest.
    @Expect(TYPE_SCALE[0].size > TYPE_SCALE[TYPE_SCALE.size - 1].size)
}

@Test
func modelToggleDrivesStyleAndSummary(): Unit {
    let model = TypographyModel()
    // Ships with bold on, everything else off.
    @Expect(model.style().bold)
    @Expect(model.summary(), "粗体")
    // Toggling flows through to the derived style and summary.
    model.italic.value = true
    model.bold.value = false
    @Expect(!model.style().bold)
    @Expect(model.style().italic)
    @Expect(model.summary(), "斜体")
}

@Test
func styleReferenceCoversEachStyle(): Unit {
    // The reference card demonstrates regular plus each single style and one combination.
    @Expect(STYLE_REFERENCE.size, 6)
    @Expect(STYLE_REFERENCE[0].style == FontStyle.regular)
    @Expect(STYLE_REFERENCE[1].style.bold)
    @Expect(STYLE_REFERENCE[2].style.italic)
    @Expect(STYLE_REFERENCE[3].style.underline)
    @Expect(STYLE_REFERENCE[4].style.strikethrough)
}
