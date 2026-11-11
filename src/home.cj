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
        ScrollView {
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
                if (state.loading.value && state.popular.value.isEmpty()) {
                    loadingBlock("正在获取热门图书…")
                }
                bookGrid(state, state.popular.value)
                if (!state.loading.value && state.popular.value.isEmpty() &&
                    state.error.value.isEmpty()) {
                    emptyBlock("cloud", "没有拿到热门图书", "检查站点状态后再试")
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 书脊网格：列数随窗口宽度自适应。 */
func bookGrid(state: AppState, items: ArrayList<BookCell>): Unit {
    if (items.isEmpty()) {
        return
    }
    AdaptiveGrid(180.0, minColumns: 2, maxColumns: 6) {
        for (item in items) {
            BookCard(state, item)
        }
    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
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
        // 卡片每帧重画，逐字符测量文字宽度会把 100 张卡片的绘制拖到几秒一帧；
        // 按字符数截断足够（书名标题的展示只需要"大致不溢出"）。
        let title = truncateRunes(cell.title, 16, suffix: "…")
        paintText(ctx.renderer, title, Rect(textX, titleY, coverW, 18.0), palette.text,
            theme.fontLabel, style: titleStyle, family: theme.fontFamily)
        let author = if (cell.author.isEmpty()) { "未知作者" } else { cell.author }
        let authorText = truncateRunes(author, 18, suffix: "…")
        paintText(ctx.renderer, authorText, Rect(textX, titleY + 20.0, coverW, 16.0),
            palette.textMuted, theme.fontCaption, family: theme.fontFamily)
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
