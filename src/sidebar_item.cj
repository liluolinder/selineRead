/*
 * 侧栏的一行：图标 + 可选文字 + 悬停/选中底色。
 *
 * 行的排版宽度恒为 `RAIL_EXPANDED`（220），外层裁切到当前可见宽度；
 * 行内任何 x 都从 `frame` 推出，不写死整行宽。
 */
package seline_read

import chui.*
import seline_ui.*

/** 侧栏行。 */
class SidebarItem <: Widget {
    private let glyph: String
    private let title: String
    private let expanded: Bool
    private let selected: Bool
    private let onTap: () -> Unit
    private let id: String
    private let rowHeight: Float32
    /** 可选：把自己每帧的矩形报给调用方（主题按钮要用真实位置做辐射原点）。 */
    private let onFrame: (Rect) -> Unit
    private var frame = Rect.zero()
    private var hot = false

    init(glyph: String, title: String, expanded: Bool, selected: Bool,
        onTap: () -> Unit, height!: Float32 = SIDEBAR_ROW_HEIGHT,
        onFrame!: (Rect) -> Unit = {_ => ()}) {
        this.onFrame = onFrame
        this.glyph = glyph
        this.title = title
        this.expanded = expanded
        this.selected = selected
        this.onTap = onTap
        this.rowHeight = height
        this.id = focusableControlIdentity("SidebarItem:${title}")
        emit(this)
    }

    /** 行只关心自己多高；宽度恒为展开宽度，可见部分由外层裁切。 */
    public func measure(_: UiContext, _: Size): Size {
        Size(RAIL_EXPANDED, rowHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
        onFrame(rect)
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let t = railT()
        let visible = railVisibleWidth()
        let blockH = rowHeight - 6.0
        let collapsedW = RAIL_COLLAPSED - 16.0
        let expandedW = RAIL_EXPANDED - SIDEBAR_INSET * 2.0
        let blockW = collapsedW + (expandedW - collapsedW) * t
        let blockX = frame.x + (visible - blockW) * 0.5
        let block = Rect(blockX, frame.y + 3.0, blockW, blockH)
        let radius = theme.radiusSmall + (theme.radiusControl - theme.radiusSmall) * t
        if (selected) {
            ctx.renderer.fillPerCornerRoundedRect(block, palette.accentSoft,
                topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: radius)
        } else if (hot) {
            ctx.renderer.fillPerCornerRoundedRect(block, palette.surfaceHover,
                topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: radius)
        }
        if (selected && t > 0.55) {
            ctx.renderer.fillPerCornerRoundedRect(
                Rect(frame.x + 2.0, frame.y + 8.0, 3.0, rowHeight - 16.0),
                palette.accent, topLeft: 1.5, topRight: 1.5, bottomRight: 1.5, bottomLeft: 1.5)
        }
        let ink = if (selected) {
            palette.accent
        } else if (hot) {
            palette.text
        } else {
            palette.textMuted
        }
        let iconSide: Float32 = 20.0
        let iconX = frame.x + (RAIL_COLLAPSED - iconSide) * 0.5
        drawGlyph(ctx.renderer, glyph,
            Rect(iconX, frame.centerY() - iconSide * 0.5, iconSide, iconSide), ink, 1.0)
        if (expanded) {
            let fade = max(0.0, (t - 0.35) / 0.65)
            if (fade > 0.02) {
                let textX = iconX + iconSide + 12.0
                let textW = max(0.0, frame.right() - SIDEBAR_INSET - textX)
                paintText(ctx.renderer, title, Rect(textX, frame.y, textW, rowHeight),
                    ink.withAlpha(Int64(255.0 * fade)), theme.fontLabel,
                    align: SelineTextAlign.Leading,
                    style: selineFontStyle(bold: selected),
                    family: theme.fontFamily)
            }
        }
    }

    private func hit(x: Float32, y: Float32): Bool {
        frame.contains(x, y) && x < frame.x + railVisibleWidth()
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                hot = hit(x, y)
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                hit(x, y)
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (hit(x, y)) {
                    onTap()
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

    public func acceptsStretch(axis: Axis): Bool {
        match (axis) {
            case Axis.Horizontal => false
            case Axis.Vertical => true
        }
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

/**
 * 侧栏底部的账号入口（本轮是占位：登录功能下一轮接入）。
 *
 * 与 seline_bili 的 AccountChip 占同一位置、同一交互（整块可点，点开设置页）。
 */
class SidebarAccountChip <: Widget {
    private let state: AppState
    private let expanded: Bool
    private let selected: Bool
    private let id: String
    private var frame = Rect.zero()
    private var hot = false

    init(state: AppState, expanded: Bool, selected: Bool) {
        this.state = state
        this.expanded = expanded
        this.selected = selected
        this.id = focusableControlIdentity("SidebarAccountChip")
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(RAIL_EXPANDED, 52.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let t = railT()
        let visible = railVisibleWidth()
        let blockW = RAIL_COLLAPSED - 16.0 + ((RAIL_EXPANDED - SIDEBAR_INSET * 2.0) -
            (RAIL_COLLAPSED - 16.0)) * t
        let block = Rect(frame.x + (visible - blockW) * 0.5, frame.y + 4.0, blockW,
            frame.h - 8.0)
        if (selected) {
            paintSurface(ctx.renderer, block, palette.accentSoft, theme.radiusControl)
        } else if (hot) {
            paintSurface(ctx.renderer, block, palette.surfaceHover, theme.radiusControl)
        }
        let avatarSide: Float32 = 28.0
        let avatarX = frame.x + (RAIL_COLLAPSED - avatarSide) * 0.5
        let avatar = Rect(avatarX, frame.centerY() - avatarSide * 0.5, avatarSide, avatarSide)
        ctx.renderer.fillPerCornerRoundedRect(avatar, palette.accentSoft,
            topLeft: avatarSide * 0.5, topRight: avatarSide * 0.5,
            bottomRight: avatarSide * 0.5, bottomLeft: avatarSide * 0.5)
        drawGlyph(ctx.renderer, "person_fill",
            centeredSquare(avatar.centerX(), avatar.centerY(), 16.0), palette.accent, 1.0)
        if (expanded) {
            let fade = max(0.0, (t - 0.35) / 0.65)
            if (fade > 0.02) {
                let textX = avatarX + avatarSide + 10.0
                let textW = max(0.0, frame.right() - SIDEBAR_INSET - textX)
                let title = if (state.loggedIn.value) {
                    state.accountName.value
                } else {
                    "未登录"
                }
                paintText(ctx.renderer, title,
                    Rect(textX, frame.y, textW, frame.h),
                    palette.text.withAlpha(Int64(255.0 * fade)), theme.fontLabel,
                    family: theme.fontFamily)
            }
        }
    }

    private func hit(x: Float32, y: Float32): Bool {
        frame.contains(x, y) && x < frame.x + railVisibleWidth()
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                hot = hit(x, y)
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                hit(x, y)
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (hit(x, y)) {
                    state.tabSelectFromRail(TAB_ACCOUNT)
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

    public func acceptsStretch(axis: Axis): Bool {
        match (axis) {
            case Axis.Horizontal => false
            case Axis.Vertical => true
        }
    }

    public func focusableId(): ?String {
        Some(id)
    }
}
