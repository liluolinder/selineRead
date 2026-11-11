/*
 * 书单页（一级页面）。
 *
 * 数据来自 papi（eapi 没有书单接口）：`BooklistApi.list` 一次返回
 * 本页书单 + 作者信息 + 每份书单的前几本书（用于卡片预览）。
 *
 * 卡片是自绘控件：左侧一列预览封面，右侧标题/作者/简介/统计，整卡可点。
 */
package seline_read

import chui.*
import seline_ui.*
import zlibraryAPI4CJ.core.*

/** 书单页：没有页头/没有「我的书单」开关，滚动到底自动加载下一页。 */
func booklistsPage(state: AppState): Unit {
    state.ensureBooklistsLoaded()
    VStack(spacing: vp(0.0)) {
        pageScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.booklistsError.value.isEmpty()) {
                    errorBannerText(state.booklistsError.value)
                    HStack(spacing: vp(SELINE_SPACE_SM)) {
                        SelineButton("重新加载", {=> state.loadBooklists()},
                            glyph: "refresh", kind: SelineButtonKind.Ghost,
                            compact: true, busy: state.booklistsLoading.value)
                        Spacer()
                    }.hug().fillWidth()
                }
                if (state.forceSkeleton.value ||
                    (state.booklistsLoading.value && state.booklists.value.isEmpty())) {
                    booklistSkeletonGrid(count: 6)
                } else if (!state.booklists.value.isEmpty()) {
                    AdaptiveGrid(360.0, minColumns: 2, maxColumns: 3) {
                        for (cell in state.booklists.value) {
                            BooklistCard(state, cell)
                        }
                    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
                    if (state.booklistsNextPage.value > 0) {
                        BooklistsLoadMoreFooter(state)
                    }
                } else if (!state.booklistsLoading.value &&
                    state.booklistsError.value.isEmpty()) {
                    emptyBlock("folder", "没有找到书单", "换个关键词，或稍后重试")
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 书单页 footer：滚进视口就自动加载下一页。 */
class BooklistsLoadMoreFooter <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 56.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (!state.booklistsLoading.value && frame.y < ctx.viewportHeight + 100.0) {
            state.loadBooklists(reset: false)
        }
        let theme = selineTheme()
        paintText(ctx.renderer,
            if (state.booklistsLoading.value) { "正在加载更多书单…" } else { "继续向下滚动加载更多" },
            Rect(frame.x, frame.centerY() - 9.0, frame.w, 20.0),
            theme.palette.textFaint, theme.fontCaption, align: SelineTextAlign.Center)
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

/** 书单卡片：左侧预览封面，右侧文字。 */
let BOOKLIST_CARD_RADIUS: Float32 = 12.0
let BOOKLIST_CARD_PAD: Float32 = 10.0
let BOOKLIST_PREVIEW_W: Float32 = 46.0
let BOOKLIST_PREVIEW_H: Float32 = 66.0
let BOOKLIST_PREVIEW_GAP: Float32 = 5.0

class BooklistCard <: Widget {
    private let state: AppState
    private let cell: BooklistCell
    private var frame = Rect.zero()
    private var hovered = false

    init(state: AppState, cell: BooklistCell) {
        this.state = state
        this.cell = cell
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        let width = if (available.w > Float32(0.0) && available.w < Float32.Max) {
            available.w
        } else {
            Float32(360.0)
        }
        Size(width, 112.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let fill = if (hovered) { palette.surfaceHover } else { palette.surfaceRaised }
        paintSurface(ctx.renderer, frame, fill, BOOKLIST_CARD_RADIUS)
        // 左侧预览封面（最多 3 张）
        let coverCount = if (cell.covers.size > 3) { 3 } else { cell.covers.size }
        var index: Int64 = 0
        while (index < coverCount) {
            let x = frame.x + BOOKLIST_CARD_PAD +
                Float32(index) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP)
            let cover = Rect(x, frame.y + BOOKLIST_CARD_PAD, BOOKLIST_PREVIEW_W,
                BOOKLIST_PREVIEW_H)
            drawBookCover(ctx, state, cell.covers[index], cover, 6.0)
            index += 1
        }
        let textX = frame.x + BOOKLIST_CARD_PAD +
            Float32(3) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP) + 4.0
        let textW = max(Float32(40.0), frame.right() - BOOKLIST_CARD_PAD - textX)
        let title = state.fittedText(ctx, cell.title, textW, theme.fontLabel, true,
            theme.fontFamily)
        paintText(ctx.renderer, title,
            Rect(textX, frame.y + 8.0, textW, 20.0), palette.text, theme.fontLabel,
            style: selineFontStyle(bold: true), family: theme.fontFamily)
        let author = if (cell.author.isEmpty()) { "匿名书单" } else { cell.author }
        paintText(ctx.renderer, state.fittedText(ctx, author, textW, theme.fontCaption,
            false, theme.fontFamily), Rect(textX, frame.y + 30.0, textW, 16.0),
            palette.textMuted, theme.fontCaption, family: theme.fontFamily)
        if (!cell.description.isEmpty()) {
            paintText(ctx.renderer, state.fittedText(ctx, cell.description, textW,
                theme.fontCaption, false, theme.fontFamily),
                Rect(textX, frame.y + 50.0, textW, 16.0), palette.textFaint,
                theme.fontCaption, family: theme.fontFamily)
        }
        let meta = state.fittedText(ctx,
            "${cell.booksCount} 本 · 浏览 ${cell.viewsCount} · 收藏 ${cell.favoritesCount}",
            textW, theme.fontCaption, false, theme.fontFamily)
        ctx.renderer.pushClip(Rect(textX, frame.y, textW, frame.h))
        paintText(ctx.renderer, meta,
            Rect(textX, frame.bottom() - 26.0, textW, 16.0), palette.textFaint,
            theme.fontCaption, family: theme.fontFamily)
        ctx.renderer.popClip()
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
                    state.openBooklist(cell)
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
