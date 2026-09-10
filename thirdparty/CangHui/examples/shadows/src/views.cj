/*
 * 阴影对比视图层：标题 + 层级调节 + 单层/双层并排对比 + 双层阶梯 + 状态条。
 *
 * 对比区两张完全相同的卡片，左边套单层 elevation、右边套 keyAmbient 双层，同层级下直接对照；
 * 阶梯区一排双层 e1..e6。阴影修饰符链在 background 之后、传同一圆角。
 */
package chui_shadows

import chui.{CrossAxisAlignment, FontSizes, Grid, HStack, Label, LengthUnits, Panel, Shadow, Spacer, Stepper, VStack,
    Widget}

func shadowsView(model: ShadowsModel): Unit {
    VStack {
        header()
        controls(model)
        compareRow(model)
        ladder()
        Spacer()
        statusBar(model)
    }.spacing(14.vp).padding(22.vp)
}

private func header(): Unit {
    VStack {
        Label("多重阴影").fontSize(FontSizes.TITLE).bold()
        Label("shadow(layers) 按序叠绘多层投影；Shadow.keyAmbient 给出 Material 式「环境光 + 方向光」双层，与单层同级对照").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func controls(model: ShadowsModel): Unit {
    HStack {
        Label("层级 e${model.current()}").fontSize(FontSizes.BODY)
        Stepper(model.level, lower: 1, upper: 6)
        Spacer()
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// 两张相同的卡片：左单层、右双层，同一层级并排对照（阴影半径与 Panel 圆角同为主题 12）。
private func compareRow(model: ShadowsModel): Unit {
    let level = model.current()
    Grid(2) {
        sampleCard("单层 elevation", "一团均匀的晕").shadow(Shadow.elevation(level), radius: 12.0)
        sampleCard("双层 keyAmbient", "环境光 + 方向光").shadow(Shadow.keyAmbient(level), radius: 12.0)
    }.spacing(24.vp, 14.vp)
}

private func sampleCard(title: String, note: String): Widget {
    Panel {
        VStack {
            Label(title).fontSize(FontSizes.BODY).bold()
            Label(note).muted().fontSize(FontSizes.CAPTION)
        }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(18.vp, 16.vp)
}

// 双层阶梯：e1..e6 逐级加深。
private func ladder(): Unit {
    VStack {
        Label("双层阶梯 e1 – e6").fontSize(FontSizes.CAPTION).muted()
        HStack {
            for (level in 1..7) {
                Label("e${level}").fontSize(FontSizes.CAPTION).padding(16.vp, 18.vp)
                    .background(CARD_BG, 10.0)
                    .shadow(Shadow.keyAmbient(level), radius: 10.0)
            }
        }.spacing(18.vp).hug().padding(4.vp, 12.vp)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func statusBar(model: ShadowsModel): Unit {
    Label(model.statusText()).muted().fontSize(FontSizes.CAPTION).wrap()
}
