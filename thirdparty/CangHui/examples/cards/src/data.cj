/*
 * 样式卡片示例的类型化数据与纯逻辑。
 *
 * 卡片的填充/边框/阴影色是固定令牌；样式描述（阴影层级、圆角、边框开关拼成一句）是纯函数，便于单测。
 */
package chui_cards

import chui.Color

// elevation 阶梯参考展示的层级。
let RAMP_LEVELS: Array<Int64> = [1, 2, 3, 4, 5, 6]

// 卡片令牌：白色填充、浅灰边框、偏冷的半透明阴影。
let CARD_FILL = Color.rgb(255, 255, 255)
let CARD_BORDER = Color.rgb(206, 212, 222)
let CARD_SHADOW = Color.rgba(28, 40, 66, 74)

// 一句话描述当前样式：阴影层级（0 为无阴影）、圆角、边框开关。
func describeStyle(elevation: Int64, radius: Int64, borderOn: Bool): String {
    let shadowPart = if (elevation <= 0) {
        "无阴影"
    } else {
        "elevation ${elevation}"
    }
    let borderPart = if (borderOn) {
        "边框开"
    } else {
        "边框关"
    }
    "${shadowPart} · 圆角 ${radius}vp · ${borderPart}"
}
