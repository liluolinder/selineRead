/*
 * 缓动示例的类型化数据与纯逻辑。
 *
 * 每条轨道绑定一种缓动曲线与一个 Animator（同一时长），播放时并排推进以对比曲线的运动分布。
 * 标记点的横坐标是缓动值与轨道两端的纯函数，便于单测且与绘制无关。
 */
package chui_motion

import chui.{Animator, Easing}

// 所有轨道共享的时长（毫秒），从而同时开始、同时到达，差别只在运动分布。
let TRACK_DURATION: UInt64 = 900

// 一条对比轨道：曲线名 + 该曲线的 Animator（从 0 缓动到 1）。Animator 可变，故用类。
class EasingTrack {
    let label: String
    let animator: Animator

    init(label: String, easing: Easing) {
        this.label = label
        this.animator = Animator(0.0, duration: TRACK_DURATION, easing: easing)
    }
}

// 本示例对比的缓动曲线：线性、二次/三次的 In/Out/InOut、正弦、回弹（overshoot）与 CSS ease 贝塞尔。
func buildTracks(): Array<EasingTrack> {
    [
        EasingTrack("Linear", Easing.Linear),
        EasingTrack("In · Quad", Easing.EaseInQuad),
        EasingTrack("Out · Quad", Easing.EaseOutQuad),
        EasingTrack("InOut · Cubic", Easing.EaseInOutCubic),
        EasingTrack("Out · Sine", Easing.EaseOutSine),
        EasingTrack("Out · Back", Easing.EaseOutBack),
        EasingTrack("CSS ease", Easing.CubicBezier(0.25, 0.1, 0.25, 1.0))
    ]
}

// 缓动值（0..1，回弹会略超 1）映射到轨道两端之间的横坐标：0→x0、1→x1，超 1 则越过 x1（回弹的过冲）。
func markerX(value: Float32, x0: Float32, x1: Float32): Float32 {
    x0 + value * (x1 - x0)
}
