package chui_links

@Test
func noticesCarryLinks(): Unit {
    @Expect(NOTICES.size, 5)
    // Every notice has at least one clickable link segment.
    for (notice in NOTICES) {
        var links = 0
        for (segment in notice.segments) {
            if (segment.isLink) {
                links += 1
            }
        }
        @Expect(links > 0)
    }
    // The total link count is positive and matched by the helper.
    @Expect(linkCount(NOTICES) > 5)
}

@Test
func segmentDefaultsToNonLink(): Unit {
    @Expect(!Segment("hi").isLink)
    @Expect(Segment("Ada", isLink: true).isLink)
}

@Test
func modelSelectUpdatesDetail(): Unit {
    let model = LinksModel()
    // Starts with the hint, no selection.
    @Expect(model.selected.value.isNone())
    @Expect(model.detailText().size > 0)
    // Selecting a link records it and shows it in the detail text.
    model.select("report.md")
    @Expect(model.selected.value.getOrThrow(), "report.md")
    @Expect(model.detailText(), "已选择：report.md")
}
