/*
 * 逐角圆角视图层：标题 + 圆角/尾角调节 + 气泡会话 + 底部输入条。
 *
 * 每个气泡是一个 Label 套 `.background(色, corners: 四角)`——四角来自 model.cornersFor，故调 Stepper 即刻改形。
 * 底部输入条用 `Corners.top(16)`：只圆上面两角，像自屏幕底部升起的抽屉。
 */
package chui_corners

import chui.{Button, ButtonRole, Corners, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, ScrollView,
    Spacer, Stepper, TextField, VStack}

func cornersView(model: CornersModel): Unit {
    VStack {
        header()
        controls(model)
        ScrollView {
            VStack {
                for (message in model.messages.value) {
                    bubbleRow(model, message)
                }
            }.spacing(8.vp)
        }.flex()
        composeBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("逐角圆角").fontSize(FontSizes.TITLE).bold()
        Label("气泡四角各自取半径：整体圆润，唯独发送者一侧的下角收成小尾角。调下方 Stepper 实时改形").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 圆角与尾角调节：改动即刻反映到每个气泡。
private func controls(model: CornersModel): Unit {
    HStack {
        Label("圆角 ${model.radius.value}").fontSize(FontSizes.CAPTION).muted()
        Stepper(model.radius, lower: 0, upper: 24, step: 2)
        Spacer()
        Label("尾角 ${model.tail.value}").fontSize(FontSizes.CAPTION).muted()
        Stepper(model.tail, lower: 0, upper: 24, step: 2)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// 我方消息靠右、对方靠左；两侧各用一个 Spacer 顶开。
private func bubbleRow(model: CornersModel, message: Message): Unit {
    HStack {
        if (message.fromMe) {
            Spacer()
        }
        bubble(model, message)
        if (!message.fromMe) {
            Spacer()
        }
    }.hug()
}

private func bubble(model: CornersModel, message: Message): Unit {
    let bg = if (message.fromMe) {
        MINE_BG
    } else {
        OTHER_BG
    }
    let fg = if (message.fromMe) {
        MINE_TEXT
    } else {
        OTHER_TEXT
    }
    Label(message.text).wrap().foregroundColor(fg).fontSize(FontSizes.BODY)
        .padding(12.vp, 9.vp)
        .background(bg, corners: model.cornersFor(message))
        .maxWidth(340.vp)
}

// 输入条：只圆上面两角（Corners.top），像自底部升起的抽屉。
private func composeBar(model: CornersModel): Unit {
    HStack {
        TextField(model.draft).flex()
        Button("发送", {=> model.send()}).role(ButtonRole.Primary)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug().padding(14.vp, 10.vp)
        .background(BAR_BG, corners: Corners.top(16.0))
}
