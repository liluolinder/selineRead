/*
 * 图书详情页（二级页面）：封面 + 元信息 + 下载 + 可选格式 + 简介。
 *
 * 数据由 `AppState.openBook` 在后台拉取，页面只读 State；
 * 首帧直接显示列表项已有的标题/作者/封面，不阻塞打开动作。
 */
package seline_read

import std.collection.ArrayList
import chui.*
import seline_ui.*

/** 详情页顶部两张卡片的总高度。 */
let DETAIL_TOP_HEIGHT: Float32 = 272.0
/** 卡片内边距 / 圆角。 */
let DETAIL_CARD_PAD: Float32 = 12.0
let DETAIL_CARD_RADIUS: Float32 = 12.0
/** 卡片内可用高度（总高 - 上下内边距）：封面高度取它。 */
let DETAIL_CARD_INNER_H: Float32 = 248.0
/** 简介滚动区高度（内高 - 「简介」标题行）。 */
let DETAIL_DESC_H: Float32 = 218.0

func detailPage(state: AppState): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(0.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("返回", {=> state.closeDetail()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth().padding(PAGE_PAD, 12.0, PAGE_PAD, 4.0)
        pageScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.detailError.value.isEmpty()) {
                    errorBannerText(state.detailError.value)
                }
                // 两张卡片（都圆角、都有底色）：
                //   左：封面 + 书名 + 作者/元信息
                //   右：简介（高度与左卡一致，内部可滚动）
                HStack(spacing: vp(SELINE_SPACE_MD)) {
                    HStack(spacing: vp(SELINE_SPACE_MD)) {
                        DetailCover(state, height: DETAIL_CARD_INNER_H)
                        VStack(spacing: vp(SELINE_SPACE_XS)) {
                            Label(state.detailTitle.value).fontSize(theme.fontHeading).bold()
                                .wrap()
                            Label(if (state.detailAuthor.value.isEmpty()) {
                                "未知作者"
                            } else {
                                state.detailAuthor.value
                            }).fontSize(theme.fontBody).muted()
                            Label(state.detailMeta.value).fontSize(theme.fontCaption).muted()
                            Spacer()
                        }.width(190.0)
                    }.hug()
                        .padding(DETAIL_CARD_PAD)
                        .background(theme.palette.surfaceRaised, vp(DETAIL_CARD_RADIUS))
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label("简介").fontSize(theme.fontHeading).bold()
                        if (state.detailLoading.value &&
                            state.detailDescription.value.isEmpty()) {
                            descriptionSkeleton()
                            ()
                        } else if (state.detailDescription.value.isEmpty()) {
                            Label("暂无简介").fontSize(theme.fontBody).muted()
                            ()
                        } else {
                            DescriptionScroll(state, DETAIL_DESC_H)
                            ()
                        }
                    }.flex()
                        .padding(DETAIL_CARD_PAD)
                        .background(theme.palette.surfaceRaised, vp(DETAIL_CARD_RADIUS))
                }.height(DETAIL_TOP_HEIGHT).fillWidth()
                // 下载（点击弹出「版本选择」菜单）
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    DownloadMenuButton(state)
                    if (!state.loggedIn.value) {
                        Label("下载需要先在「设置」页登录").fontSize(theme.fontCaption).muted()
                    }
                    Spacer()
                }.hug().fillWidth()
                if (!state.downloadMessage.value.isEmpty()) {
                    Label(state.downloadMessage.value).fontSize(theme.fontCaption)
                        .foregroundColor(theme.palette.accent)
                }
                // 分段：书籍信息 / 书籍评论 / 相关书籍
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineSegmented(["书籍信息", "书籍评论", "相关书籍"],
                        state.detailSection.value,
                        {index => state.selectDetailSection(index)}, minSegment: 96.0)
                    Spacer()
                }.hug().fillWidth()
                if (state.detailSection.value == 0) {
                    bookInfoSection(state)
                } else if (state.detailSection.value == 1) {
                    commentsSection(state)
                } else {
                    relatedSection(state)
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 书籍信息：两列 key/value。 */
func bookInfoSection(state: AppState): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        Label("书籍信息").fontSize(theme.fontHeading).bold()
        HStack(spacing: vp(SELINE_SPACE_XL)) {
            VStack(spacing: vp(SELINE_SPACE_SM)) {
                detailInfoRow("ISBN", state.detailIdentifier.value)
                detailInfoRow("出版社", state.detailPublisher.value)
                detailInfoRow("年份", state.detailYear.value)
                detailInfoRow("语言", state.detailLanguage.value)
                detailInfoRow("页数", state.detailPages.value)
            }.flex()
            VStack(spacing: vp(SELINE_SPACE_SM)) {
                detailInfoRow("版本", state.detailEdition.value)
                detailInfoRow("系列", state.detailSeries.value)
                detailInfoRow("格式", state.detailExtension.value)
                detailInfoRow("文件大小", state.detailFilesize.value)
                detailInfoRow("作者", state.detailAuthor.value)
            }.flex()
        }.hug().fillWidth()
    }.hug().fillWidth()
        .padding(12.0)
        .background(theme.palette.surfaceRaised, vp(10.0))
}

