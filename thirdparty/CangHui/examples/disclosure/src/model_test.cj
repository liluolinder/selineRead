package chui_disclosure

@Test
func faqCoversFrameworkTopics(): Unit {
    @Expect(FAQ.size, 6)
    // 每条都有非空的问题与答案。
    for (item in FAQ) {
        @Expect(item.question.size > 0)
        @Expect(item.answer.size > 0)
    }
}

@Test
func modelStartsWithFirstOpen(): Unit {
    let model = DisclosureModel()
    @Expect(model.isOpen(0))
    @Expect(!model.isOpen(1))
    @Expect(model.openCount(), 1)
    @Expect(!model.allOpen())
}

@Test
func toggleOpensAndClosesIndependently(): Unit {
    let model = DisclosureModel()
    // 展开第三条——第一条保持展开（允许多条同时展开）。
    model.toggle(2)
    @Expect(model.isOpen(0))
    @Expect(model.isOpen(2))
    @Expect(model.openCount(), 2)
    // 再切一次只收起这一条。
    model.toggle(2)
    @Expect(!model.isOpen(2))
    @Expect(model.isOpen(0))
    // 收起第一条后没有展开项。
    model.toggle(0)
    @Expect(model.openCount(), 0)
}

@Test
func toggleAllExpandsThenCollapses(): Unit {
    let model = DisclosureModel()
    // 未全开时展开全部，文案随之切换。
    @Expect(model.expandLabel(), "全部展开")
    model.toggleAll()
    @Expect(model.allOpen())
    @Expect(model.openCount(), model.items.size)
    @Expect(model.expandLabel(), "全部收起")
    // 已全开时清空。
    model.toggleAll()
    @Expect(model.openCount(), 0)
    @Expect(!model.allOpen())
}
