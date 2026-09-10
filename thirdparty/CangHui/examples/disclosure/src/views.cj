/*
 * 折叠问答视图层：标题行（计数摘要 + 全部展开/收起）+ 问答卡片列表。
 *
 * 每张卡片 = FaqRow 自绘标题行 + Reveal 包裹的答案区。答案左缩进与问题文本对齐；
 * 点行或 Enter/空格切换，Reveal 缓动高度、其下卡片平滑让位。
 */
package chui_disclosure

import chui.{Button, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, Reveal, ScrollView,
    Spacer, VStack}

func disclosureView(model: DisclosureModel): Unit {
    VStack {
        header(model)
        ScrollView {
            VStack {
                for (i in 0..model.items.size) {
                    faqItem(model, i)
                }
            }.spacing(10.vp)
        }.flex()
    }.spacing(14.vp).padding(20.vp)
}

private func header(model: DisclosureModel): Unit {
    HStack {
        VStack {
            Label("常见问题").fontSize(FontSizes.TITLE).bold()
            Label("${model.items.size} 个问题 · 已展开 ${model.openCount()}").muted().fontSize(FontSizes.CAPTION)
        }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        Spacer()
        Button(model.expandLabel(), {=> model.toggleAll()})
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func faqItem(model: DisclosureModel, index: Int64): Unit {
    let item = model.items[index]
    let open = model.isOpen(index)
    Panel {
        VStack {
            FaqRow(index, item.question, open, {=> model.toggle(index)})
            Reveal(shown: open, key: "faq-${index}") {
                VStack {
                    Label(item.answer).muted().fontSize(FontSizes.BODY).wrap()
                }.crossAxisAlignment(CrossAxisAlignment.Start).padding(40.vp, 0.vp, 16.vp, 12.vp)
            }
        }.crossAxisAlignment(CrossAxisAlignment.Stretch).hug()
    }.contentPadding(6.vp)
}