func detailInfoRow(label: String, value: String): Unit {
    let theme = selineTheme()
    HStack(spacing: vp(SELINE_SPACE_SM)) {
        Label(label).fontSize(theme.fontCaption).muted().width(72.0)
        Label(if (value.isEmpty()) { "—" } else { value })
            .fontSize(theme.fontBody).wrap()
        Spacer()
    }.hug().fillWidth()
}

/** 书籍评论（懒加载：切到本分段才请求）。 */
func commentsSection(state: AppState): Unit {
    let theme = selineTheme()
    state.ensureCommentsLoaded()
    VStack(spacing: vp(SELINE_SPACE_XS)) {
        Label(if (state.comments.value.isEmpty()) {
            "评论"
        } else {
            "评论 ${state.comments.value.size}"
        }).fontSize(theme.fontHeading).bold()
        if (!state.commentsError.value.isEmpty()) {
            errorBannerText(state.commentsError.value)
        }
        if (state.commentsDisabled.value) {
            Label("本书已关闭评论").fontSize(theme.fontCaption).muted()
        }
        if (state.commentsLoading.value && state.comments.value.isEmpty()) {
            commentSkeleton(rows: 3)
        }
        var shown: Int64 = 0
        for (comment in state.comments.value) {
            if (shown >= state.commentsVisible.value) {
                break
            }
            commentRow(comment)
            shown += 1
        }
        if (!state.commentsLoading.value && state.comments.value.isEmpty() &&
            state.commentsError.value.isEmpty() && !state.commentsDisabled.value) {
            Label("还没有评论").fontSize(theme.fontCaption).muted()
        }
        if (state.commentsVisible.value < Int64(state.comments.value.size)) {
            SelineButton("显示更多评论", {=> state.showMoreComments()},
                glyph: "chevron_down_fill", kind: SelineButtonKind.Ghost, compact: true)
        } else if (state.commentsNextOffset.value > 0) {
            SelineButton("加载更多评论", {=> state.loadMoreComments()},
                glyph: "refresh", kind: SelineButtonKind.Ghost, compact: true,
                busy: state.commentsLoading.value)
        }
    }.hug().fillWidth()
}

/** 相关书籍（懒加载：切到本分段才请求）。 */
func relatedSection(state: AppState): Unit {
    let theme = selineTheme()
    state.ensureRelatedLoaded()
    VStack(spacing: vp(SELINE_SPACE_MD)) {
        Label("相关书籍").fontSize(theme.fontHeading).bold()
        if (!state.detailRelatedError.value.isEmpty()) {
            errorBannerText(state.detailRelatedError.value)
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineButton("重新加载", {=> state.reloadRelated()}, glyph: "refresh",
                    kind: SelineButtonKind.Ghost, compact: true,
                    busy: state.detailRelatedLoading.value)
                Spacer()
            }.hug().fillWidth()
        }
        if (state.detailRelatedLoading.value && state.detailRelated.value.isEmpty()) {
            bookSkeletonGrid(count: 12)
        } else if (state.detailRelated.value.isEmpty() &&
            state.detailRelatedError.value.isEmpty()) {
            emptyBlock("cloud", "没有相关书籍", "服务端没有返回相似图书")
        } else {
            bookGrid(state, state.detailRelated.value)
        }
    }.hug().fillWidth()
}
/** 详情页大封面：2:3 固定槽位。 */
class DetailCover <: Widget {
    private let state: AppState
    private let coverHeight: Float32
    private var frame = Rect.zero()

