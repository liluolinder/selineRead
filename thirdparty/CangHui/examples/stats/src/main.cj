/*
 * CangHui 示例：数据看板。
 *
 * 演示 `RichText` 的逐段字号：每张指标卡把「大号粗体数值 + 小号弱化单位」拼在同一行富文本里，两种字号
 * 在行内居中对齐、行高随最大字号增长；下方一行是彩色环比变化。顶部分时段切换。综合演示逐段字号 + 逐段
 * 颜色 + 状态绑定 + 派生。
 */
package chui_stats

import chui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = StatsModel()
    let app = DesktopApp(WindowSpec("CangHui 数据看板", 640, 560, scale: 1.5), theme: statsTheme())
    app.setMinimumSize(540, 480)
    app.run {
        statsView(model)
    }
    return 0
}
