/*
 * 笔记主题：清爽的浅色纸面配色，令牌集中于此。
 */
package chui_notes

import chui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let NOTES_TITLE: Length = 20.fp

func notesTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 243, 239),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 220, 210),
        text: Color.rgb(38, 34, 28),
        mutedText: Color.rgb(124, 116, 102),
        accent: Color.rgb(196, 128, 44),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 74, 66),
        field: Color.rgb(250, 249, 246),
        fieldActive: Color.rgb(248, 240, 228),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(248, 236, 218),
        shadow: Color.rgba(60, 48, 30, 26),
        radius: 14.0,
        controlRadius: 10.0
    )
}
