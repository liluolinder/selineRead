/*
 * 渐变视图层：标题 + 大预览（选中预设 + 方向）+ 控件（预设 Stepper、方向 Switch）+ 全部预设样本墙。
 *
 * 预览与控件都由模型现算；点 Stepper 换预设、切 Switch 换方向，大预览实时更新。样本墙固定展示各预设的纵向渐变。
 */
package chui_gradients

import chui.{Color, CrossAxisAlignment, FlowRow, FontSizes, Gradient, HStack, Label, LengthUnits, ScrollView, Spacer,
    Stepper, Switch, VStack}

private let ON_GRADIENT = Color.rgb(255, 255, 255)
private let ON_GRADIENT_SOFT = Color.rgba(255, 255, 255, 210)

func gradientsView(model: GradientsModel): Unit {
    ScrollView {
        VStack {
            header()
            preview(model)
            controls(model)
            gallery(model)
        }.spacing(16.vp).padding(20.vp)
    }
}

private func header(): Unit {
    VStack {
        Label("线性渐变").fontSize(FontSizes.TITLE).bold()
        Label("gradientBackground(Gradient)：两色线性渐变填充圆角背景，可纵向或横向，复用实填缓存网格逐顶点着色").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 大预览：选中预设 + 方向的渐变填充，名称与方向叠在其上（白字）。
private func preview(model: GradientsModel): Unit {
    VStack {
        Spacer()
        Label(model.current().name).fontSize(FontSizes.DISPLAY).bold().foregroundColor(ON_GRADIENT)
        Label(model.directionText()).fontSize(FontSizes.CAPTION).foregroundColor(ON_GRADIENT_SOFT)
        Spacer()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Center).fillWidth().height(160.vp)
        .gradientBackground(model.gradient(), 16.0)
}

private func controls(model: GradientsModel): Unit {
    VStack {
        HStack {
            Label("预设  ${model.current().name}").width(180.vp)
            Stepper(model.selected, key: "preset", lower: 0, upper: PRESETS.size - 1)
            Spacer()
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        HStack {
            Switch("纵向渐变（关闭则横向）", model.vertical)
            Spacer()
        }.hug()
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 全部预设的纵向渐变样本墙。
private func gallery(model: GradientsModel): Unit {
    VStack {
        Label("全部预设（纵向）").muted().fontSize(FontSizes.CAPTION)
        FlowRow {
            for (i in 0..model.presets.size) {
                swatch(model.presets[i])
            }
        }.spacing(12.vp, 12.vp)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func swatch(preset: GradientPreset): Unit {
    VStack {
        VStack {}.width(94.vp).height(54.vp).gradientBackground(
            Gradient(start: preset.start, end: preset.end),
            10.0
        )
        Label(preset.name).muted().fontSize(FontSizes.CAPTION)
    }.spacing(5.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
