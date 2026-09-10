/*
 * 虚线边框状态：实线段长、间隔长、圆角（均可调）。
 *
 * 预览框由这三项现算；Stepper 直接绑定 State。
 */
package chui_dashed

import chui.State

class DashedModel {
    let dash = State<Int64>(7)
    let gap = State<Int64>(5)
    let radius = State<Int64>(14)

    func describe(): String {
        describeDash(dash.value, gap.value, radius.value)
    }
}
