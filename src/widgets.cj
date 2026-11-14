/*
 * 跨页面共用的小部件与文案。
 */
package seline_read

import chui.*
import seline_ui.*

/** 内容区左右留白，各页面共用。 */
let PAGE_PAD: Float32 = SELINE_PAGE_MARGIN

/**
 * 全局滚动手感。
 *
 * 目标是"滚轮一格 = 一小段、动画能看清但不停顿"：
 * - 步长 84px（约 2~3 行），比默认更大，滚轮响应跟手；
 * - 动画 200ms + ease-out：全程十几帧都在动，60Hz 下是连续滑动，
 *   而不是"一下就跳过去"；先快后慢的曲线收尾不生硬。
 *
 * 也支持 `SELINE_READ_SCROLL=immediate` 直接无动画（验收/低配机用）。
 */
func appScrollOptions(): ScrollOptions {
    let mode = scrollModeOverride()
    if (mode == "immediate") {
        return ScrollOptions.immediate(wheelStep: 84.0)
    }
    ScrollOptions.web(wheelStep: 84.0, duration: 200, easing: Easing.EaseOutCubic)
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

/**
 * 绘制裁剪：卡片是否与当前视口相交。
 *
 * `ScrollView` 会把整棵内容树都画一遍（视口外只是被裁掉像素），长列表滚动时
 * 视口外几十张卡片每帧仍在做圆角/文字/贴图绘制。卡片自己的 `draw` 里用这个
 * 判断先退出，能省掉绝大部分无效绘制。
 */
func visibleInViewport(ctx: UiContext, frame: Rect, margin!: Float32 = 96.0): Bool {

    if (frame.h <= Float32(0.0) || frame.w <= Float32(0.0)) {
        return false
    }
    frame.bottom() > -margin && frame.y < ctx.viewportHeight + margin
}

/**
 * 「滚进视口就加载更多」的哨兵。
 *
 * 页面里**不再画任何提示文字**（"继续向下滚动"/"正在加载更多"都去掉），只保留
 * 一个薄薄的触发区；加载状态由调用方用 Toast 反馈。
 */
class LoadMoreNotice <: Widget {
    private let trigger: () -> Unit
    private var frame = Rect.zero()

    init(trigger!: () -> Unit) {
        this.trigger = trigger
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 24.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (frame.y < ctx.viewportHeight + 120.0) {
            trigger()
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
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