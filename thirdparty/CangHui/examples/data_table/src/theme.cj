/*
 * 监控台主题：干净的浅色配色，蓝色强调，字号令牌集中于此。
 */
package chui_data_table

import chui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let TABLE_TITLE: Length = 20.fp

func fleetTheme(): Theme {
    Theme(
        bg: Color.rgb(246, 247, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(223, 227, 234),
        text: Color.rgb(28, 33, 42),
        mutedText: Color.rgb(110, 118, 132),
        accent: Color.rgb(37, 99, 235),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(220, 74, 68),
        field: Color.rgb(250, 251, 253),
        fieldActive: Color.rgb(238, 243, 252),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(223, 234, 252),
        shadow: Color.rgba(20, 30, 50, 26),
        radius: 14.0,
        controlRadius: 10.0
    )
}
