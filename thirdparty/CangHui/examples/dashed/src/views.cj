/*
 * 虚线边框视图层：标题 + 可调预览框 + 控件（实线/间隔/圆角 Stepper）+ 常见用法（拖放区、占位卡）。
 *
 * 预览框用当前 dash/gap/radius 画虚线边框；拖放区与占位卡是固定用法示例。
 */
package chui_dashed

import chui.{CrossAxisAlignment, FlowRow, FontSizes, HStack, Label, LengthUnits, ScrollView, Spacer, Stepper, VStack}

func dashedView(model: DashedModel): Unit {
    ScrollView {
        VStack {
            header()
            preview(model)
            controls(model)
            examples()
        }.spacing(16.vp).padding(20.vp)
    }
}

private func header(): Unit {
    VStack {
        Label("虚线边框").fontSize(FontSizes.TITLE).bold()
        Label("dashedBorder：沿圆角矩形周边等距行进画虚线，转角处仍均匀；实线段/间隔/圆角/线宽可配").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 预览框：当前参数的虚线边框，居中显示参数描述。
private func preview(model: DashedModel): Unit {
    let dash = Float32(model.dash.value)
    let gap = Float32(model.gap.value)
    let radius = Float32(model.radius.value)
    VStack {
        Spacer()
        Label(model.describe()).fontSize(FontSizes.BODY)
        Spacer()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Center).fillWidth().height(130.vp)
        .dashedBorder(DASH_ACCENT, width: 1.5, radius: radius, dash: dash, gap: gap)
}

private func controls(model: DashedModel): Unit {
    VStack {
        controlRow("实线段 dash = ${model.dash.value}") {
            => Stepper(model.dash, key: "dash", lower: 1, upper: 16)
        }
        controlRow("间隔 gap = ${model.gap.value}") {
            => Stepper(model.gap, key: "gap", lower: 1, upper: 16)
        }
        controlRow("圆角 radius = ${model.radius.value}vp") {
            => Stepper(model.radius, key: "radius", lower: 0, upper: 28, step: 2)
        }
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func controlRow(label: String, control: () -> Unit): Unit {
    HStack {
        Label(label).width(180.vp)
        control()
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// 常见用法：拖放区 + 一排占位卡。
private func examples(): Unit {
    VStack {
        Label("常见用法").muted().fontSize(FontSizes.CAPTION)
        VStack {
            Spacer()
            Label("拖放文件到此，或点击选择").muted().fontSize(FontSizes.BODY)
            Spacer()
        }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Center).fillWidth().height(96.vp).dashedBorder(
            DASH_MUTED,
            width: 1.5,
            radius: 14.0,
            dash: 9.0,
            gap: 6.0
        )
        FlowRow {
            for (_ in 0..4) {
                VStack {
                    Label("+").muted().fontSize(FontSizes.TITLE)
                }.crossAxisAlignment(CrossAxisAlignment.Center).width(92.vp).height(64.vp).dashedBorder(
                    DASH_MUTED,
                    radius: 10.0
                )
            }
        }.spacing(12.vp, 12.vp)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}
