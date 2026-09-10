/*
 * 交错入场视图层：标题 + 档位/开关 + 逐行错开入场的卡片列表 + 状态条。
 *
 * 每行裹一个 Reveal，只是把 delay 设成 model.delayFor(i)（= 行号 × 步进），于是整组变成依次展开的瀑布。
 * key 里带上步进：Reveal 的时序在其 Animator 首次创建时读取，换档需要新身份才能生效（新 Animator 以当前
 * 展开态创建，故换档本身不闪动，再按开关即可用新节奏重播）。
 */
package chui_stagger

import chui.{Button, ButtonRole, CrossAxisAlignment, Easing, FontSizes, HStack, Icon, Label, LengthUnits, Panel,
    Reveal, ScrollView, SegmentedControl, Spacer, VStack}

func staggerView(model: StaggerModel): Unit {
    VStack {
        header()
        controls(model)
        ScrollView {
            VStack {
                for (i in 0..model.items.size) {
                    Reveal(
                        shown: model.shown.value,
                        key: "row-${i}-${model.step()}",
                        duration: UInt64(REVEAL_MS),
                        easing: Easing.EaseOutCubic,
                        delay: model.delayFor(i)
                    ) {
                        itemCard(model, i)
                    }
                }
            }.spacing(8.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("交错入场").fontSize(FontSizes.TITLE).bold()
        Label("每行的入场只比上一行多等一点点（行号 × 步进），整组便成了依次落位的瀑布，而不是一起弹出").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func controls(model: StaggerModel): Unit {
    HStack {
        SegmentedControl(STEP_NAMES, model.stepIndex, key: "steps")
        Spacer()
        Button(toggleLabel(model), {=> model.toggle()}).role(ButtonRole.Primary)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func toggleLabel(model: StaggerModel): String {
    if (model.shown.value) {
        "收起"
    } else {
        "入场"
    }
}

// 一行卡片：图标 + 标题/说明，右侧标出这一行等了多久（把交错的数学摆到明面上）。
private func itemCard(model: StaggerModel, index: Int64): Unit {
    let item = model.items[index]
    Panel {
        HStack {
            Icon(item.icon).foregroundColor(item.iconColor).iconSize(18.vp)
            VStack {
                Label(item.title).fontSize(FontSizes.BODY)
                Label(item.detail).muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
            Spacer()
            Label("+${model.delayFor(index)}ms").muted().fontSize(FontSizes.CAPTION)
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(12.vp)
}

private func statusBar(model: StaggerModel): Unit {
    Panel {
        Label(model.statusText()).fontSize(FontSizes.BODY)
    }.contentPadding(14.vp)
}
