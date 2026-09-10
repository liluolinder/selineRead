/*
 * 渐变示例状态：选中的预设下标与方向（纵向/横向）。
 *
 * 当前预设与合成的 Gradient 都由这两项派生；Stepper/SegmentedControl 直接绑定 State。
 */
package chui_gradients

import chui.{Gradient, State}

class GradientsModel {
    let presets: Array<GradientPreset> = PRESETS
    let selected = State<Int64>(0)
    let vertical = State<Bool>(true)

    func current(): GradientPreset {
        presets[clampPreset(selected.value)]
    }

    // 当前预设 + 方向合成的渐变。
    func gradient(): Gradient {
        gradientFor(selected.value, vertical.value)
    }

    func directionText(): String {
        directionLabel(vertical.value)
    }
}
