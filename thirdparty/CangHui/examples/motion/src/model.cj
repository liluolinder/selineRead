/*
 * 缓动示例状态：轨道列表（持久，含各自的 Animator）与播放开关。
 *
 * 播放开关翻转即让所有轨道的 Animator 同时朝 1（播放）或 0（复位）缓动；轨道对象在模型里持久存在，
 * 以便逐帧累积动画时间。
 */
package chui_motion

import chui.State

class MotionModel {
    let tracks: Array<EasingTrack> = buildTracks()
    let playing = State<Bool>(false)

    // 翻转播放状态：所有轨道随之朝新目标缓动。
    func toggle(): Unit {
        playing.value = !playing.value
    }

    // 播放按钮文案：播放中显示“复位”，否则“播放”。
    func playLabel(): String {
        if (playing.value) {
            "复位"
        } else {
            "播放"
        }
    }
}
