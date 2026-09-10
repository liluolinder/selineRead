/*
 * 交错入场示例的类型化数据与纯时序逻辑。
 *
 * 交错的全部数学都在这两个纯函数里：staggerDelay 给第 index 行算它该等多久，cascadeTotalMs 算整组跑完要多久。
 * 视图只是把 staggerDelay 的结果交给 Reveal 的 delay，故时序可独立单测。
 */
package chui_stagger

import chui.{Color, IconName}

// 一行卡片：图标、图标色、标题、说明。
struct Item {
    let icon: IconName
    let iconColor: Color
    let title: String
    let detail: String

    init(icon: IconName, iconColor: Color, title: String, detail: String) {
        this.icon = icon
        this.iconColor = iconColor
        this.title = title
        this.detail = detail
    }
}

let ICON_OK = Color.rgb(52, 199, 120)
let ICON_RUN = Color.rgb(96, 165, 250)
let ICON_WAIT = Color.rgb(230, 168, 70)

let ITEMS: Array<Item> = [
    Item(IconName.NewDocument, ICON_OK, "拉取变更", "已同步 12 个提交"),
    Item(IconName.Process, ICON_RUN, "编译框架", "chui + sdl，零告警"),
    Item(IconName.Refresh, ICON_RUN, "运行测试", "375 项全部通过"),
    Item(IconName.Save, ICON_OK, "生成快照", "42 个示例已渲染"),
    Item(IconName.Calendar, ICON_WAIT, "等待审阅", "指派给 周珩"),
    Item(IconName.Copy, ICON_WAIT, "准备发布", "版本 v0.4.0")
]

// 每行入场的缓动时长（ms）。
let REVEAL_MS: Int64 = 260

// 可选的交错步进（ms）：相邻两行的入场间隔。
let STAGGER_STEPS: Array<Int64> = [0, 45, 90]
let STEP_NAMES: Array<String> = ["无交错", "轻交错", "明显交错"]

// 第 index 行该等待的毫秒数：行号 × 步进。步进为 0 即所有行同时入场。
func staggerDelay(index: Int64, stepMs: Int64): UInt64 {
    if (index <= 0 || stepMs <= 0) {
        return UInt64(0)
    }
    UInt64(index * stepMs)
}

// 整组跑完的毫秒数：最后一行的等待 + 一行的缓动时长。
func cascadeTotalMs(count: Int64, stepMs: Int64, durationMs: Int64): Int64 {
    if (count <= 0) {
        return 0
    }
    Int64(staggerDelay(count - 1, stepMs)) + durationMs
}
