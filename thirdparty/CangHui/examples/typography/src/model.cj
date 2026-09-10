/*
 * 字体样式状态：四个独立开关（粗体/斜体/下划线/删除线）。
 *
 * 当前合成样式是四个开关的纯函数派生；Chip 直接绑定各开关的 State（State 即 Bindable）。
 */
package chui_typography

import chui.{FontStyle, State}

class TypographyModel {
    let bold = State<Bool>(true)
    let italic = State<Bool>(false)
    let underline = State<Bool>(false)
    let strikethrough = State<Bool>(false)

    // 由四个开关合成的当前样式，供预览逐档渲染。
    func style(): FontStyle {
        composeStyle(bold.value, italic.value, underline.value, strikethrough.value)
    }

    // 当前样式的中文摘要，显示在页脚。
    func summary(): String {
        styleSummary(style())
    }
}
