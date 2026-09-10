/*
 * 问答折叠行：自绘的可交互标题行（chevron 指示 + 问题文本）。
 *
 * 演示应用层自定义控件接入框架交互体系的完整姿势：构造期 focusableControlIdentity 进 Tab 序，
 * handle 里 claimHoverIfInside 认领悬停光标、点击或 Enter/空格切换，draw 里按 isHovered 画
 * 悬停底、按 showFocusRing 画焦点环——与内置控件同一套协议，无需任何框架内部权限。
 */
package chui_disclosure

import chui.{CursorShape, FontSizes, Key, MouseButton, Pen, Rect, Size, UiContext, UiEvent, Widget,
    claimHoverIfInside, drawFocusRing, emit, focusableControlIdentity}

// 行高、chevron 中心距左缘、问题文本起点（答案区左缩进与文本起点对齐）。
let FAQ_ROW_H: Float32 = 46.0
let FAQ_CHEVRON_X: Float32 = 20.0
let FAQ_TEXT_X: Float32 = 40.0

class FaqRow <: Widget {
    private let question: String
    private let open: Bool
    private let onToggle: () -> Unit
    private let id: String
    private var frame = Rect.zero()

    init(index: Int64, question: String, open: Bool, onToggle: () -> Unit) {
        this.question = question
        this.open = open
        this.onToggle = onToggle
        this.id = focusableControlIdentity("FaqRow:${index}")
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, FAQ_ROW_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (ctx.isHovered(id)) {
            ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        if (ctx.showFocusRing(id)) {
            drawFocusRing(ctx, frame, ctx.theme.smallRadius)
        }
        drawChevron(ctx, frame.x + FAQ_CHEVRON_X, frame.centerY())
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(question, frame.x + FAQ_TEXT_X, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (frame.contains(x, y)) {
                ctx.focus(id)
                onToggle()
                return true
            }
            case UiEvent.KeyDown(Key.Enter, _) => if (ctx.hasFocus(id)) {
                onToggle()
                return true
            }
            case UiEvent.KeyDown(Key.Space, _) => if (ctx.hasFocus(id)) {
                onToggle()
                return true
            }
            case _ => ()
        }
        false
    }

    // 收起时右指、展开时下指的 chevron，笔画取主题次要文字色。
    private func drawChevron(ctx: UiContext, cx: Float32, cy: Float32): Unit {
        let arm: Float32 = 4.5
        let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
        if (open) {
            ctx.renderer.strokeLine(cx - arm, cy - arm * 0.5, cx, cy + arm * 0.5, pen)
            ctx.renderer.strokeLine(cx, cy + arm * 0.5, cx + arm, cy - arm * 0.5, pen)
        } else {
            ctx.renderer.strokeLine(cx - arm * 0.5, cy - arm, cx + arm * 0.5, cy, pen)
            ctx.renderer.strokeLine(cx + arm * 0.5, cy, cx - arm * 0.5, cy + arm, pen)
        }
    }
}
