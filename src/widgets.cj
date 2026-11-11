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

/** 解 HTML 常见命名实体。 */
private func decodeHtmlEntity(name: String): String {
    if (name == "amp") {
        return "&"
    }
    if (name == "lt") {
        return "<"
    }
    if (name == "gt") {
        return ">"
    }
    if (name == "quot") {
        return "\""
    }
    if (name == "apos" || name == "#39") {
        return "'"
    }
    if (name == "nbsp") {
        return " "
    }
    "&" + name + ";"
}

/**
 * 把服务端简介里的 HTML 标签与常见实体转成纯文本。
 *
 * 只用于展示：服务端 `description` 是 HTML 片段（`<p>…</p>`），直接塞进
 * `Label` 会把标签本身显示出来。这里不追求完整 HTML 解析，只处理标签与实体。
 */
func plainText(markup: String): String {
    let runes = markup.toRuneArray()
    var result = ""
    var inTag = false
    var inEntity = false
    var entity = ""
    for (rune in runes) {
        let ch = rune.toString()
        if (inTag) {
            if (ch == ">") {
                inTag = false
            }
            continue
        }
        if (inEntity) {
            if (ch == ";") {
                result += decodeHtmlEntity(entity)
                entity = ""
                inEntity = false
            } else if (ch == "<") {
                result += "&" + entity
                entity = ""
                inEntity = false
                inTag = true
            } else {
                entity += ch
            }
            continue
        }
        if (ch == "<") {
            inTag = true
            continue
        }
        if (ch == "&") {
            inEntity = true
            entity = ""
            continue
        }
        result += ch
    }
    if (inEntity) {
        result += "&" + entity
    }
    result
}