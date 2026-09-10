/*
 * 样式指南视图层：滚动页，逐节展示设计令牌尺度（间距/圆角/高度/字号/动效）。
 *
 * 页面自身用这些令牌排版（`Spacing` 作间距/内边距、`Radii` 作圆角、`Shadow.elevation` 作卡片高度），既是参考也是范例。
 */
package chui_styleguide

import chui.{CrossAxisAlignment, FlowRow, FontSizes, HStack, Label, Panel, Radii, ScrollView, Shadow, Spacer, Spacing,
    VStack}

func styleguideView(): Unit {
    ScrollView {
        VStack {
            header()
            spacingSection()
            radiiSection()
            elevationSection()
            typeSection()
            motionSection()
        }.spacing(Spacing.lg).padding(Spacing.xl)
    }
}

private func header(): Unit {
    VStack {
        Label("设计令牌").fontSize(FontSizes.TITLE).bold()
        Label("Spacing / Radii / Motion 尺度，与既有的字号、高度预设一起构成设计系统；本页也用这些令牌排版").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(Spacing.xs).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func sectionHeader(title: String): Unit {
    Label(title).fontSize(FontSizes.BODY).bold()
}

private func spacingSection(): Unit {
    VStack {
        sectionHeader("间距 Spacing（4px 栅格）")
        Panel {
            VStack {
                for (step in SPACING_STEPS) {
                    HStack {
                        Label(step.name).muted().fontSize(FontSizes.CAPTION).width(Spacing.xxl)
                        VStack {}.width(step.length).height(14.0).background(ACCENT, Radii.sm)
                        Label("${Int64(step.length.value)}vp").muted().fontSize(FontSizes.CAPTION)
                        Spacer()
                    }.spacing(Spacing.md).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                }
            }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        }.contentPadding(Spacing.lg)
    }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func radiiSection(): Unit {
    VStack {
        sectionHeader("圆角 Radii")
        Panel {
            FlowRow {
                for (step in RADIUS_STEPS) {
                    VStack {
                        VStack {}.width(76.0).height(48.0).background(ACCENT_SOFT, step.radius).border(
                            EDGE,
                            width: 1.0,
                            radius: step.radius
                        )
                        Label(step.name).muted().fontSize(FontSizes.CAPTION)
                    }.spacing(Spacing.xs).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                }
            }.spacing(Spacing.md, Spacing.md)
        }.contentPadding(Spacing.lg)
    }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func elevationSection(): Unit {
    VStack {
        sectionHeader("高度 Elevation（Shadow.elevation）")
        Panel {
            FlowRow {
                for (level in ELEVATION_LEVELS) {
                    VStack {
                        Label("e${level}").muted().fontSize(FontSizes.CAPTION)
                    }.crossAxisAlignment(CrossAxisAlignment.Center).width(88.0).height(56.0).background(
                        CARD_FILL,
                        Radii.md
                    ).shadow(Shadow.elevation(level, color: CARD_SHADOW), radius: Radii.md)
                }
            }.spacing(Spacing.xl, Spacing.xl)
        }.contentPadding(Spacing.xl)
    }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func typeSection(): Unit {
    VStack {
        sectionHeader("字号 Type scale（FontSizes）")
        Panel {
            VStack {
                for (step in TYPE_STEPS) {
                    HStack {
                        Label("Ag 字体").fontSize(step.size)
                        Spacer()
                        Label("${step.name} · ${Int64(step.size)}fp").muted().fontSize(FontSizes.CAPTION)
                    }.spacing(Spacing.md).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                }
            }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        }.contentPadding(Spacing.lg)
    }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func motionSection(): Unit {
    VStack {
        sectionHeader("动效 Motion（时长 + 缓动）")
        Panel {
            VStack {
                for (step in MOTION_STEPS) {
                    HStack {
                        Label(step.name).muted().fontSize(FontSizes.CAPTION).width(Spacing.xxl)
                        VStack {}.width(msBarWidth(step.ms)).height(12.0).background(ACCENT, Radii.sm)
                        Label(formatMs(step.ms)).muted().fontSize(FontSizes.CAPTION)
                        Spacer()
                    }.spacing(Spacing.md).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                }
                Label("缓动：standard(InOut) · decelerate(Out) · accelerate(In) · emphasized(回弹)").muted()
                    .fontSize(FontSizes.CAPTION).wrap()
            }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        }.contentPadding(Spacing.lg)
    }.spacing(Spacing.sm).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}
