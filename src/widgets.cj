/*
 * 跨页面共用的小部件与文案。
 */
package seline_read

import std.env.getVariable
import chui.*
import seline_ui.*

/** 内容区左右留白，各页面共用。 */
let PAGE_PAD: Float32 = SELINE_PAGE_MARGIN

/**
 * 全局滚动手感：滚轮步长放大，动画时长缩短。
 *
 * chui 默认是 300ms 的缓动动画；本机整窗重绘较慢（约 40~60ms/帧），
 * 长动画在低帧率下看起来是一跳一跳的。缩短到 160ms + ease-out，
 * 滚轮响应更跟手；也支持 `SELINE_READ_SCROLL=immediate` 直接无动画。
 */
func appScrollOptions(): ScrollOptions {
    let mode = scrollModeOverride()
    if (mode == "immediate") {
        return ScrollOptions.immediate(wheelStep: 96.0)
    }
    ScrollOptions.web(wheelStep: 96.0, duration: 160,
        easing: Easing.CubicBezier(0.16, 1.0, 0.3, 1.0))
}

/**
 * 页面级滚动容器：统一使用 appScrollOptions（各页面滚动都不再用默认手感）。
 *
 * `scrollState` 传入外部 State 时，滚动位置在切页（进详情再返回）后仍保留。
 */
func pageScrollView(scrollState!: ?State<Float32> = None, body!: () -> Unit): ScrollView {
    let view = ScrollView(body: body).scrollOptions(appScrollOptions())
    match (scrollState) {
        case Some(value) => view.scrollState(value)
        case None => view
    }
}

/** 页面标题 + 右侧动作。 */
func pageHeader(title: String, subtitle: String, trailing: () -> Unit): Unit {
    HStack(spacing: vp(SELINE_SPACE_MD)) {
        VStack(spacing: vp(2.0)) {
            Label(title).fontSize(selineTheme().fontTitle).bold()
            // 副标题留空时不占高度（有些页面只要标题）
            if (!subtitle.isEmpty()) {
                Label(subtitle).fontSize(selineTheme().fontCaption).muted()
            }
        }.hug()
        Spacer()
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            trailing()
        }.hug()
    }.hug().fillWidth()
        .padding(PAGE_PAD, 14.0, PAGE_PAD, 8.0)
}


/** 错误提示条：红字 + 浅底，不弹窗（弹窗会打断用户）。 */
/**
 * 去掉错误文案里的"xxx失败："前缀。
 *
 * 卡片已经有标题了，正文再重复一遍前缀会显得啰嗦。
 */
private func stripErrorPrefix(text: String): String {
    for (colon in ["：", ": "]) {
        let index = text.indexOf(colon)
        if (let Some(at) <- index) {
            if (at > 0 && at + colon.size < text.size) {
                return text[at + colon.size..].trimAscii()
            }
        }
    }
    text
}

/**
 * 页面级错误态：居中的错误卡片（圆形图标底 + 标题 + 具体原因 + 重试）。
 *
 * 用于"整页数据都没拿到"的情况 —— 比原来一条红字横幅更能表达"这里出错了"。
 */
func errorStateCard(title: String, detail: String, retry!: Option<() -> Unit> = None,
    busy!: Bool = false): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    // 不加底板：裸内容 + 整体居中（不靠背景块区分层级）
    HStack(spacing: vp(0.0)) {
        Spacer()
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            HStack(spacing: vp(0.0)) {
                Spacer()
                SelineIcon("warn", size: 34.0, color: palette.danger)
                Spacer()
            }.hug().fillWidth()
            HStack(spacing: vp(0.0)) {
                Spacer()
                Label(title).fontSize(theme.fontHeading).bold()
                Spacer()
            }.hug().fillWidth()
            Label(stripErrorPrefix(detail)).fontSize(theme.fontCaption).muted()
                .wrap().textAlign(TextAlign.Center)
            if (let Some(action) <- retry) {
                HStack(spacing: vp(0.0)) {
                    Spacer()
                    SelineButton("重试", action, glyph: "refresh",
                        kind: SelineButtonKind.Secondary, compact: true, busy: busy)
                    Spacer()
                }.hug().fillWidth()
                    .padding(0.0, SELINE_SPACE_MD, 0.0, 0.0)
            }
        }.hug().width(520.0)
            .padding(28.0, 32.0, 28.0, 32.0)
        Spacer()
    }.hug().fillWidth()
}

/**
 * 空状态：图标 + 标题 + 说明 + 可选动作按钮。
 *
 * 中性配色（不是错误），只表达"这里现在没有内容"。
 */
func emptyBlock(glyph: String, title: String, detail: String,
    actionLabel!: String = "", onAction!: Option<() -> Unit> = None): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        HStack(spacing: vp(0.0)) {
            Spacer()
            SelineIcon(glyph, size: 34.0, color: theme.palette.textFaint)
            Spacer()
        }.hug().fillWidth()
        HStack(spacing: vp(0.0)) {
            Spacer()
            Label(title).fontSize(theme.fontBody).bold()
            Spacer()
        }.hug().fillWidth()
        Label(detail).fontSize(theme.fontCaption).muted().wrap()
            .textAlign(TextAlign.Center)
        if (!actionLabel.isEmpty() && (let Some(action) <- onAction)) {
            HStack(spacing: vp(0.0)) {
                Spacer()
                SelineButton(actionLabel, action, glyph: "person_fill",
                    kind: SelineButtonKind.Secondary, compact: true)
                Spacer()
            }.hug().fillWidth()
                .padding(0.0, SELINE_SPACE_SM, 0.0, 0.0)
        }
    }.hug()
        .fillWidth()
        .padding(0.0, 56.0, 0.0, 48.0)
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