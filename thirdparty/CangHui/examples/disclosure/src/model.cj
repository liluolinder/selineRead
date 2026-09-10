/*
 * 折叠问答状态：当前展开的条目下标集合（可多条同时展开）。
 *
 * 切换以“复制集合 + 增删 + 整体重赋”触发 State 通知；是否展开是集合的纯查询。
 */
package chui_disclosure

import chui.State
import std.collection.HashSet

class DisclosureModel {
    let items: Array<FaqItem> = FAQ
    let open: State<HashSet<Int64>>

    init() {
        // 默认展开第一条，便于首屏即见内容（也让静态快照有展开态）。
        let initial = HashSet<Int64>()
        initial.add(0)
        this.open = State<HashSet<Int64>>(initial)
    }

    func isOpen(index: Int64): Bool {
        open.value.contains(index)
    }

    // 切换第 index 条的展开状态：复制集合、增删、整体重赋以触发重建。
    func toggle(index: Int64): Unit {
        let next = HashSet<Int64>()
        for (x in open.value) {
            next.add(x)
        }
        if (next.contains(index)) {
            next.remove(index)
        } else {
            next.add(index)
        }
        open.value = next
    }

    // 已展开条数（标题栏摘要用）。
    func openCount(): Int64 {
        open.value.size
    }

    // 是否全部展开。
    func allOpen(): Bool {
        open.value.size == items.size
    }

    // 标题栏按钮文案：全开时给「全部收起」，否则给「全部展开」。
    func expandLabel(): String {
        if (allOpen()) {
            "全部收起"
        } else {
            "全部展开"
        }
    }

    // 全部展开/收起：未全开时展开全部，已全开时清空。
    func toggleAll(): Unit {
        let next = HashSet<Int64>()
        if (!allOpen()) {
            for (i in 0..items.size) {
                next.add(i)
            }
        }
        open.value = next
    }
}
