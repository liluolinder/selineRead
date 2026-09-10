/*
 * 交错入场示例状态：是否展开、交错步进档位。
 *
 * shown 翻转即整组入场/退场，每行按 delayFor(i) 依次错开；stepIndex 选交错步进档位。
 * 注意：Reveal 的 duration/easing/delay 在其 Animator 首次创建时读取，故换档要让 key 随步进变化（见 views）。
 */
package chui_stagger

import chui.State

class StaggerModel {
    let items: Array<Item> = ITEMS
    let shown = State<Bool>(true)
    // 默认「轻交错」，一进来就能看出错落。
    let stepIndex = State<Int64>(1)

    /** 当前交错步进（ms）。 */
    func step(): Int64 {
        let i = stepIndex.value
        if (i < 0 || i >= STAGGER_STEPS.size) {
            return STAGGER_STEPS[0]
        }
        STAGGER_STEPS[i]
    }

    /** 第 index 行的入场等待（ms）。 */
    func delayFor(index: Int64): UInt64 {
        staggerDelay(index, step())
    }

    /** 整组入场/退场耗时（ms）。 */
    func totalMs(): Int64 {
        cascadeTotalMs(items.size, step(), REVEAL_MS)
    }

    func toggle(): Unit {
        shown.value = !shown.value
    }

    /** 底部状态条文案。 */
    func statusText(): String {
        let s = step()
        if (s <= 0) {
            return "${items.size} 行同时入场，整组 ${totalMs()}ms 完成"
        }
        "${items.size} 行 × ${s}ms 交错，整组 ${totalMs()}ms 完成"
    }
}
