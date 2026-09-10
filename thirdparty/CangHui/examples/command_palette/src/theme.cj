/*
 * 命令面板主题：深色浮层观感，配色令牌集中于此。
 */
package chui_command_palette

import chui.{Color, Length, LengthUnits, Theme}

/** 面板主标题字号。 */
let PALETTE_TITLE: Length = 20.fp

func paletteTheme(): Theme {
    Theme(
        bg: Color.rgb(23, 25, 33),
        panel: Color.rgb(33, 36, 47),
        panelEdge: Color.rgb(52, 57, 72),
        text: Color.rgb(232, 235, 244),
        mutedText: Color.rgb(150, 157, 173),
        accent: Color.rgb(112, 143, 255),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(233, 92, 102),
        field: Color.rgb(27, 30, 40),
        fieldActive: Color.rgb(40, 45, 60),
        panelRaised: Color.rgb(45, 50, 65),
        accentSoft: Color.rgb(43, 53, 92),
        shadow: Color.rgba(0, 0, 0, 90),
        radius: 14.0,
        controlRadius: 10.0
    )
}
