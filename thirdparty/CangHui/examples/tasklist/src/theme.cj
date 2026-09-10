/*
 * 任务清单主题：清爽浅底 + 靛蓝强调。令牌集中于此。
 */
package chui_tasklist

import chui.{Color, Theme}

func tasklistTheme(): Theme {
    Theme(
        bg: Color.rgb(236, 238, 244),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(222, 226, 234),
        text: Color.rgb(30, 34, 44),
        mutedText: Color.rgb(118, 124, 138),
        accent: Color.rgb(74, 104, 210),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(246, 248, 251),
        fieldActive: Color.rgb(235, 240, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 30),
        radius: 12.0,
        controlRadius: 9.0
    )
}
