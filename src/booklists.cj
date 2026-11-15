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

let BOOKLIST_CELL_W: Float32 = 320.0

/**
 * 书单页：没有页头/没有「我的书单」开关，滚动到底自动加载下一页。
 *
 * 三种状态（加载中/有数据/出错）**都放在同一个滚动容器里**：这样无论客户端是不是
 * 已经就绪、侧栏有没有展开，页面始终能滚到内容底部，不会出现"这一屏根本滚不动"。
 * 「加载更多」不再画在页面里，改由右下角 Toast 反馈。
 */
func booklistsPage(state: AppState): Unit {
    state.ensureBooklistsLoaded()
    let loading = state.booklistsLoading.value
    let failed = !state.booklistsError.value.isEmpty()
    let cells = state.booklists.value
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.booklistsScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (state.forceSkeleton.value || !state.isClientReady() ||
                    (loading && cells.isEmpty())) {
                    // 骨架铺满一屏：加载中页面看起来仍是"满"的，底部也能滚到。
                    booklistSkeletonGrid(count: 18)
                } else if (!cells.isEmpty()) {
                    if (failed) {
                        state.toastIfChanged(state.booklistsError.value)
                    }
                    AdaptiveGrid(BOOKLIST_CELL_W, minColumns: 2, maxColumns: 5) {
                        for (cell in cells) {
                            BooklistCard(state, cell)
                        }
                    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
                    if (state.booklistsNextPage.value > 0) {
                        LoadMoreNotice(trigger: {=>
                            if (!state.booklistsLoading.value) {
                                // 首屏没铺满窗口时会立刻自动补一页 —— 这种也要提示，
                                // 否则用户只看到"页面没满、还在转"，不知道发生了什么。
                                state.showToastNow("正在加载更多书单…", kind: ToastKind.Info)
                                state.loadBooklists(reset: false)
                            }
                        })
                    }
                } else if (failed) {
                    VStack(spacing: vp(0.0)) {
                        errorStateCard("书单加载失败", state.booklistsError.value,
                            retry: Some({=> state.loadBooklists()}), busy: loading)
                    }.padding(0.0, 72.0, 0.0, 0.0)
                } else if (!loading) {
                    emptyBlock("folder", "没有找到书单", "换个关键词，或稍后重试")
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 书单卡片：左侧预览封面，右侧文字。 */
let BOOKLIST_CARD_RADIUS: Float32 = 12.0
/**
 * 卡片列宽。
 *
 * 选 320 是为了**列数稳定**：内容区在侧栏收起时约 1168、展开时约 1004，
 * `1168/320 = 3.65 → 3 列`、`1004/320 = 3.14 → 3 列`，两种状态都是 3 列。
 * 之前是 340（3 列 ↔ 2 列来回跳），每跳一次整页重排、还让一批新卡片进入视口
 * 触发文字首绘 —— 侧栏展开时那几帧 40~50ms 的卡顿就是这么来的。
 */
let BOOKLIST_CARD_PAD: Float32 = 10.0
let BOOKLIST_PREVIEW_W: Float32 = 46.0
let BOOKLIST_PREVIEW_H: Float32 = 66.0
let BOOKLIST_PREVIEW_GAP: Float32 = 5.0
/**
 * 卡片高度 = 预览封面高 + 上下内边距。
 *
 * 这样封面四周的留白都是 `BOOKLIST_CARD_PAD`（上=下=左），
 * 不会出现"左右 10、上下 23"这种不一致。
 */
let BOOKLIST_CARD_H: Float32 = BOOKLIST_PREVIEW_H + BOOKLIST_CARD_PAD * 2.0

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
        Size(width, BOOKLIST_CARD_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        // 视口外的卡片不画：滚动时列表里可能已经有几十张卡，全画一遍很贵。
        if (!visibleInViewport(ctx, frame)) {
            return
        }
        let cardT0 = PerformanceClock.ticksNanoseconds()
        state.diagCardCount += 1
        drawCardBody(ctx)
        state.diagCardMs += Float32(Int64(PerformanceClock.ticksNanoseconds() - cardT0)) / 1000000.0
    }

    private func drawCardBody(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let fill = if (hovered) { palette.surfaceHover } else { palette.surfaceRaised }
        paintSurface(ctx.renderer, frame, fill, BOOKLIST_CARD_RADIUS)
        // 左侧预览封面（最多 3 张）
        // 贴内边距：上/下/左都是 BOOKLIST_CARD_PAD，四边留白一致（之前封面垂直居中，
        // 左右 10、上下 23，看起来整体偏上，和右侧文字也不齐）。
        let coverTop = frame.y + BOOKLIST_CARD_PAD
        // 固定画 3 个封面位：接口没给预览（或不足 3 本）时补默认封面图，不能留空 ——
        // 同一屏里有的卡 3 张、有的 1 张、有的全空，会让人以为加载失败。
        // 空 URL 传给 drawBookCover 就会画 assets 里的占位封面。
        var index: Int64 = 0
        while (index < 3) {
            let x = frame.x + BOOKLIST_CARD_PAD +
                Float32(index) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP)
            let cover = Rect(x, coverTop, BOOKLIST_PREVIEW_W, BOOKLIST_PREVIEW_H)
            let url = if (index < cell.covers.size) { cell.covers[index] } else { "" }
            // 三个封面位共用一块底板（第一张时画），少两次圆角填充/卡
            drawBookCover(ctx, state, url, cover, 6.0, backdrop: index == 0)
            index += 1
        }

        // 文字首绘受每帧预算限制：没轮到的卡片这一帧只画底板/封面，下一帧补上
        if (!state.grantCardText("bl|${cell.id}")) {
            ctx.requestFrame()
            return
        }
        let textX = frame.x + BOOKLIST_CARD_PAD +
            Float32(3) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP) + 4.0
        let textW = max(Float32(40.0), frame.right() - BOOKLIST_CARD_PAD - textX)
        let title = state.fittedText(ctx, cell.title, textW, theme.fontLabel, true,
            theme.fontFamily)
        paintText(ctx.renderer, title,
            Rect(textX, coverTop, textW, 18.0), palette.text, theme.fontLabel,
            style: selineFontStyle(bold: true), family: theme.fontFamily)
        let author = if (cell.author.isEmpty()) { "匿名书单" } else { cell.author }
        paintText(ctx.renderer, state.fittedText(ctx, author, textW, theme.fontCaption,
            false, theme.fontFamily), Rect(textX, coverTop + 18.0, textW, 15.0),
            palette.textMuted, theme.fontCaption, family: theme.fontFamily)
        if (!cell.description.isEmpty()) {
            paintText(ctx.renderer, state.fittedText(ctx, cell.description, textW,
                theme.fontCaption, false, theme.fontFamily),
                Rect(textX, coverTop + 33.0, textW, 15.0), palette.textFaint,
                theme.fontCaption, family: theme.fontFamily)
        }
        // 统计行已经是 fittedText（一定放得下），不需要再 pushClip/popClip：
        // 每次裁剪都是一次渲染状态切换，卡片多了这开销很可观。
        let meta = state.fittedText(ctx,
            "${cell.booksCount} 本 · 浏览 ${cell.viewsCount} · 收藏 ${cell.favoritesCount}",
            textW, theme.fontCaption, false, theme.fontFamily)
        paintText(ctx.renderer, meta,
            Rect(textX, coverTop + BOOKLIST_PREVIEW_H - 15.0, textW, 15.0), palette.textFaint,
            theme.fontCaption, family: theme.fontFamily)
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
