/*
 * 字体样式示例的类型化数据与纯逻辑。
 *
 * 字号阶梯、样式参考表都是不可变数据；样式合成与样式摘要是纯函数，便于单测且与视图无关。
 */
package chui_typography

import chui.{FontSizes, FontStyle}
import std.collection.ArrayList

// 字号阶梯上的一档：展示名 + 字号（fp）。
struct TypeStep {
    let name: String
    let size: Float32

    init(name: String, size: Float32) {
        this.name = name
        this.size = size
    }
}

// 从大到小的字号阶梯，取自框架标准字号，供实时预览逐档渲染当前样式。
let TYPE_SCALE: Array<TypeStep> = [
    TypeStep("Display", FontSizes.DISPLAY),
    TypeStep("Title", FontSizes.TITLE),
    TypeStep("Body", FontSizes.BODY),
    TypeStep("Caption", FontSizes.CAPTION)
]

// 样式参考表的一行：中文名 + 对应样式，静态展示每种样式的样子（不随开关变化）。
struct StyleSample {
    let label: String
    let style: FontStyle

    init(label: String, style: FontStyle) {
        this.label = label
        this.style = style
    }
}

let STYLE_REFERENCE: Array<StyleSample> = [
    StyleSample("常规 Regular", FontStyle.regular),
    StyleSample("粗体 Bold", FontStyle(bold: true)),
    StyleSample("斜体 Italic", FontStyle(italic: true)),
    StyleSample("下划线 Underline", FontStyle(underline: true)),
    StyleSample("删除线 Strikethrough", FontStyle(strikethrough: true)),
    StyleSample("粗斜体 Bold Italic", FontStyle(bold: true, italic: true))
]

// 由四个开关合成一个字体样式。纯函数，模型与测试共用。
func composeStyle(bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool): FontStyle {
    FontStyle(bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
}

// 字号阶梯每档的说明标签，如「Body · 15fp」。
func stepCaption(step: TypeStep): String {
    "${step.name} · ${Int64(step.size)}fp"
}

// 样式的中文摘要，如「粗体 · 斜体」；无任何样式时为「常规」。
func styleSummary(style: FontStyle): String {
    let parts = ArrayList<String>()
    if (style.bold) {
        parts.add("粗体")
    }
    if (style.italic) {
        parts.add("斜体")
    }
    if (style.underline) {
        parts.add("下划线")
    }
    if (style.strikethrough) {
        parts.add("删除线")
    }
    if (parts.isEmpty()) {
        return "常规"
    }
    var out = parts[0]
    for (i in 1..parts.size) {
        out += " · " + parts[i]
    }
    out
}
