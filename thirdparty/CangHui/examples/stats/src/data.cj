/*
 * 数据看板示例的类型化数据与纯逻辑。
 *
 * 每个指标含名称、数值、单位、环比变化与“升为好”方向；分时段数据集固定。变化文案、变化好坏都是纯函数，便于单测。
 */
package chui_stats

// 一个指标：名称、数值、单位、环比百分比（带符号）、以及“升高是否为好”（如延迟越低越好）。
struct Stat {
    let name: String
    let value: Int64
    let unit: String
    let deltaPct: Int64
    let goodWhenUp: Bool

    init(name: String, value: Int64, unit: String, deltaPct: Int64, goodWhenUp!: Bool = true) {
        this.name = name
        this.value = value
        this.unit = unit
        this.deltaPct = deltaPct
        this.goodWhenUp = goodWhenUp
    }
}

let TODAY: Array<Stat> = [
    Stat("活跃用户", 1284, "人", 12),
    Stat("请求量", 58, "万次", 6),
    Stat("平均延迟", 42, "ms", -8, goodWhenUp: false),
    Stat("转化率", 34, "%", 5)
]

let WEEK: Array<Stat> = [
    Stat("活跃用户", 8420, "人", 9),
    Stat("请求量", 391, "万次", 5),
    Stat("平均延迟", 45, "ms", 4, goodWhenUp: false),
    Stat("转化率", 31, "%", -2)
]

let MONTH: Array<Stat> = [
    Stat("活跃用户", 32100, "人", 15),
    Stat("请求量", 1620, "万次", 11),
    Stat("平均延迟", 40, "ms", -12, goodWhenUp: false),
    Stat("转化率", 36, "%", 8)
]

let PERIOD_LABELS: Array<String> = ["今日", "本周", "本月"]

// 时段下标对应的指标集（越界回退到月）。
func statsFor(period: Int64): Array<Stat> {
    match (period) {
        case 0 => TODAY
        case 1 => WEEK
        case _ => MONTH
    }
}

// 环比变化文案：正数带 +，负数自带 -。
func deltaText(deltaPct: Int64): String {
    if (deltaPct >= 0) {
        "+${deltaPct}%"
    } else {
        "${deltaPct}%"
    }
}

// 变化是否为“好”：升且升为好，或降且降为好。
func deltaIsGood(stat: Stat): Bool {
    (stat.deltaPct >= 0) == stat.goodWhenUp
}
