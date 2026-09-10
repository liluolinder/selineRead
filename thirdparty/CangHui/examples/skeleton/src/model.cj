/*
 * 骨架屏示例状态：加载完成与否 + 共享的呼吸脉冲。
 *
 * Pulse 由模型持有（普通对象即可跨帧存活，同 Spring 的用法），全部骨架行共享一个脉冲同步呼吸；
 * loaded 翻转即在骨架与真实内容间切换。
 */
package chui_skeleton

import chui.{Easing, Pulse, State}

class SkeletonModel {
    let loaded = State<Bool>(false)
    // 900ms 一息、往复呼吸、正弦缓动——柔和不扎眼。
    let pulse = Pulse(period: 900, autoreverse: true, easing: Easing.EaseInOutSine)

    func toggle(): Unit {
        loaded.value = !loaded.value
    }

    func buttonLabel(): String {
        if (loaded.value) {
            "重新加载"
        } else {
            "加载完成"
        }
    }

    func statusText(): String {
        if (loaded.value) {
            "内容已就位；点「重新加载」回到骨架态"
        } else {
            "骨架行由一个共享 Pulse 驱动同步呼吸，仅加载态请求续帧——内容就位后界面回到零帧空闲"
        }
    }
}
