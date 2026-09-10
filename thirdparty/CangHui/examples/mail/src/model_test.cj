package chui_mail

@Test
func inboxDataIsWellFormed(): Unit {
    @Expect(INBOX.size, 9)
    for (mail in INBOX) {
        @Expect(mail.sender.size > 0)
        @Expect(mail.subject.size > 0)
        @Expect(mail.paragraphs.size > 0)
    }
}

@Test
func initialSelectionMarksFirstRead(): Unit {
    let model = MailModel()
    // 默认选中第一封并随选中标为已读。
    @Expect(model.selectedId.value, INBOX[0].id)
    @Expect(!model.isUnread(INBOX[0].id))
    // 预置已读 3 封 + 选中 1 封，可见 9 封中未读 5 封。
    @Expect(model.visible().size, 9)
    @Expect(model.unreadCount(), 5)
}

@Test
func queryFiltersBySenderSubjectPreview(): Unit {
    let model = MailModel()
    // 命中发件人。
    model.query.value = "陈晓雯"
    @Expect(model.visible().size, 1)
    @Expect(model.visible()[0].id, 1)
    // 命中主题关键词。
    model.query.value = "构建"
    @Expect(model.visible().size, 1)
    @Expect(model.visible()[0].id, 2)
    // 无命中给空列表；清空恢复全量。
    model.query.value = "不存在的词"
    @Expect(model.visible().size, 0)
    model.query.value = ""
    @Expect(model.visible().size, 9)
}

@Test
func selectMarksReadAndUnreadRestores(): Unit {
    let model = MailModel()
    @Expect(model.isUnread(2))
    model.select(2)
    @Expect(!model.isUnread(2))
    // 标回未读保持选中。
    model.markSelectedUnread()
    @Expect(model.isUnread(2))
    @Expect(model.selectedId.value, 2)
}

@Test
func archiveRemovesAndAdvancesSelection(): Unit {
    let model = MailModel()
    // 归档选中的第一封：列表少一封，选中顺延到原位置的下一封（id 2）。
    model.archiveSelected()
    @Expect(model.visible().size, 8)
    @Expect(model.selectedId.value, 2)
    @Expect(model.selectedMail().getOrThrow().id, 2)
    // 归档后的邮件不再出现在可见集，也取不到详情。
    model.query.value = ""
    for (mail in model.visible()) {
        @Expect(mail.id != 1)
    }
}

@Test
func archiveLastVisibleFallsBackToPrevious(): Unit {
    let model = MailModel()
    // 过滤到只剩一封再归档：列表为空、选中清空。
    model.query.value = "行政"
    @Expect(model.visible().size, 1)
    model.select(9)
    model.archiveSelected()
    @Expect(model.visible().size, 0)
    @Expect(model.selectedId.value, -1)
    // 清空过滤后其余邮件仍在。
    model.query.value = ""
    @Expect(model.visible().size, 8)
}
