/*
 * 数据看板主题：深色仪表盘，青蓝强调。令牌集中于此。
 */
package chui_stats

import chui.{Color, Theme}

func statsTheme(): Theme {
    Theme(
        bg: Color.rgb(20, 23, 30),
        panel: Color.rgb(29, 33, 43),
        panelEdge: Color.rgb(44, 49, 62),
        text: Color.rgb(232, 236, 244),
        mutedText: Color.rgb(146, 155, 170),
        accent: Color.rgb(96, 165, 250),
        accentText: Color.rgb(12, 16, 24),
        danger: Color.rgb(232, 100, 100),
        field: Color.rgb(36, 41, 53),
        fieldActive: Color.rgb(52, 74, 112),
        panelRaised: Color.rgb(36, 41, 53),
        accentSoft: Color.rgb(64, 90, 148),
        shadow: Color.rgba(0, 0, 0, 76),
        radius: 14.0,
        controlRadius: 9.0
    )
}

// 变化的语义色（不随主题）：好为绿、差为红。
let DELTA_GOOD = Color.rgb(52, 199, 120)
let DELTA_BAD = Color.rgb(240, 110, 100)
