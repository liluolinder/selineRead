/*
 * 图书详情页（二级页面）：封面 + 元信息 + 下载 + 可选格式 + 简介。
 *
 * 数据由 `AppState.openBook` 在后台拉取，页面只读 State；
 * 首帧直接显示列表项已有的标题/作者/封面，不阻塞打开动作。
 */
package seline_read

import chui.*
import seline_ui.*

func detailPage(state: AppState): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(0.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("返回", {=> state.closeDetail()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth().padding(PAGE_PAD, 12.0, PAGE_PAD, 4.0)
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.detailError.value.isEmpty()) {
                    errorBannerText(state.detailError.value)
                }
                HStack(spacing: vp(SELINE_SPACE_LG)) {
                    DetailCover(state)
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label(state.detailTitle.value).fontSize(theme.fontTitle).bold().wrap()
                        Label(if (state.detailAuthor.value.isEmpty()) {
                            "未知作者"
                        } else {
                            state.detailAuthor.value
                        }).fontSize(theme.fontBody).muted()
                        Label(state.detailMeta.value).fontSize(theme.fontCaption).muted()
                        if (state.detailLoading.value) {
                            loadingBlock("正在加载详情…")
                        }
                        HStack(spacing: vp(SELINE_SPACE_SM)) {
                            // 点击弹出「版本选择」菜单：第一项是默认下载链接，下面是可选格式
                            DownloadMenuButton(state)
                            if (!state.loggedIn.value) {
                                Label("下载需要先在「设置」页登录").fontSize(theme.fontCaption)
                                    .muted()
                            }
                            Spacer()
                        }.hug().fillWidth()
                            .padding(0.0, 4.0, 0.0, 0.0)
                        if (!state.downloadMessage.value.isEmpty()) {
                            Label(state.downloadMessage.value).fontSize(theme.fontCaption)
                                .foregroundColor(theme.palette.accent)
                        }
                    }.hug()
                    Spacer()
                }.hug().fillWidth()
                if (!state.detailDescription.value.isEmpty()) {
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label("简介").fontSize(theme.fontHeading).bold()
                        Label(plainText(state.detailDescription.value)).fontSize(theme.fontBody).wrap()
                    }.hug().fillWidth()
                }

                // 评论（papi：eapi 没有评论接口）
                VStack(spacing: vp(SELINE_SPACE_XS)) {
                    Label("评论").fontSize(theme.fontHeading).bold()
                    if (!state.commentsError.value.isEmpty()) {
                        errorBannerText(state.commentsError.value)
                    }
                    if (state.commentsDisabled.value) {
                        Label("本书已关闭评论").fontSize(theme.fontCaption).muted()
                    }
                    if (state.commentsLoading.value && state.comments.value.isEmpty()) {
                        loadingBlock("正在加载评论…")
                    }
                    for (comment in state.comments.value) {
                        commentRow(comment)
                    }
                    if (!state.commentsLoading.value && state.comments.value.isEmpty() &&
                        state.commentsError.value.isEmpty() &&
                        !state.commentsDisabled.value) {
                        Label("还没有评论").fontSize(theme.fontCaption).muted()
                    }
                    if (state.commentsNextOffset.value > 0) {
                        SelineButton("加载更多评论", {=> state.loadMoreComments()},
                            glyph: "refresh", kind: SelineButtonKind.Ghost,
                            compact: true, busy: state.commentsLoading.value)
                    }
                }.hug().fillWidth()
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 详情页大封面：2:3 固定槽位。 */
class DetailCover <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(180.0, 270.0)
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