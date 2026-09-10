/*
 * 自定义骨架行 Widget：头像圆 + 两条圆角占位条，底色随共享 Pulse 在基色与亮色间呼吸。
 *
 * 每帧 draw 里 pulse.animate(ctx) 推进相位并请求下一帧（脉冲永不静止），再用 Color.lerp 取当帧底色——
 * 这是即时模式 + 脏帧跳过下驱动常亮动画的标准路径（同 MotionLab/Toaster）。占位条宽度比例来自纯函数，
 * 长短交错更像真实文字。
 */
package chui_skeleton

import chui.{Pulse, Rect, Size, UiContext, UiEvent, Widget, emit}

private let ROW_H: Float32 = 58.0
private let AVATAR_R: Float32 = 17.0
private let BAR_H: Float32 = 12.0
private let BAR_RADIUS: Float32 = 6.0
private let GAP: Float32 = 12.0

class SkeletonRow <: Widget {
    private let pulse: Pulse
    private let row: Int64
    private var frame = Rect.zero()

    init(pulse: Pulse, row: Int64) {
        this.pulse = pulse
        this.row = row
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, ROW_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false // 纯展示占位，不消费任何事件
    }

    public func draw(ctx: UiContext): Unit {
        // 推进共享脉冲并请求下一帧；Pulse 按帧戳去重，多行共用同一实例时每帧只推进一次、呼吸同步。
        let t = pulse.animate(ctx)
        let base = ctx.theme.field
        let glow = ctx.theme.fieldActive
        let shade = base.lerp(glow, t)
        let cy = frame.y + ROW_H / 2.0
        // 头像圆。
        ctx.renderer.fillCircle(frame.x + AVATAR_R, cy, AVATAR_R, shade)
        // 标题条与摘要条，宽度比例按行号交错。
        let barX = frame.x + AVATAR_R * 2.0 + GAP
        let room = frame.right() - barX
        let titleY = cy - BAR_H - 3.0
        let lineY = cy + 3.0
        ctx.renderer.fillRoundedRect(Rect(barX, titleY, room * titleFraction(row), BAR_H), BAR_RADIUS, shade)
        ctx.renderer.fillRoundedRect(Rect(barX, lineY, room * lineFraction(row), BAR_H), BAR_RADIUS, shade)
    }
}
