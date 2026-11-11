/*
 * 跨页面共用的小部件与文案。
 */
package seline_read

import chui.*
import seline_ui.*

/** 内容区左右留白，各页面共用。 */
let PAGE_PAD: Float32 = SELINE_PAGE_MARGIN

/** 页面标题 + 右侧动作。 */
func pageHeader(title: String, subtitle: String, trailing: () -> Unit): Unit {
    HStack(spacing: vp(SELINE_SPACE_MD)) {
        VStack(spacing: vp(2.0)) {
            Label(title).fontSize(selineTheme().fontTitle).bold()
            Label(subtitle).fontSize(selineTheme().fontCaption).muted()
        }.hug()
        Spacer()
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            trailing()
        }.hug()
    }.hug().fillWidth()
        .padding(PAGE_PAD, 14.0, PAGE_PAD, 8.0)
}

/** 加载态：转圈 + 一句说明。 */
func loadingBlock(text: String): Unit {
    HStack(spacing: vp(SELINE_SPACE_SM)) {
        SelineSpinner(size: 16.0)
        Label(text).fontSize(selineTheme().fontBody).muted()
    }.hug()
        .fillWidth()
        .padding(0.0, 24.0, 0.0, 24.0)
}

/** 错误提示条：红字 + 浅底，不弹窗（弹窗会打断用户）。 */
func errorBannerText(text: String): Unit {
    let palette = selineTheme().palette
    HStack(spacing: vp(SELINE_SPACE_SM)) {
        SelineIcon("warn", size: 15.0, color: palette.danger)
        Label(text).fontSize(selineTheme().fontLabel).foregroundColor(palette.danger)
    }.hug()
        .fillWidth()
        .padding(12.0)
        .background(palette.surfaceSunken, vp(8.0))
}

/** 空状态：图标 + 标题 + 说明。 */
func emptyBlock(glyph: String, title: String, detail: String): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        SelineIcon(glyph, size: 34.0, color: theme.palette.textFaint)
        Label(title).fontSize(theme.fontBody).bold()
        Label(detail).fontSize(theme.fontCaption).muted().wrap()
    }.hug()
        .fillWidth()
        .padding(0.0, 48.0, 0.0, 48.0)
}