    init(state: AppState, height!: Float32 = 270.0) {
        this.state = state
        this.coverHeight = height
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(coverHeight * 2.0 / 3.0, coverHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawBookCover(ctx, state, state.detailCover.value, frame, 10.0)
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

/** 下载按钮：点击弹出「默认链接 + 可选格式」菜单，并把自身位置写给菜单定位。 */
class DownloadMenuButton <: Widget {
    private let state: AppState
    private var frame = Rect.zero()
    private var hovered = false

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(ctx: UiContext, _: Size): Size {
        let theme = selineTheme()
        let textWidth = ctx.renderer.textWidth("下载", pointSize: theme.fontLabel,
            style: selineFontStyle(bold: true), font: None<String>)
        Size(max(100.0, textWidth + 64.0), 34.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
        // 菜单锚点：每帧同步（普通对象，不触发重建）
        state.downloadAnchor.x = rect.x
        state.downloadAnchor.y = rect.y
        state.downloadAnchor.w = rect.w
        state.downloadAnchor.h = rect.h
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let open = state.downloadMenuOpen.value
        let fill = if (open) {
            palette.accentSoft
        } else if (hovered) {
            palette.surfaceHover
        } else {
            palette.surfaceSunken
        }
        paintSurface(ctx.renderer, frame, fill, 8.0,
            border: if (open) { palette.accent } else { palette.border })
        drawGlyph(ctx.renderer, "download",
            Rect(frame.x + 12.0, frame.centerY() - 8.0, 16.0, 16.0), palette.accent,
            1.0)
        let label = if (state.downloading.value) { "下载中…" } else { "下载" }
        paintText(ctx.renderer, label,
            Rect(frame.x + 34.0, frame.y, frame.w - 58.0, frame.h), palette.text,
            theme.fontLabel, style: selineFontStyle(bold: true), family: theme.fontFamily)
        drawGlyph(ctx.renderer, "chevron_down_fill",
            Rect(frame.right() - 22.0, frame.centerY() - 6.0, 12.0, 12.0),
            palette.textMuted, 1.0)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                hovered = frame.contains(x, y)
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                frame.contains(x, y)
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    state.toggleDownloadMenu()
                    true
                } else {
                    false
                }
            case _ => false
        }
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}
/** 一条评论：作者 / 相对时间 / 点赞 + 正文（自动换行）。 */
func commentRow(comment: CommentCell): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(3.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            if (comment.isReply) {
                Label("回复").fontSize(theme.fontCaption)
                    .foregroundColor(theme.palette.accent)
            }
            Label(comment.author).fontSize(theme.fontLabel).bold()
            Label(comment.dateRelative).fontSize(theme.fontCaption).muted()
            if (comment.likes > 0) {
                Label("赞 ${comment.likes}").fontSize(theme.fontCaption).muted()
            }
            Spacer()
        }.hug().fillWidth()
        Label(comment.text).fontSize(theme.fontBody).wrap()
    }.hug().fillWidth()
        .padding(10.0)
        .background(theme.palette.surfaceSunken, vp(8.0))
}

/** 固定高度、可滚动的简介区：自己折行并处理滚轮，避免与页面 ScrollView 嵌套。 */
class DescriptionScroll <: Widget {
    private let state: AppState
    private let viewHeight: Float32
    private var frame = Rect.zero()

    init(state: AppState, height: Float32) {
        this.state = state
        this.viewHeight = height
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, viewHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    private func lineHeight(): Float32 {
        selineTheme().fontBody + 7.0
    }

    private func lines(ctx: UiContext): ArrayList<String> {
        state.wrappedDescriptionLines(ctx, plainText(state.detailDescription.value),
            frame.w - 8.0)
    }

    private func maxOffset(ctx: UiContext): Float32 {
        let total = lineHeight() * Float32(lines(ctx).size)
        max(0.0, total - frame.h)
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let content = lines(ctx)
        let lineH = lineHeight()
        let limit = maxOffset(ctx)
        var offset = state.detailDescriptionOffset.value
        if (offset > limit) {
            offset = limit
        }
        ctx.renderer.pushClip(frame)
        var index: Int64 = 0
        while (index < content.size) {
            let y = frame.y + Float32(index) * lineH - offset
            if (y > frame.bottom()) {
                break
            }
            if (y + lineH >= frame.y) {
                paintText(ctx.renderer, content[index],
                    Rect(frame.x, y, frame.w, lineH), theme.palette.text,
                    theme.fontBody, family: theme.fontFamily)
            }
            index += 1
        }
        ctx.renderer.popClip()
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseWheel(_, wheelY, x, y) =>
                if (!frame.contains(x, y)) {
                    return false
                }
                let limit = maxOffset(ctx)
                if (limit <= 0.0) {
                    // 简介没有超出高度：滚轮交给页面继续滚动
                    return false
                }
                let current = state.detailDescriptionOffset.value
                let next = max(0.0, min(limit, current + wheelY * 48.0))
                if (next == current) {
                    // 已经到顶/到底：滚轮继续传给页面
                    return false
                }
                state.detailDescriptionOffset.value = next
                true
            case _ => false
        }
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}

/** 把文本按像素宽度折行（贪心 + 二分查找每行结尾，结果由 AppState 缓存）。 */
func wrapTextByWidth(ctx: UiContext, text: String, width: Float32, pointSize: Float32,
    family: String): ArrayList<String> {
    let out = ArrayList<String>()
    let fontValue: ?String = if (family.isEmpty()) {
        None<String>
    } else {
        Some(family)
    }
    for (paragraph in text.split("\n")) {
        let runes = paragraph.toRuneArray()
        if (runes.isEmpty()) {
            out.add("")
            continue
        }
        var start: Int64 = 0
        while (start < Int64(runes.size)) {
            var low = start + 1
            var high = Int64(runes.size)
            var best = low
            while (low <= high) {
                let mid = (low + high) / 2
                let candidate = runesSlice(runes, start, mid)
                if (ctx.renderer.textWidth(candidate, pointSize: pointSize,
                    font: fontValue) <= width) {
                    best = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }
            out.add(runesSlice(runes, start, best))
            start = best
        }
    }
    out
}

func runesSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var index = start
    while (index < end && index < Int64(runes.size)) {
        builder.append(runes[index].toString())
        index += 1
    }
    builder.toString()
}