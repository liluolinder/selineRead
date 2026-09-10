/*
 * 链接示例状态：最近点击的链接文本。
 *
 * 点任一链接片段即把它设为“已选择”，显示在底部详情条。
 */
package chui_links

import chui.State

class LinksModel {
    let notices: Array<Notice> = NOTICES
    let selected = State<?String>(None)

    // 点击链接：记录其文本。
    func select(label: String): Unit {
        selected.value = Some(label)
    }

    // 详情条文案：已选择的链接，或提示。
    func detailText(): String {
        match (selected.value) {
            case Some(label) => "已选择：${label}"
            case None => "点上方 ${linkCount(notices)} 个彩色链接中的任意一个，这里显示你点了什么"
        }
    }
}
