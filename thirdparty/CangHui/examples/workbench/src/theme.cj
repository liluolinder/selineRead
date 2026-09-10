/*
 * 工作台主题：冷调石板灰底 + 靛蓝强调色，凸显分栏边界与聚焦分隔条。令牌集中于此。
 */
package chui_workbench

import chui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let WORKBENCH_TITLE: Length = 20.fp

func workbenchTheme(): Theme {
    Theme(
        bg: Color.rgb(236, 238, 243),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(216, 221, 230),
        text: Color.rgb(28, 33, 42),
        mutedText: Color.rgb(108, 116, 132),
        accent: Color.rgb(72, 108, 214),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(247, 249, 252),
        fieldActive: Color.rgb(236, 241, 252),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 251),
        shadow: Color.rgba(28, 40, 72, 28),
        radius: 12.0,
        controlRadius: 9.0
    )
}
