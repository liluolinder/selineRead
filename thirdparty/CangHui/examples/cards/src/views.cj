/*
 * 样式卡片视图层：标题 + 居中预览卡片 + 控件（阴影层级/圆角 Stepper、边框 Switch）+ elevation 阶梯参考。
 *
 * 预览卡片始终链式套 background/shadow/border 三个修饰符；关闭阴影或边框时以透明色传入（自然不绘制），
 * 从而避免条件包装。阶梯参考固定展示各 elevation 预设的阴影，作对照。
 */
package chui_cards

import chui.{Color, CrossAxisAlignment, Divider, FlowRow, FontSizes, HStack, Label, LengthUnits, Shadow, Spacer,
    Stepper, Switch, VStack}

func cardsView(model: CardsModel): Unit {
    VStack {
        header()
        HStack {
            Spacer()
            previewCard(model)
            Spacer()
        }.hug()
        controls(model)
        Divider()
        rampSection()
    }.spacing(18.vp).padding(22.vp)
}

private func header(): Unit {
    VStack {
        Label("样式卡片").fontSize(FontSizes.TITLE).bold()
        Label("shadow（软阴影 + elevation 预设）· background（圆角填充）· border（圆角描边），实时调整").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 预览卡片：三个样式修饰符恒链式套用；关闭时传透明色，自然不绘制。
private func previewCard(model: CardsModel): Unit {
    let elev = model.elevation.value
    let r = Float32(model.radius.value)
    let shadowColor = if (elev > 0) {
        CARD_SHADOW
    } else {
        Color.rgba(0, 0, 0, 0)
    }
    let borderColor = if (model.borderOn.value) {
        CARD_BORDER
    } else {
        Color.rgba(0, 0, 0, 0)
    }
    let level = if (elev > 0) {
        elev
    } else {
        1
    }
    VStack {
        Label("样式预览").fontSize(FontSizes.TITLE).bold()
        Label("阴影 · 圆角 · 边框").muted().fontSize(FontSizes.CAPTION)
    }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug().padding(32.vp).background(CARD_FILL, r)
        .shadow(Shadow.elevation(level, color: shadowColor), radius: r)
        .border(borderColor, width: 1.5, radius: r)
}

private func controls(model: CardsModel): Unit {
    VStack {
        controlRow("阴影层级 elevation = ${model.elevation.value}") {
            => Stepper(model.elevation, key: "elev", lower: 0, upper: 6)
        }
        controlRow("圆角 radius = ${model.radius.value}vp") {
            => Stepper(model.radius, key: "radius", lower: 0, upper: 28, step: 2)
        }
        HStack {
            Switch("边框 border", model.borderOn)
            Spacer()
        }.hug()
        Label(model.describe()).muted().fontSize(FontSizes.CAPTION)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func controlRow(label: String, control: () -> Unit): Unit {
    HStack {
        Label(label).width(190.vp)
        control()
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func rampSection(): Unit {
    VStack {
        Label("elevation 阶梯参考（层级越高，阴影越大越柔）").muted().fontSize(FontSizes.CAPTION)
        FlowRow {
            for (level in RAMP_LEVELS) {
                rampCard(level)
            }
        }.spacing(14.vp, 14.vp)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func rampCard(level: Int64): Unit {
    VStack {
        Label("e${level}").fontSize(FontSizes.CAPTION)
    }.crossAxisAlignment(CrossAxisAlignment.Center).width(74.vp).height(50.vp).background(CARD_FILL, 10.0)
        .shadow(Shadow.elevation(level, color: CARD_SHADOW), radius: 10.0)
}
