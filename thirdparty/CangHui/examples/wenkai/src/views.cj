/*
 * 样本册视图层：标题 + 字重切换 + 大字样张卡 + 字重对比卡 + 等宽代码卡 + 状态条。
 *
 * 样张卡整卡随切换器换字重（fontFamily 按名引用）；对比卡三行同文案各绑一个字重名，并排看粗细；
 * 等宽卡固定 wenkai-mono。字体缺失时同样的名字会整页回退系统字体，页面结构不变。
 */
package chui_wenkai

import chui.{CrossAxisAlignment, FontSizes, Label, LengthUnits, Panel, ScrollView, SegmentedControl, VStack}

func wenkaiView(model: WenkaiModel): Unit {
    VStack {
        header()
        SegmentedControl(weightLabels(), model.selected, key: "weights")
        ScrollView {
            VStack {
                specimenCard(model)
                weightCompareCard()
                monoCard()
            }.spacing(12.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("本地字体样本册").fontSize(FontSizes.TITLE).bold()
        Label("Fonts.register 从本地文件加载 CJK 字体（多字重各占一名），fontFamily 按名套用——楷体的笔意与系统黑体一望而知").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 大字样张：标题大字 + 词句 + 拉丁数字行，整卡随选中字重切换。
private func specimenCard(model: WenkaiModel): Unit {
    let family = model.family()
    Panel {
        VStack {
            Label(SPECIMEN_TITLE).fontFamily(family).fontSize(44.0).foregroundColor(INK_ACCENT)
            Label(SPECIMEN_POEM).fontFamily(family).fontSize(19.0).wrap()
            Label(SPECIMEN_LATIN).fontFamily(family).fontSize(14.0).muted()
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start)
    }.contentPadding(18.vp)
}

// 字重对比：三行同一句，各绑一个字重名，笔画粗细并排可辨。
private func weightCompareCard(): Unit {
    Panel {
        VStack {
            Label("字重对比").fontSize(FontSizes.CAPTION).muted()
            for (weight in WEIGHTS) {
                Label("春风得意马蹄疾 · ${weight.label}").fontFamily(weight.family).fontSize(18.0)
            }
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start)
    }.contentPadding(16.vp)
}

// 等宽变体：代码行与易混字形（0O 1lI）的区分度。
private func monoCard(): Unit {
    Panel {
        VStack {
            Label("等宽变体 ${MONO.label}").fontSize(FontSizes.CAPTION).muted()
            for (line in MONO_LINES) {
                Label(line).fontFamily(MONO.family).fontSize(14.0).wrap()
            }
        }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Start)
    }.contentPadding(16.vp)
}

private func statusBar(model: WenkaiModel): Unit {
    Panel {
        Label(model.statusText()).fontSize(FontSizes.CAPTION).wrap()
    }.contentPadding(12.vp)
}
