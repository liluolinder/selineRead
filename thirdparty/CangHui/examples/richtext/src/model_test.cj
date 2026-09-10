package chui_richtext

@Test
func dataCoversEveryCategoryAndStaysWellFormed(): Unit {
    // 过滤标签 = 「全部」+ 各类别名；两个版本区块、类别下标全部合法。
    @Expect(FILTER_LABELS.size, CATEGORY_NAMES.size + 1)
    @Expect(RELEASES.size, 2)
    var covered = Array<Bool>(CATEGORY_NAMES.size, repeat: false)
    for (section in RELEASES) {
        @Expect(section.version.size > 0)
        @Expect(section.notes.size > 0)
        for (note in section.notes) {
            @Expect(note.category >= 0 && note.category < CATEGORY_NAMES.size)
            @Expect(note.subject.size > 0)
            @Expect(note.desc.size > 0)
            // 议题号要么为空、要么以 # 开头（链接文案约定）。
            if (!note.issue.isEmpty()) {
                @Expect(note.issue.startsWith("#"))
            }
            // 弃用条目必须同时给出旧写法与替代代码，迁移指引才完整。
            if (note.category == 3) {
                @Expect(!note.oldApi.isEmpty())
                @Expect(!note.code.isEmpty())
            }
            covered[note.category] = true
        }
    }
    for (flag in covered) {
        @Expect(flag)
    }
}

@Test
func categoryMappingsAreTotal(): Unit {
    @Expect(categoryName(0), "新增")
    @Expect(categoryName(3), "弃用")
    // 越界给兜底名而不崩溃。
    @Expect(categoryName(9), "其他")
    // 每个类别的主色与软底互不相同（视觉可区分）。
    for (i in 0..CATEGORY_NAMES.size) {
        for (j in (i + 1)..CATEGORY_NAMES.size) {
            @Expect(Int64(categoryColor(i).r) != Int64(categoryColor(j).r) ||
                Int64(categoryColor(i).g) != Int64(categoryColor(j).g))
        }
    }
}

@Test
func filterSelectsSingleCategory(): Unit {
    let model = RichTextModel()
    // 全部：条目总数 = 两区块之和。
    @Expect(model.visibleTotal(), 8)
    // 「修复」只在 2.3 区块出现两条。
    model.filter.value = 2
    @Expect(model.visibleNotes(model.sections[0]).size, 0)
    @Expect(model.visibleNotes(model.sections[1]).size, 2)
    @Expect(model.visibleTotal(), 2)
    // 「弃用」全库仅 2.4 的迁移条。
    model.filter.value = 4
    @Expect(model.visibleTotal(), 1)
    @Expect(model.visibleNotes(model.sections[0])[0].category, 3)
}

@Test
func matchesFilterMapsIndexes(): Unit {
    let note = ReleaseNote(2, "x", "y")
    @Expect(matchesFilter(note, 0))
    @Expect(matchesFilter(note, 3))
    @Expect(!matchesFilter(note, 1))
}

@Test
func openIssueCountsAndRemembers(): Unit {
    let model = RichTextModel()
    @Expect(model.openedCount.value, 0)
    @Expect(model.lastIssue.value.isEmpty())
    model.openIssue("#4821")
    model.openIssue("#4702")
    @Expect(model.openedCount.value, 2)
    @Expect(model.lastIssue.value, "#4702")
}

@Test
func noteSpansAssembleOptionalSegments(): Unit {
    // 全可选字段齐备：图标+空隙+标签+空隙+主题+描述（6）+旧写法三段+代码两段+尾句+链接两段 = 14。
    let full = ReleaseNote(3, "主题位置参数", "不再受支持", code: "Theme(bg: …)",
        tail: "详见迁移指引", oldApi: "Theme(bg, …)", issue: "#1")
    @Expect(noteSpans(full, {=> ()}).size, 14)
    // 最简条目只有六段基干。
    let bare = ReleaseNote(1, "修一处", "描述")
    @Expect(noteSpans(bare, {=> ()}).size, 6)
    // 仅带代码与链接的常规条目：6 + 代码两段 + 链接两段。
    let coded = ReleaseNote(0, "新能力", "描述", code: "Api", issue: "#2")
    @Expect(noteSpans(coded, {=> ()}).size, 10)
}
