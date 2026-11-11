/*
 * 热门页（一级页面）与图书卡片。
 *
 * 卡片是自绘控件：封面走 `drawBookCover`（后台下载/解码，UI 线程上传纹理），
 * 标题按可用宽度截断，整卡可点击进入详情页。
 */
package seline_read

import std.collection.ArrayList
import chui.*
import zlibraryAPI4CJ.core.*
import seline_ui.*

/** 热门页：页头 + 自适应网格。 */
func homePage(state: AppState): Unit {
    // 首页不要页头、不要常驻刷新按钮：直接一墙封面。
    // 只有获取失败时才出现错误条 + 「重新加载」（用户明确要求）。
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.homeScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.error.value.isEmpty()) {
                    errorBannerText(state.error.value)
                    HStack(spacing: vp(SELINE_SPACE_SM)) {
                        SelineButton("重新加载", {=> state.reloadPopular()},
                            glyph: "refresh", kind: SelineButtonKind.Ghost,
                            compact: true, busy: state.loading.value)
                        Spacer()
                    }.hug().fillWidth()
                }
                if (state.forceSkeleton.value ||
                    (state.loading.value && state.popular.value.isEmpty())) {
                    bookSkeletonGrid(count: 12)
                } else {
                    bookGrid(state, state.popular.value, limit: state.popularVisible.value)
                }
                if (state.popularVisible.value < Int64(state.popular.value.size)) {
                    PopularLoadMoreFooter(state)
                }
                if (!state.loading.value && state.popular.value.isEmpty() &&
                    state.error.value.isEmpty()) {
                    emptyBlock("cloud", "没有拿到热门图书", "检查站点状态后再试")
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 书脊网格：列数随窗口宽度自适应；`limit > 0` 时只渲染前 N 张（懒加载用）。 */
func bookGrid(state: AppState, items: ArrayList<BookCell>, limit!: Int64 = -1): Unit {
    if (items.isEmpty()) {
        return
    }
    let total = Int64(items.size)
    let count = if (limit > 0 && limit < total) { limit } else { total }
    AdaptiveGrid(180.0, minColumns: 2, maxColumns: 6) {
        var index: Int64 = 0
        for (item in items) {
            if (index >= count) {
                break
            }
            BookCard(state, item)
            index += 1
        }
    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
}

/**
 * 首页「继续向下滚动」footer：滚进视口才揭示下一批卡片。
 *
 * 用"画到自己了"当可见性判据（ScrollView 给子节点的 frame 是屏幕坐标），
 * 同 seline_bili 的 LoadMoreFooter；幂等由 `popularVisible` 上限保证。
 */
class PopularLoadMoreFooter <: Widget {
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
        if (frame.y < ctx.viewportHeight + 100.0) {
            state.showMorePopular()
        }
        let theme = selineTheme()
        paintText(ctx.renderer, "继续向下滚动加载更多",
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

/** 卡片圆角；封面圆角 = 卡片圆角 - 内边距，两段圆弧才同心。 */
let BOOK_CARD_RADIUS: Float32 = 14.0
let BOOK_CARD_PAD: Float32 = 8.0

/** 一本书的卡片。 */
class BookCard <: Widget {
    private let state: AppState
    private let cell: BookCell
    private var frame = Rect.zero()
    private var hovered = false

    init(state: AppState, cell: BookCell) {
        this.state = state
        this.cell = cell
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        let width = if (available.w > Float32(0.0) && available.w < Float32.Max) {
            available.w
        } else {
            Float32(180.0)
        }
        Size(width, width / BOOK_COVER_ASPECT + 62.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        // 卡片必须有一层比内容面板更亮的底色（同 seline_bili 的 surfaceRaised），
        // 否则卡片与页面同色，圆角和卡片边界完全看不出来。
        let fill = if (hovered) { palette.surfaceHover } else { palette.surfaceRaised }
        paintSurface(ctx.renderer, frame, fill, BOOK_CARD_RADIUS)
        let coverW = frame.w - BOOK_CARD_PAD * 2.0
        let coverH = coverW / BOOK_COVER_ASPECT
        let cover = Rect(frame.x + BOOK_CARD_PAD, frame.y + BOOK_CARD_PAD, coverW, coverH)
        // 封面圆角 = 卡片圆角 - 内边距，两条圆弧同心
        drawBookCover(ctx, state, cell.cover, cover, BOOK_CARD_RADIUS - BOOK_CARD_PAD)
        let textX = cover.x
        let titleY = cover.y + cover.h + 8.0
        let titleStyle = selineFontStyle(bold: true)
        // 按实际像素宽度截断（结果缓存），避免混排时超出卡片
        let title = state.fittedText(ctx, cell.title, coverW, theme.fontLabel, true,
            theme.fontFamily)
        let author = if (cell.author.isEmpty()) { "未知作者" } else { cell.author }
        let authorText = state.fittedText(ctx, author, coverW, theme.fontCaption, false,
            theme.fontFamily)
        // 文本裁剪到卡片内：即使测量误差/字体回退，也不会"飞"出卡片
        ctx.renderer.pushClip(Rect(frame.x, titleY, frame.w, frame.bottom() - titleY))
        paintText(ctx.renderer, title, Rect(textX, titleY, coverW, 18.0), palette.text,
            theme.fontLabel, style: titleStyle, family: theme.fontFamily)
        paintText(ctx.renderer, authorText, Rect(textX, titleY + 20.0, coverW, 16.0),
            palette.textMuted, theme.fontCaption, family: theme.fontFamily)
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
                    state.openBook(cell)
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
