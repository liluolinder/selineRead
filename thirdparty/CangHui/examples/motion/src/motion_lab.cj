/*
 * 自定义动画 Widget：并排绘制各缓动轨道并逐帧推进。
 *
 * 每帧 draw 里对每条轨道调用 animator.animate(ctx, target:)——推进一帧并在未静止时请求下一帧，
 * 从而在即时模式 + 脏帧跳过下驱动连续动画（与 ProgressRing/Toaster 同路径）。标记点横坐标由缓动值决定，
 * 曲线不同则同一时刻位置不同，直观对比运动分布。
 */
package chui_motion

import chui.{FontSizes, Pen, Rect, Size, UiContext, UiEvent, Widget, emit}

private let ROW_H: Float32 = 46.0
private let LABEL_W: Float32 = 132.0
private let MARKER_R: Float32 = 9.0
// 右端留出的过冲余量，让回弹曲线越过终点的部分仍在轨道内可见。
private let OVERSHOOT_ROOM: Float32 = 22.0

class MotionLab <: Widget {
    private let tracks: Array<EasingTrack>
    private let playing: Bool
    private var frame = Rect.zero()

    init(tracks: Array<EasingTrack>, playing: Bool) {
        this.tracks = tracks
        this.playing = playing
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, Float32(tracks.size) * ROW_H + 8.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (playing) {
            1.0
        } else {
            0.0
        }
        let theme = ctx.theme
        let x0 = frame.x + LABEL_W
        let x1 = frame.right() - MARKER_R - OVERSHOOT_ROOM
        var i = 0
        while (i < tracks.size) {
            let track = tracks[i]
            // Advance this track a frame and request the next while it is still moving.
            let value = track.animator.animate(ctx, target: goal)
            let cy = frame.y + Float32(i) * ROW_H + ROW_H / 2.0
            ctx.renderer.text(track.label, frame.x, cy - 8.0, theme.mutedText, pointSize: FontSizes.CAPTION)
            // The baseline track, then the travelled portion, then the marker at the eased position.
            ctx.renderer.strokeLine(x0, cy, x1, cy, Pen(width: 3.0, color: theme.panelEdge))
            let mx = markerX(value, x0, x1)
            if (mx > x0 + 0.5) {
                ctx.renderer.strokeLine(x0, cy, mx, cy, Pen(width: 3.0, color: theme.accentSoft))
            }
            ctx.renderer.fillCircle(mx, cy, MARKER_R, theme.accent)
            i += 1
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
