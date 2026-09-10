/*
 * 发布说明状态：类别过滤、议题链接的打开计数与最近一次打开的议题号。
 *
 * 可见条目由过滤下标纯函数派生；点击链接只改状态，具体反馈由底部状态条渲染。
 */
package chui_richtext

import chui.State
import std.collection.ArrayList

class RichTextModel {
    let sections: Array<ReleaseSection> = RELEASES
    let filter = State<Int64>(0)
    let openedCount = State<Int64>(0)
    let lastIssue = State<String>("")

    // 某版本区块在当前过滤下的可见条目（保持原序）。
    func visibleNotes(section: ReleaseSection): Array<ReleaseNote> {
        let out = ArrayList<ReleaseNote>()
        for (note in section.notes) {
            if (matchesFilter(note, filter.value)) {
                out.add(note)
            }
        }
        out.toArray()
    }

    // 当前过滤下所有区块的可见条目总数（空态提示用）。
    func visibleTotal(): Int64 {
        var total: Int64 = 0
        for (section in sections) {
            total += visibleNotes(section).size
        }
        total
    }

    // 议题链接点击：计数并记录最近一次。
    func openIssue(issue: String): Unit {
        openedCount.value = openedCount.value + 1
        lastIssue.value = issue
    }
}
