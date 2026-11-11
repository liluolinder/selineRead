/*
 * 加载骨架：所有"等待数据"的页面统一用骨架网格，不再显示「转圈 + 文字」。
 *
 * 骨架是纯静态绘制（不做 shimmer 动画）：静态页面本就按需请求帧，
 * 给骨架加动画会重新变成每帧重绘，得不偿失。
 */
package seline_read

import chui.*
import seline_ui.*

/** 一个圆角占位块。 */
class SkeletonBox <: Widget {
    private let boxWidth: Float32
    private let boxHeight: Float32
    private let radius: Float32
    private var frame = Rect.zero()

    init(width: Float32, height: Float32, radius!: Float32 = 8.0) {
        this.boxWidth = width
        this.boxHeight = height
        this.radius = radius
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(boxWidth, boxHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        paintSurface(ctx.renderer, frame, selineTheme().palette.surfaceHover, radius)
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

/** 图书卡骨架：封面块 + 标题条 + 作者条。 */
class SkeletonBookCard <: Widget {
    private var frame = Rect.zero()

    init() {
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
        paintSurface(ctx.renderer, frame, palette.surfaceRaised, BOOK_CARD_RADIUS)
        let coverW = frame.w - BOOK_CARD_PAD * 2.0
        let coverH = coverW / BOOK_COVER_ASPECT
        let cover = Rect(frame.x + BOOK_CARD_PAD, frame.y + BOOK_CARD_PAD, coverW, coverH)
        paintSurface(ctx.renderer, cover, palette.surfaceHover,
            BOOK_CARD_RADIUS - BOOK_CARD_PAD)
        let textX = cover.x
        let textY = cover.y + cover.h + 10.0
        paintSurface(ctx.renderer, Rect(textX, textY, coverW * 0.72, 12.0),
            palette.surfaceHover, 4.0)
        paintSurface(ctx.renderer, Rect(textX, textY + 22.0, coverW * 0.42, 10.0),
            palette.surfaceHover, 4.0)
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

/** 书籍网格骨架。 */
func bookSkeletonGrid(count!: Int64 = 12): Unit {
    AdaptiveGrid(180.0, minColumns: 2, maxColumns: 6) {
        var index: Int64 = 0
        while (index < count) {
            SkeletonBookCard()
            index += 1
        }
    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
}

/** 书单卡骨架：左侧三张预览块 + 右侧文字条。 */
class SkeletonBooklistCard <: Widget {
    private var frame = Rect.zero()

    init() {
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
        let palette = selineTheme().palette
        paintSurface(ctx.renderer, frame, palette.surfaceRaised, BOOKLIST_CARD_RADIUS)
        var index: Int64 = 0
        while (index < 3) {
            let x = frame.x + BOOKLIST_CARD_PAD +
                Float32(index) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP)
            paintSurface(ctx.renderer,
                Rect(x, frame.y + BOOKLIST_CARD_PAD, BOOKLIST_PREVIEW_W, BOOKLIST_PREVIEW_H),
                palette.surfaceHover, 6.0)
            index += 1
        }
        let textX = frame.x + BOOKLIST_CARD_PAD +
            Float32(3) * (BOOKLIST_PREVIEW_W + BOOKLIST_PREVIEW_GAP) + 4.0
        let textW = max(Float32(40.0), frame.right() - BOOKLIST_CARD_PAD - textX)
        paintSurface(ctx.renderer, Rect(textX, frame.y + 14.0, textW * 0.7, 14.0),
            palette.surfaceHover, 4.0)
        paintSurface(ctx.renderer, Rect(textX, frame.y + 38.0, textW * 0.45, 11.0),
            palette.surfaceHover, 4.0)
        paintSurface(ctx.renderer, Rect(textX, frame.y + 58.0, textW * 0.8, 11.0),
            palette.surfaceHover, 4.0)
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

/** 书单网格骨架。 */
func booklistSkeletonGrid(count!: Int64 = 6): Unit {
    AdaptiveGrid(360.0, minColumns: 2, maxColumns: 3) {
        var index: Int64 = 0
        while (index < count) {
            SkeletonBooklistCard()
            index += 1
        }
    }.spacing(SELINE_SPACE_MD, SELINE_SPACE_MD)
}

/** 详情页「简介」骨架：标题条 + 三行正文条（按可用宽度百分比收缩）。 */
/** 简介骨架（页面自己画「简介」标题，这里只画那一整块）。 */
func descriptionSkeleton(): Unit {
    DescriptionSkeletonBlock(DETAIL_DESC_H)
}

/** 简介骨架：**一整块**（简介本身是一块连续正文，不该拆成多张卡）。 */
class DescriptionSkeletonBlock <: Widget {
    private let blockHeight: Float32
    private var frame = Rect.zero()

    init(height: Float32) {
        this.blockHeight = height
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, blockHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let palette = selineTheme().palette
        paintSurface(ctx.renderer, frame, palette.surfaceRaised, 8.0)
        // 块内部只画几条淡淡的行，表示"这里是一段正文"
        let innerX = frame.x + 12.0
        let innerW = max(0.0, frame.w - 24.0)
        var index: Int64 = 0
        while (index < 8) {
            let y = frame.y + 14.0 + Float32(index) * 26.0
            if (y + 10.0 > frame.bottom() - 10.0) {
                break
            }
            let ratio: Float32 = if (index == 7) { 0.42 } else { 0.94 }
            paintSurface(ctx.renderer, Rect(innerX, y, innerW * ratio, 10.0),
                palette.surfaceHover, 4.0)
            index += 1
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

/** 按宽度比例画一条骨架（不能预知可用宽度，所以只能按 frame 百分比）。 */
class CommentSkeletonLine <: Widget {
    private let widthRatio: Float32
    private let lineHeight: Float32
    private var frame = Rect.zero()

    init(widthRatio!: Float32, height!: Float32) {
        this.widthRatio = widthRatio
        this.lineHeight = height
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, lineHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        paintSurface(ctx.renderer,
            Rect(frame.x, frame.y, frame.w * widthRatio, frame.h),
            selineTheme().palette.surfaceHover, 4.0)
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

/** 评论区骨架：几张浅色评论卡（作者条 + 正文条），高度接近真实评论行。 */
class SkeletonCommentRow <: Widget {
    private var frame = Rect.zero()

    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 64.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let palette = selineTheme().palette
        paintSurface(ctx.renderer, frame, palette.surfaceRaised, 8.0)
        let innerX = frame.x + 12.0
        let innerW = max(0.0, frame.w - 24.0)
        paintSurface(ctx.renderer, Rect(innerX, frame.y + 14.0, innerW * 0.18, 10.0),
            palette.surfaceHover, 4.0)
        paintSurface(ctx.renderer, Rect(innerX, frame.y + 34.0, innerW * 0.72, 10.0),
            palette.surfaceHover, 4.0)
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

/** 评论骨架：3 行。 */
func commentSkeleton(rows!: Int64 = 3): Unit {
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        var index: Int64 = 0
        while (index < rows) {
            SkeletonCommentRow()
            index += 1
        }
    }.hug().fillWidth()
}