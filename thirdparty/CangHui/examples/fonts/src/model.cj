/*
 * 字体加载状态：样张选用哪种字体、是否加粗。
 *
 * 选中字体名是选中下标的纯函数派生；SegmentedControl/Chip 直接绑定 State（State 即 Bindable）。
 */
package chui_fonts

import chui.State

class FontsModel {
    let faces: Array<TypeFace> = TYPEFACES
    let selected = State<Int64>(1) // 默认选中衬线，凸显与系统字体的差异
    let bold = State<Bool>(false)

    // 样张当前选用的字体注册名（None = 系统默认）。
    func currentFace(): ?String {
        faceName(faces, selected.value)
    }

    // 供 SegmentedControl 使用的字体标签数组。
    func labels(): Array<String> {
        let out = Array<String>(faces.size, {i => faces[i].label})
        out
    }
}
