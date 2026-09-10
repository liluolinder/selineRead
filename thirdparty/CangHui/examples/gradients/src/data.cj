/*
 * 渐变示例的类型化数据与纯逻辑。
 *
 * 预设是一组两色渐变（起止色 + 名称）；由预设与方向合成 Gradient、下标钳位都是纯函数，便于单测。
 */
package chui_gradients

import chui.{Color, Gradient}

// 一个渐变预设：名称与两个色标。
struct GradientPreset {
    let name: String
    let start: Color
    let end: Color

    init(name: String, start: Color, end: Color) {
        this.name = name
        this.start = start
        this.end = end
    }
}

// 一组现代感的两色渐变预设。
let PRESETS: Array<GradientPreset> = [
    GradientPreset("Dusk", Color.rgb(94, 114, 235), Color.rgb(140, 82, 205)),
    GradientPreset("Sunset", Color.rgb(250, 112, 154), Color.rgb(254, 197, 74)),
    GradientPreset("Ocean", Color.rgb(33, 147, 176), Color.rgb(109, 213, 237)),
    GradientPreset("Ember", Color.rgb(240, 96, 96), Color.rgb(255, 186, 120)),
    GradientPreset("Forest", Color.rgb(19, 149, 138), Color.rgb(84, 217, 128)),
    GradientPreset("Grape", Color.rgb(126, 46, 190), Color.rgb(214, 120, 232))
]

// 把下标钳到合法范围（越界回绕到端点）。
func clampPreset(index: Int64): Int64 {
    if (index < 0) {
        0
    } else if (index >= PRESETS.size) {
        PRESETS.size - 1
    } else {
        index
    }
}

// 由预设下标与方向合成一个 Gradient（纵向 = 顶到底，横向 = 左到右）。
func gradientFor(index: Int64, vertical: Bool): Gradient {
    let preset = PRESETS[clampPreset(index)]
    Gradient(start: preset.start, end: preset.end, vertical: vertical)
}

// 方向的中文标签。
func directionLabel(vertical: Bool): String {
    if (vertical) {
        "纵向（顶 → 底）"
    } else {
        "横向（左 → 右）"
    }
}
