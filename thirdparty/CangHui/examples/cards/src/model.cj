/*
 * 样式卡片状态：阴影层级、圆角、边框开关。
 *
 * 预览卡片与描述都由这三项现算；Stepper/Switch 直接绑定 State（State 即 Bindable）。
 */
package chui_cards

import chui.State

class CardsModel {
    let elevation = State<Int64>(3) // 0 = 无阴影
    let radius = State<Int64>(14)
    let borderOn = State<Bool>(true)

    // 当前样式的一句话描述。
    func describe(): String {
        describeStyle(elevation.value, radius.value, borderOn.value)
    }
}
