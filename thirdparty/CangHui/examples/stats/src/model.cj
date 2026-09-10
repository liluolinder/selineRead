/*
 * 数据看板状态：选中的时段（今日/本周/本月）。
 *
 * 当前指标集由时段派生；SegmentedControl 直接绑定 State。
 */
package chui_stats

import chui.State

class StatsModel {
    let period = State<Int64>(0)

    func stats(): Array<Stat> {
        statsFor(period.value)
    }
}
