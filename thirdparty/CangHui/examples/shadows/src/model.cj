/*
 * 阴影对比示例状态：当前层级。
 *
 * level 由 Stepper 绑定并钳到 1..6（与 elevation/keyAmbient 预设的定义域一致）；clampLevel 为纯函数可测。
 */
package chui_shadows

import chui.State

// 层级钳到预设定义域 1..6。
func clampLevel(value: Int64): Int64 {
    if (value < 1) {
        1
    } else if (value > 6) {
        6
    } else {
        value
    }
}

class ShadowsModel {
    let level = State<Int64>(3)

    func current(): Int64 {
        clampLevel(level.value)
    }

    func statusText(): String {
        "层级 e${current()}：单层是一团均匀的晕，双层由宽而淡的环境光叠上窄而深的方向光——深度感来自两者的差"
    }
}
